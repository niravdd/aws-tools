# aws-tools
Tools written to help with specific use-cases to augment AWS services & their use.

## Tools:
l. efs-userdata-mount
   * _Service_      : Amazon Elastic File System (EFS)
   * _Use-case_     : The Amazon EFS service provides you with a DNS name/endpoint to mount your volume on a Amazon EC2 instance. The service documentation also guides users to mount the volume on on-premises servers with a DNS name. Users need to update their on-premises DNS server to forward the DNS requests for Amazon EFS mount targets to a DNS server in the Amazon VPC over the AWS Direct Connect connection.

   However, if users are unable to setup the DNS entries or the DNS forwarding - for whatever reason - they have to perform the mount using an IP address. Amazon EFS provides different mount targets for each AZ in a region. This can be troublesome if the users need instances in an Auto-Scaling Group (ASG) across multiple AZs, to be able to mount the volume at startup.

   This bash script can be help in such cases, to mount the volume via the IP address. The script identifies the AZ hosting the EC2 instance and mounts the volume using the appropriate mount target IP address for the AZ.

   * _Pre-requisites_: The EC2 instance should run with an appropriate role which can do the following, at minimum.

       l. Create/Update an IAM role to allow the following at minimum. Fine tune the policy if you need to restrict the { "Resource": "*" } further. Associate the IAM Role with the instance/launch-config for the ASG - as required.
```
			{
			    "Version": "2012-10-17",
			    "Statement": [
			        {
			            "Action": [
			                "ec2:DescribeSubnets",
			                "elasticfilesystem:DescribeMountTargets"
			            ],
			            "Effect": "Allow",
			            "Resource": "*"
			        }
			    ]
			}
```
       l. The EFS Volume security group should allow TCP connections to port 2049 (NFS) from your preferred range of IP addresses.
