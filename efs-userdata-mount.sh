#!/bin/bash
############################################################################
# Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.
############################################################################
#
# Script: efs-userdata-mount
# Use Case: When not using the VPC's default DNS, if you cannot setup DNS entry/forwarding for whatever reasons, you can use this tool to mount your EFS Volume via the appropriate mount target.
#           The tool determines the instance's AZ and mounts the right EFS mount target.
#           Customers prefer to build their AMI with this script and then invoke it from the EC2 instance's userdata (independently or as part of a launch configuration for an ASG).
# niravdd @ github
# TODO:
# 1. Use AWS-CLI --query to filter & extract instead of awk. Issue storing the results to the array as individual elements yet, so pending.
#
############################################################################

if [ "$1" = "" ] || [ "$2" = "" ] || [ "$1" = "help" ] || [ "$2" = "help" ] || [ "$1" = "debug" ] || [ "$2" = "debug" ] || [ "$1" = "boot" ] || [ "$2" = "boot" ]; then
    echo "Syntax: ./efs-userdata-mount <EFS file-system-id> <preferred mount point> [ boot / debug ]"
    echo "        ./efs-userdata-mount help"
    echo " "
    echo "help    Request for this info about the syntax"
    echo "boot    (Optional) To add the mount instructions to /etc/fstab. [Remember to remove this script from the EC2 instance's user data or startup scripts.]"
    echo "debug   (Optional) Run the tool in verbose mode"
    echo " "
    echo "Note: Script assumes -"
    echo "o That the script is being run as root; and"
    echo "o That the underlying OS is either Amazon Linux or CentOS/RHEL. Change 'yum' calls in the script appropriately, for other Linux distros."
    echo " "
    exit 0
fi

echo "[Running yum updater... It will take some time if there are any updates pending...]"
## Assuming Amazon Linux or CentOS/RHEL
yum-config-manager --enable epel > /dev/null 2>&1
yum update -y > /dev/null 2>&1
yum -y install nfs-utils aws-cli curl > /dev/null 2>&1
##

preferredMountPoint=$2
if [ ! -d "$preferredMountPoint" ]; then
   read -p "$preferredMountPoint does not exist. Do you want this script to create it? [Y/N]: " userResponse
   if [ "$userResponse" = 'Y' ] || [ "$userResponse" = 'y' ]; then
        mkdir -p $preferredMountPoint
        errorCode=$?
        if [ $errorCode -eq 0 ]; then
            if [ "$3" = "debug" ]; then
              echo "*Debug* Created the preferred mount point directory... Proceeding..."
          fi
        else
          echo "ERROR: mkdir $preferredMountPoint failed. [Exit Status: $errorCode]"
            echo "ABORTED: Cannot proceed without a valid mount point."
            exit 1
        fi
   else
        echo "ABORTED: Cannot proceed without a valid mount point."
        exit 1
   fi
fi

REGION=$(curl -s  http://169.254.169.254/latest/dynamic/instance-identity/document | awk '/region/{ gsub(/,/, "", $3); gsub(/"/, "", $3); print $3 }')
if [ "$3" = "debug" ]; then
    echo "*Debug* Region: [ == $REGION == ]"
fi
IFS=' ' read -ra subnets <<<$(aws efs describe-mount-targets --region $REGION --file-system-id $1 | awk '/SubnetId/{ gsub(/,/, "", $2); gsub(/"/, "", $2); print $2 }')

# The describe-subnets unfortinately does not return the results in the order of subnets specified, so extracting in-order
## availabilityZones=$(aws ec2 describe-subnets --region $REGION --subnet-ids $subnets | awk '/AvailabilityZone/{print substr($2, 2, length($2) - 3)}')

azCounter=0
for az in "${subnets[@]}"
do
     availabilityZones[$azCounter]=$(aws ec2 describe-subnets --region $REGION --subnet-ids ${subnets[$azCounter]} | awk '/AvailabilityZone/{ gsub(/,/, "", $2); gsub(/"/, "", $2); print $2 }')
     azCounter=`expr $azCounter + 1`
done
IFS=' ' read -ra efsMountPoints <<<$(aws efs describe-mount-targets --region $REGION --file-system-id $1 | awk '/IpAddress/{ gsub(/,/, "", $2); gsub(/"/, "", $2); print $2 }')

currentAZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

if [ "$3" = "debug" ]; then
    echo "*Debug* EFS Volume Subnets: [ == ${subnets[@]} == ]"
    echo "*Debug* EFS Volume AZs: [ == ${availabilityZones[@]} == ]"
    echo "*Debug* EFS Volume Mount Points: [ == ${efsMountPoints[@]} == ]"
fi

azCounter=0
for az in "${availabilityZones[@]}"
do
  if [ "$3" = "debug" ]; then
        echo "*Debug* Checking if instance's AZ [$currentAZ] and [$az] match..."
    fi
    if [ "$currentAZ" = "$az" ]; then
        if [ "$3" = "debug" ]; then
            echo "*Debug* == Match. Now attempting to mount EFS volume at ${efsMountPoints[$azCounter]} in $az..."
            mount -v -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${efsMountPoints[$azCounter]}:/ $preferredMountPoint
            errorCode=$?
        else
            mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${efsMountPoints[$azCounter]}:/ $preferredMountPoint
            errorCode=$?
        fi
        if [ $errorCode -eq 0 ]; then
           echo "SUCCESS: EFS Volume was mounted successfully! Access it via the [ $preferredMountPoint ]."
           if [ "$3" != "boot" ]; then
               echo "Tip: You may now want to include 'boot' as the third parameter to this tool to add the mount target to the /etc/fstab."
           fi
        else
            echo "ERROR: There was an error with the request to mount the volume."
            if [ "$3" != "debug" ]; then
                echo "Tip: Consider re-running with 'debug' as the third parameter to this tool to run in verbose mode."
            fi
        fi
        if [ "$3" = "boot" ]; then
          # Assuming "debug" is enabled for "boot - verbose..."
            echo "*Debug* Adding entry to the /etc/fstab..."
            echo "*Debug* [ == ${efsMountPoints[$azCounter]}:/ $preferredMountPoint nfs defaults 0 0 == ]"
            echo "${efsMountPoints[$azCounter]}:/ $preferredMountPoint nfs defaults 0 0" >> /etc/fstab
        fi
    fi
    azCounter=`expr $azCounter + 1`
done


# aws efs describe-mount-targets --file-system-id fs-8c2acab5 --query 'MountTargets[].IpAddress' --output text
# aws efs describe-mount-targets --file-system-id fs-8c2acab5 --query 'MountTargets[].SubnetId' --output text

# $(aws ec2 describe-subnets --subnet-ids $(aws efs describe-mount-targets --file-system-id fs-8c2acab5 | awk '/SubnetId/{print substr($2, 2, length($2) - 3)}' | awk 'NR==1') | awk '/AvailabilityZone/{print substr($2, 2, length($2) - 3)}') ]; then

# aws ec2 describe-subnets --subnet-ids $(aws efs describe-mount-targets --file-system-id fs-8c2acab5 | awk '/SubnetId/{print substr($2, 2, length($2) - 3)}' | awk 'NR==1') | awk '/AvailabilityZone/{print substr($2, 2, length($2) - 3)}')


#     echo "$"
# if [ $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone) = $(aws ec2 describe-subnets --subnet-ids $(aws efs describe-mount-targets --file-system-id fs-8c2acab5 | awk '/SubnetId/{print substr($2, 2, length($2) - 3)}' | awk 'NR==2') | awk '/AvailabilityZone/{print substr($2, 2, length($2) - 3)}') ]; then
#     echo "$"
# if [ $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone) = $(aws ec2 describe-subnets --subnet-ids $(aws efs describe-mount-targets --file-system-id fs-8c2acab5 | awk '/SubnetId/{print substr($2, 2, length($2) - 3)}' | awk 'NR==2') | awk '/AvailabilityZone/{print substr($2, 2, length($2) - 3)}') ]; then


# aws ec2 describe-subnets --subnet-ids $(aws efs describe-mount-targets --file-system-id fs-8c2acab5 | awk '/SubnetId/{print substr($2, 2, length($2) - 3)}' | awk 'NR==1') | awk '/AvailabilityZone/{print substr($2, 2, length($2) - 3)}'


# 1. aws ec2 describe-subnets --region ap-southeast-2 --subnet-ids $(aws efs describe-mount-targets --region ap-southeast-2 --file-system-id fs-8c2acab5 | awk '/SubnetId/{print substr($2, 2, length($2) - 3)}') | awk '/AvailabilityZone/{print substr($2, 2, length($2) - 3)}'
# 2. aws efs describe-mount-targets --file-system-id fs-8c2acab5 | awk '/IpAddress/{print substr($2, 2, length($2) - 3)}' | awk 'NR==1'
