# aws-tools
Tools written to help with specific use-cases to augment AWS services & their use.

## efs-userdata-mount
* _**Service**_: **Amazon Elastic File System (EFS)**
* _**Use-case**_: The Amazon EFS service provides you with a DNS name/endpoint to mount your EFS volume on a Amazon EC2 instance. The service documentation also guides you to mount the volume on on-premises servers with a DNS name. You need to update your on-premises DNS server to forward the DNS requests for Amazon EFS mount targets to a DNS server in the Amazon VPC over the AWS Direct Connect/VPN connection.

    However, if you are unable to setup the DNS entries or the DNS forwarding _(for whatever reasons)_ you have to perform the mount using the EFS mount target IP Address specific to the AZ where your EC2 instance is running. Amazon EFS provides you with mount target IP addresses, specific to each AZ in a region - you can use them to mount the volumes manually. This would not work if you need instances launched by an Auto-Scaling Group (ASG) to intelligently mount the volume via your AZ's mount target IP Address, at startup.

    This bash script can help for such a use-case. The script identifies the AZ hosting the EC2 instance and mounts the volume using the appropriate mount target IP address for the AZ.

* _**Usage**_: Customers prefer to build their AMI with this script and then invoke it from the EC2 instance's userdata (independently or as part of a launch configuration for an ASG).
```
Syntax: ./efs-userdata-mount <EFS file-system-id> <preferred mount point> [ boot / debug ]
        ./efs-userdata-mount help

help    Request for this info about the syntax
boot    (Optional) To add the mount instructions to /etc/fstab. [Remember to remove this script from the startup scripts]
debug   (Optional) Run the tool in verbose mode

Note: Script assumes -
o That the script is being run as root; and
o That the underlying OS is either Amazon Linux or CentOS/RHEL. Change 'yum' calls in the script appropriately, for other Linux distros.
```

1. You can add the tool to your EC2 instance's userdata as below & build an AMI to be used by the launch-config/ASG.
```
    #!/bin/bash
    yum-config-manager --enable epel
    yum update -y
    yum -y install nfs-utils aws-cli curl git
    mkdir -p <mount-point>
    git clone https://github.com/niravdd/aws-tools.git /home/ec2-user
    /home/ec2-user/aws-tools/efs-userdata-mount.sh <file-system-id> <mount-point>    ## Fill the variables appropriately
```

2. To make the tool add a mount-point to the /etc/fstab, add a third parameter "boot" in the userdata as below:
```
    #!/bin/bash
    yum-config-manager --enable epel
    yum update -y
    yum -y install nfs-utils aws-cli curl git
    mkdir -p <mount-point>
    git clone https://github.com/niravdd/aws-tools.git /home/ec2-user
    /home/ec2-user/aws-tools/efs-userdata-mount.sh <file-system-id> <mount-point> boot
```
3. Alternatively, you can set up the bash script to run as a service. There are a number of solutions available on the internet to help with this.

* _**Pre-requisites**_: The EC2 instance should be launched in the same VPC as the EFS volume & in one of the subnets where the EFS Volume has mount targets.
1. Create/Update an IAM role to allow the following permissions at minimum. Fine tune the policy, as needed. Attach the IAM Role to the instance (if its running without an ASG) or in the launch-config for the ASG.
>		{
>		    "Version": "2012-10-17",
>		    "Statement": [
>		        {
>		            "Action": [
>		                "ec2:DescribeSubnets",
>		                "elasticfilesystem:DescribeMountTargets"
>		            ],
>		            "Effect": "Allow",
>		            "Resource": "*"
>		        }
>		    ]
>		}

2. The EFS Volume security group should allow TCP connections to port 2049 (NFS) from your preferred range of IP addresses.