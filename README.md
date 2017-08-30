# aws-tools
Tools written to help with specific use-cases to augment AWS services & their use.

## efs-userdata-mount
* _Service_: **Amazon Elastic File System (EFS)**
* _Use-case_: The Amazon EFS service provides you with a DNS name/endpoint to mount your volume on a Amazon EC2 instance. The service documentation also guides you to mount the volume on on-premises servers with a DNS name. You need to update their on-premises DNS server to forward the DNS requests for Amazon EFS mount targets to a DNS server in the Amazon VPC over the AWS Direct Connect connection.

    However, if you are unable to setup the DNS entries or the DNS forwarding _(for whatever reasons)_ you have to perform the mount using the EFS mount target IP Address specific to the AZ where your EC2 instance is running. Amazon EFS provides you with different mount target IP addresses, specific to each AZ in a region. This would not work if you need instances launched by an Auto-Scaling Group (ASG) to mount the volume via their AZ's mount target IP Address, at startup.

    This bash script can be help in such cases, to mount the volume via the IP address. The script identifies the AZ hosting the EC2 instance and mounts the volume using the appropriate mount target IP address for the AZ.

* _Pre-requisites_: The EC2 instance should be launched in the same VPC as the EFS volume & in one of the subnets where the EFS Volume has mount targets.

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

## TBD