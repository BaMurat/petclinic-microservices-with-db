## MSP 11 - Prepare Jenkins Server for CI/CD Pipeline

* Create `feature/msp-11` branch from `dev`.

``` bash
git checkout dev
git branch feature/msp-11
git checkout feature/msp-11
```

* Set up a Jenkins Server and enable it with `Git`,  `Docker`,  `Docker Compose`,  `AWS CLI v2`, `Python`,  `Ansible` and `Boto3`.  To do so, prepare a [Cloudformation template for Jenkins Server](./msp-11-jenkins-server-cfn-template.yml) with following script and save it as `jenkins-server-cfn-template.yml` under `infrastructure` folder.

``` bash
#! /bin/bash
# update os
yum update -y
# set server hostname as jenkins-server
hostnamectl set-hostname jenkins-server
# install git
yum install git -y
# install java 11
yum install java-11-amazon-corretto -y
# install jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
yum install jenkins -y
systemctl start jenkins
systemctl enable jenkins
# install docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
usermod -a -G docker jenkins
# configure docker as cloud agent for jenkins
cp /lib/systemd/system/docker.service /lib/systemd/system/docker.service.bak
sed -i 's/^ExecStart=.*/ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:2375 -H unix:\/\/\/var\/run\/docker.sock/g' /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker
systemctl restart jenkins
# install docker compose
curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" \
-o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
# uninstall aws cli version 1
rm -rf /bin/aws
# install aws cli version 2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
# install python 3
yum install python3 -y
# install ansible
pip3 install ansible
# install boto3
pip3 install boto3
# install terraform
yum install -y yum-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install terraform
```

* Grant permissions to Jenkins Server within Cloudformation template to create Cloudformation Stack and create ECR Registry, push or pull Docker images to ECR Repo.

* Commit the change, then push the cloudformation file to the remote repo.

``` bash
git add .
git commit -m 'added jenkins server cfn template'
git push --set-upstream origin feature/msp-11
git checkout dev
git merge feature/msp-11
git push origin dev
```



## MSP 12 - Configure Jenkins Server for Project

* Run jenkins server through cloud formation template(upload it from your local to AWS console)
* SSH into Jenkins server
* Get the initial administrative password.

``` bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

* Go to public URL of the Jenkins server EC2
* Enter the temporary password to unlock the Jenkins.

* Install suggested plugins.

* Create first admin user.

* Open your Jenkins dashboard and navigate to `Manage Jenkins` >> `Manage Plugins` >> `Available` tab

* Search and select `GitHub Integration`,  `Docker Plugin`,  `Docker Pipeline`, and `Jacoco` plugins, then click `Install without restart`. Note: No need to install the other `Git plugin` which is already installed can be seen under `Installed` tab.

* Configure Docker as `cloud agent` by navigating to `Manage Jenkins` >> `Manage Nodes and Clouds` >> `Configure Clouds` and using `tcp://localhost:2375` as Docker Host URI.

## MSP 13 - Prepare Continuous Integration (CI) Pipeline

* Create `feature/msp-13` branch from `dev`.

``` bash
git checkout dev
git branch feature/msp-13
git checkout feature/msp-13
```

* Create a folder, named `jenkins`, to keep `Jenkinsfiles` and `Jenkins jobs` of the project.

``` bash
mkdir jenkins
```
* Create a Jenkins job with the name of `petclinic-ci-job`: 
  * Select `Freestyle project` and click `OK`
  * Select github project and write the url to your repository's page into `Project url` (https://github.com/[your-github-account]/petclinic-microservices)
  * Under the `Source Code Management` select `Git` 
  * Write the url of your repository into the `Repository URL` (https://github.com/[your-github-account]/petclinic-microservices.git)
  * Add `*/dev`, `*/feature**` and `*/bugfix**` branches to `Branches to build`
  * Select `GitHub hook trigger for GITScm polling` under  `Build triggers`
  * Select `Add timestamps to the Console Output` under `Build Environment`
  * Click `Add build step` under `Build` and select `Execute Shell`
  * Write below script into the `Command`
    ```bash
    echo 'Running Unit Tests on Petclinic Application'
    docker run --rm -v $HOME/.m2:/root/.m2 -v `pwd`:/app -w /app maven:3.8-openjdk-11 mvn clean test
    ```
  * Click `Add post-build action` under `Post-build Actions` and select `Record jacoco coverage report`
  * Click `Save`
  
* Jenkins `CI Job` should be triggered to run on each commit of `feature**` and `bugfix**` branches and on each `PR` merge to `dev` branch.

* Prepare a script for Jenkins CI job (covering Unit Test only) and save it as `jenkins-petclinic-ci-job.sh` under `jenkins` folder.
    * You can install MAVEN into jenkins and run maven commands to run unittests, or you can run maven jobs in a maven container, as we do below
    * mvn clean test          -> straight maven command
    * maven:3.8-openjdk-11    -> using certain maven container directly from terminal
    * -w /app                 -> workspace for docker image
    * -v `pwd`:/app           -> volume for the docker image
    * -v $HOME/.m2:/root/.m2  -> After each clean 'test' execution, gotta create image_root/.m2 file to store dependencies
    * docker run --rm         -> clean up unnecessary containers before running a new one

``` bash
echo 'Running Unit Tests on Petclinic Application'
docker run --rm -v $HOME/.m2:/root/.m2 -v `pwd`:/app -w /app maven:3.8-openjdk-11 mvn clean test
```
* Create a webhook for Jenkins CI Job; 

  + Go to the project repository page and click on `Settings`.

  + Click on the `Webhooks` on the left hand menu, and then click on `Add webhook`.

  + Copy the Jenkins URL, paste it into `Payload URL` field, add `/github-webhook/` at the end of URL, and click on `Add webhook`.
  + You need to update the IP address of Jenkins hostname from webhook after re-starting the server

  ``` text
  http://[jenkins-server-hostname]:8080/github-webhook/
  ```

* Commit the change, then push the Jenkinsfile to the remote repo.

``` bash
git add .
git commit -m 'added Jenkins Job for CI pipeline'
git push --set-upstream origin feature/msp-13
git checkout dev
git merge feature/msp-13
git push origin dev
```



## MSP 14 - Create Docker Registry for Dev Manually (ECR repo)

- Create `feature/msp-14` branch from `dev`.

``` bash
git checkout dev
git branch feature/msp-14
git checkout feature/msp-14
```

* Create a Jenkins Job and name it as `create-ecr-docker-registry-for-dev` to create Docker Registry for `dev` on AWS ECR manually.

* put this in execute shell
``` bash
PATH="$PATH:/usr/local/bin"
APP_REPO_NAME="clarusway-repo/petclinic-app-dev"
AWS_REGION="us-east-1"

aws ecr create-repository \
  --repository-name ${APP_REPO_NAME} \
  --image-scanning-configuration scanOnPush=false \
  --image-tag-mutability MUTABLE \
  --region ${AWS_REGION}
```

* Prepare a script to create Docker Registry for `dev` on AWS ECR and save it as `create-ecr-docker-registry-for-dev.sh` under `infrastructure` folder.

``` bash
PATH="$PATH:/usr/local/bin"
APP_REPO_NAME="clarusway-repo/petclinic-app-dev"
AWS_REGION="us-east-1"

aws ecr create-repository \
  --repository-name ${APP_REPO_NAME} \
  --image-scanning-configuration scanOnPush=false \
  --image-tag-mutability MUTABLE \
  --region ${AWS_REGION}
```

* Commit the change, then push the script to the remote repo.

``` bash
git add .
git commit -m 'added script for creating ECR registry for dev'
git push --set-upstream origin feature/msp-14
git checkout dev
git merge feature/msp-14
git push origin dev
```

## MSP 15 - Create a QA Automation Environment with Kubernetes - Part-1

- Create `feature/msp-15` branch from `dev`.

```bash
git checkout dev
git branch feature/msp-15
git checkout feature/msp-15
```

* Create a folder for kubernetes infrastructure setup with the name of `dev-k8s-terraform` under `infrastructure` folder.

``` bash
mkdir infrastructure/dev-k8s-terraform
```

- Create a folder for roles of master and worker nodes with the name of `IAM` under the `infrastructure/dev-k8s-terraform/modules` folder.

```bash
mkdir -p infrastructure/dev-k8s-terraform/modules/IAM
```

- Create iam policy file for the master node with the name of `policy_for_master.json`  under the `infrastructure/dev-k8s-terraform/modules/IAM`.

```json
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVolumes",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyVolume",
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteVolume",
        "ec2:DetachVolume",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeVpcs",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:AttachLoadBalancerToSubnets",
        "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancerPolicy",
        "elasticloadbalancing:CreateLoadBalancerListeners",
        "elasticloadbalancing:ConfigureHealthCheck",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DetachLoadBalancerFromSubnets",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeLoadBalancerPolicies",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
        "iam:CreateServiceLinkedRole",
        "kms:DescribeKey",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:GetRepositoryPolicy",
        "ecr:ListImages",
        "ecr:DeleteRepository",
        "ecr:BatchDeleteImage",
        "ecr:SetRepositoryPolicy",
        "ecr:DeleteRepositoryPolicy",
        "s3:ListAccessPointsForObjectLambda",
        "s3:GetObjectVersionTagging",
        "s3:GetStorageLensConfigurationTagging",
        "s3:GetObjectAcl",
        "s3:GetBucketObjectLockConfiguration",
        "s3:GetIntelligentTieringConfiguration",
        "s3:GetObjectVersionAcl",
        "s3:GetBucketPolicyStatus",
        "s3:GetObjectRetention",
        "s3:GetBucketWebsite",
        "s3:GetJobTagging",
        "s3:ListJobs",
        "s3:GetMultiRegionAccessPoint",
        "s3:GetObjectAttributes",
        "s3:GetObjectLegalHold",
        "s3:GetBucketNotification",
        "s3:DescribeMultiRegionAccessPointOperation",
        "s3:GetReplicationConfiguration",
        "s3:ListMultipartUploadParts",
        "s3:GetObject",
        "s3:DescribeJob",
        "s3:GetAnalyticsConfiguration",
        "s3:GetObjectVersionForReplication",
        "s3:GetAccessPointForObjectLambda",
        "s3:GetStorageLensDashboard",
        "s3:GetLifecycleConfiguration",
        "s3:GetAccessPoint",
        "s3:GetInventoryConfiguration",
        "s3:GetBucketTagging",
        "s3:GetAccessPointPolicyForObjectLambda",
        "s3:GetBucketLogging",
        "s3:ListBucketVersions",
        "s3:ListBucket",
        "s3:GetAccelerateConfiguration",
        "s3:GetObjectVersionAttributes",
        "s3:GetBucketPolicy",
        "s3:GetEncryptionConfiguration",
        "s3:GetObjectVersionTorrent",
        "s3:GetBucketRequestPayment",
        "s3:GetAccessPointPolicyStatus",
        "s3:GetObjectTagging",
        "s3:GetMetricsConfiguration",
        "s3:GetBucketOwnershipControls",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetMultiRegionAccessPointPolicyStatus",
        "s3:ListBucketMultipartUploads",
        "s3:GetMultiRegionAccessPointPolicy",
        "s3:GetAccessPointPolicyStatusForObjectLambda",
        "s3:ListAccessPoints",
        "s3:GetBucketVersioning",
        "s3:ListMultiRegionAccessPoints",
        "s3:GetBucketAcl",
        "s3:GetAccessPointConfigurationForObjectLambda",
        "s3:ListStorageLensConfigurations",
        "s3:GetObjectTorrent",
        "s3:GetStorageLensConfiguration",
        "s3:GetAccountPublicAccessBlock",
        "s3:ListAllMyBuckets",
        "s3:GetBucketCORS",
        "s3:GetBucketLocation",
        "s3:GetAccessPointPolicy",
        "s3:GetObjectVersion"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
}
```

- Create iam policy file for the worker node with the name of `policy_for_worker.json`  under the `infrastructure/dev-k8s-terraform/modules/IAM`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:ModifyVolume",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:GetRepositoryPolicy",
        "ecr:ListImages",
        "ecr:DeleteRepository",
        "ecr:BatchDeleteImage",
        "ecr:SetRepositoryPolicy",
        "ecr:DeleteRepositoryPolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:CreateAction": [
            "CreateVolume",
            "CreateSnapshot"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/CSIVolumeName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeSnapshotName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
```

- Create a terraform file for roles with the name of `roles.tf`  under the `infrastructure/dev-k8s-terraform/modules/IAM`.

```go
resource "aws_iam_policy" "policy_for_master_role" {
  name        = "policy_for_master_role"
  policy      = file("./modules/IAM/policy_for_master.json")
}

resource "aws_iam_policy" "policy_for_worker_role" {
  name        = "policy_for_worker_role"
  policy      = file("./modules/IAM/policy_for_worker.json")
}

resource "aws_iam_role" "role_for_master" {
  name = "role_master_k8s"

  # Terraform "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "role_for_master"
  }
}

resource "aws_iam_role" "role_for_worker" {
  name = "role_worker_k8s"

  # Terraform "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "role_for_worker"
  }
}

resource "aws_iam_policy_attachment" "attach_for_master" {
  name       = "attachment_for_master"
  roles      = [aws_iam_role.role_for_master.name]
  policy_arn = aws_iam_policy.policy_for_master_role.arn
}

resource "aws_iam_policy_attachment" "attach_for_worker" {
  name       = "attachment_for_worker"
  roles      = [aws_iam_role.role_for_worker.name]
  policy_arn = aws_iam_policy.policy_for_worker_role.arn
}

resource "aws_iam_instance_profile" "profile_for_master" {
  name  = "profile_for_master"
  role = aws_iam_role.role_for_master.name
}

resource "aws_iam_instance_profile" "profile_for_worker" {
  name  = "profile_for_worker"
  role = aws_iam_role.role_for_worker.name
}

output master_profile_name {
  value       = aws_iam_instance_profile.profile_for_master.name
}

output worker_profile_name {
  value       = aws_iam_instance_profile.profile_for_worker.name
}
```

- Prepare a terraform file for kubernetes Infrastructure consisting of 1 master, 2 Worker Nodes and save it as `main.tf` under the `infrastructure/dev-k8s-terraform`.

```go
provider "aws" {
  region  = "us-east-1"
}

module "iam" {
  source = "./modules/IAM"
}

resource "aws_security_group" "matt-kube-mutual-sg" {
  name = "kube-mutual-sec-group-for-matt"
}

resource "aws_security_group" "matt-kube-worker-sg" {
  name = "kube-worker-sec-group-for-matt"
  ingress {
    protocol = "tcp"
    from_port = 10250
    to_port = 10250
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 30000
    to_port = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "udp"
    from_port = 8472
    to_port = 8472
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  
  egress{
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "kube-worker-secgroup"
    "kubernetes.io/cluster/mattsCluster" = "owned"
  }
}

resource "aws_security_group" "matt-kube-master-sg" {
  name = "kube-master-sec-group-for-matt"

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol = "tcp"
    from_port = 6443
    to_port = 6443
    cidr_blocks = ["0.0.0.0/0"]
    #security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol = "tcp"
    from_port = 2380
    to_port = 2380
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 2379
    to_port = 2379
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 10250
    to_port = 10250
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 10251
    to_port = 10251
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 10252
    to_port = 10252
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  ingress {
    protocol = "tcp"
    from_port = 30000
    to_port = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol = "udp"
    from_port = 8472
    to_port = 8472
    security_groups = [aws_security_group.matt-kube-mutual-sg.id]
  }
  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "kube-master-secgroup"
    # "kubernetes.io/cluster/mattsCluster" = "owned"  # This part is commented out for not letting master node to get into the target instances of the ingress load balancer
  }
}

resource "aws_instance" "kube-master" {
    ami = "ami-013f17f36f8b1fefb"
    instance_type = "t2.medium"
    iam_instance_profile = module.iam.master_profile_name
    vpc_security_group_ids = [aws_security_group.matt-kube-master-sg.id, aws_security_group.matt-kube-mutual-sg.id]
    key_name = "mattkey"
    subnet_id = "subnet-c41ba589"  # select own subnet_id of us-east-1a
    availability_zone = "us-east-1a"
    tags = {
        Name = "kube-master"
        "kubernetes.io/cluster/mattsCluster" = "owned"
        Project = "tera-kube-ans"
        Role = "master"
        Id = "1"
        environment = "dev"
    }
}

resource "aws_instance" "worker-1" {
    ami = "ami-013f17f36f8b1fefb"
    instance_type = "t2.medium"
        iam_instance_profile = module.iam.worker_profile_name
    vpc_security_group_ids = [aws_security_group.matt-kube-worker-sg.id, aws_security_group.matt-kube-mutual-sg.id]
    key_name = "mattkey"
    subnet_id = "subnet-c41ba589"  # select own subnet_id of us-east-1a
    # subnet_id = "subnet-077c9758"
    availability_zone = "us-east-1a"
    tags = {
        Name = "worker-1"
        "kubernetes.io/cluster/mattsCluster" = "owned"
        Project = "tera-kube-ans"
        Role = "worker"
        Id = "1"
        environment = "dev"
    }
}

resource "aws_instance" "worker-2" {
    ami = "ami-013f17f36f8b1fefb"
    instance_type = "t2.medium"
    iam_instance_profile = module.iam.worker_profile_name
    vpc_security_group_ids = [aws_security_group.matt-kube-worker-sg.id, aws_security_group.matt-kube-mutual-sg.id]
    key_name = "mattkey"
    subnet_id = "subnet-c41ba589"  # select own subnet_id of us-east-1a
    # subnet_id = "subnet-3ccd235a"
    availability_zone = "us-east-1a"
    tags = {
        Name = "worker-2"
        "kubernetes.io/cluster/mattsCluster" = "owned"
        Project = "tera-kube-ans"
        Role = "worker"
        Id = "2"
        environment = "dev"
    }
}

output kube-master-ip {
  value       = aws_instance.kube-master.public_ip
  sensitive   = false
  description = "public ip of the kube-master"
}

output worker-1-ip {
  value       = aws_instance.worker-1.public_ip
  sensitive   = false
  description = "public ip of the worker-1"
}

output worker-2-ip {
  value       = aws_instance.worker-2.public_ip
  sensitive   = false
  description = "public ip of the worker-2"
}
```

> Note: Tag the subnet of us-east-1a with "kubernetes.io/cluster/mattsCluster" = "owned" for ingress.

- Commit the change, then push the cloudformation(terraform) template to the remote repo.

```bash
git add .
git commit -m 'added dev-k8s-terraform  for kubernetes infrastructure'
git push --set-upstream origin feature/msp-15
git checkout dev
git merge feature/msp-15
git push origin dev
```

## MSP 16 - Create a QA Automation Environment with Kubernetes - Part-2

- Create `feature/msp-16` branch from `dev`.

```bash
git checkout dev
git branch feature/msp-16
git checkout feature/msp-16
```

- Create a Jenkins Job and name it as `test-creating-qa-automation-infrastructure` to test `bash` scripts creating QA Automation Infrastructure for `dev` manually.
  * Select `Freestyle project` and click `OK`
  * Select github project and write the url to your repository's page into `Project url` (https://github.com/[your-github-account]/petclinic-microservices)
  * Under the `Source Code Management` select `Git` 
  * Write the url of your repository into the `Repository URL` (https://github.com/[your-github-account]/petclinic-microservices.git)
  * Add `*/feature/msp-16`branch to `Branches to build`
  * Select `Add timestamps to the Console Output` under `Build Environment`
  * Click `Add build step` under `Build` and select `Execute Shell`
  * Write below script into the `Command` for checking the environment tools and versions with following script.

```bash
echo $PATH
whoami
PATH="$PATH:/usr/local/bin"
python3 --version
pip3 --version
ansible --version
aws --version
terraform --version
```
  * Click `Save`

- After running the job above, replace the script with the one below in order to test creating key pair for `ansible`.

```bash
PATH="$PATH:/usr/local/bin"
ANS_KEYPAIR="call-ansible-test-dev.key"
AWS_REGION="us-east-1"
aws ec2 create-key-pair --region ${AWS_REGION} --key-name ${ANS_KEYPAIR} --query "KeyMaterial" --output text > ${ANS_KEYPAIR}
chmod 400 ${ANS_KEYPAIR}
```

- After running the job above, replace the script with the one below in order to test creating kubernetes infrastructure with terraform.

```bash
PATH="$PATH:/usr/local/bin"
ANS_KEYPAIR="call-ansible-test-dev.key"
AWS_REGION="us-east-1"
cd infrastructure/dev-k8s-terraform
sed -i "s/appServer-Key/$ANS_KEYPAIR/g" main.tf
terraform init
terraform apply -auto-approve
```

- After running the job above, replace the script with the one below in order to test SSH connection with one of the instances.

```bash
ANS_KEYPAIR="call-ansible-test-dev.key"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${WORKSPACE}/${ANS_KEYPAIR} ubuntu@44.192.98.250 hostname
```

- Prepare static inventory file with name of `hosts.ini` for Ansible under `ansible/inventory` folder using Docker machines private IP addresses.

```ini
172.31.4.143   ansible_user=ubuntu  
172.31.14.76   ansible_user=ubuntu
172.31.4.18    ansible_user=ubuntu
```

- Commit the change, then push to the remote repo.

```bash
git add .
git commit -m 'added ansible static inventory host.ini for testing'
git push --set-upstream origin feature/msp-16
```

- Configure `test-creating-qa-automation-infrastructure` job and replace the existing script with the one below in order to test ansible by pinging static hosts.

```bash
PATH="$PATH:/usr/local/bin"
ANS_KEYPAIR="call-ansible-test-dev.key"
export ANSIBLE_INVENTORY="${WORKSPACE}/ansible/inventory/hosts.ini"
export ANSIBLE_PRIVATE_KEY_FILE="${WORKSPACE}/${ANS_KEYPAIR}"
export ANSIBLE_HOST_KEY_CHECKING=False
ansible all -m ping
```

- Prepare dynamic inventory file with name of `dev_stack_dynamic_inventory_aws_ec2.yaml` for Ansible under `ansible/inventory` folder using ec2 instances private IP addresses.

```yaml
plugin: aws_ec2
regions:
  - "us-east-1"
filters:
  tag:Project: tera-kube-ans
  tag:environment: dev
keyed_groups:
  - key: tags['Project']
    prefix: 'all_instances'
  - key: tags['Role']
    prefix: 'role'
hostnames:
  - "ip-address"
compose:
  ansible_user: "'ubuntu'"
```

- Commit the change, then push the cloudformation template to the remote repo.

```bash
git add .
git commit -m 'added ansible dynamic inventory files for dev environment'
git push
```

- Configure `test-creating-qa-automation-infrastructure` job and replace the existing script with the one below in order to check the Ansible dynamic inventory for `dev` environment.

```bash
APP_NAME="Petclinic"
ANS_KEYPAIR="call-ansible-test-dev.key"
PATH="$PATH:/usr/local/bin"
export ANSIBLE_PRIVATE_KEY_FILE="${WORKSPACE}/${ANS_KEYPAIR}"
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-inventory -v -i ./ansible/inventory/dev_stack_dynamic_inventory_aws_ec2.yaml --graph
```

- After running the job above, replace the script with the one below in order to test all instances within dev dynamic inventory by pinging static hosts.

```bash
# Test dev dynamic inventory by pinging
APP_NAME="Petclinic"
ANS_KEYPAIR="call-ansible-test-dev.key"
PATH="$PATH:/usr/local/bin"
export ANSIBLE_PRIVATE_KEY_FILE="${WORKSPACE}/${ANS_KEYPAIR}"
export ANSIBLE_HOST_KEY_CHECKING=False
ansible -i ./ansible/inventory/dev_stack_dynamic_inventory_aws_ec2.yaml all -m ping
```

- Create a `ClusterConfiguration file` and save it as `clusterconfig-base.yml` under `ansible/playbooks` folder.

```yml
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.23.5
controlPlaneEndpoint: ${CONTROLPLANE_ENDPOINT}
networking:
  podSubnet: 10.244.0.0/16
apiServer:
  extraArgs:
    cloud-provider: external
    enable-aggregator-routing: "true"
controllerManager:
  extraArgs:
    cloud-provider: external
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: external
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
```

- The fields in the `clusterconfig-base.yml` file:
    - ```controlePlaneEndpoint:``` Private IP address of the master node. (It will be paste programmatically.)
    - ```podSubnet:``` Pod CIDR is necessary for Flannel CNI Plug-in.
    - ```cloud-provider:``` With the value ```external``` Kubernetes cluster will be aware of the cloud controller manager. So that the cloud controller manager can implement specific tasks related to nodes, services etc.

- Create a yaml file for Kubernetes `StorageClass` object and name it as `storage.yml` under `ansible/playbooks` folder.

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  csi.storage.k8s.io/fstype: xfs
  type: io1
  iopsPerGB: "50"
  encrypted: "true"
allowedTopologies:
- matchLabelExpressions:
  - key: topology.ebs.csi.aws.com/zone
    values:
    - us-east-1a
```

- Create an ansible playbook to install kubernetes and save it as `k8s_setup.yaml` under `ansible/playbooks` folder.

```yaml
---
- hosts: all
  become: true
  tasks:

  - name: change hostnames
    shell: "hostnamectl set-hostname {{ hostvars[inventory_hostname]['private_dns_name'] }}"

  - name: swap off
    shell: |
      free -m
      swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab

  - name: Enable the nodes to see bridged traffic
    shell: |
      cat << EOF | sudo tee /etc/sysctl.d/k8s.conf
      net.bridge.bridge-nf-call-ip6tables = 1
      net.bridge.bridge-nf-call-iptables = 1
      EOF
      sysctl --system

  - name: update apt-get
    shell: apt-get update

  - name: Install packages that allow apt to be used over HTTPS
    apt:
      name: "{{ packages }}"
      state: present
      update_cache: yes
    vars:
      packages:
      - apt-transport-https  
      - curl
      - ca-certificates

  - name: update apt-get and install kube packages
    shell: |
      curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
      echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
      apt-get update -q && \
      apt-get install -qy kubelet=1.23.5-00 kubectl=1.23.5-00 kubeadm=1.23.5-00 docker.io

  - name: Add ubuntu to docker group
    user:
      name: ubuntu
      group: docker

  - name: Restart docker and enable
    service:
      name: docker
      state: restarted
      enabled: yes

  # change the Docker cgroup driver by creating a configuration file `/etc/docker/daemon.json` 
  # and adding the following line then restart deamon, docker and kubelet

  - name: change the Docker cgroup
    shell: |
      echo '{"exec-opts": ["native.cgroupdriver=systemd"]}' | sudo tee /etc/docker/daemon.json
      sudo systemctl daemon-reload
      sudo systemctl restart docker
      sudo systemctl restart kubelet


- hosts: role_master
  tasks:
      
  - name: pull kubernetes images before installation
    become: yes
    shell: kubeadm config images pull

  - name: copy the configuration
    become: yes
    copy: 
      src: ./clusterconfig-base.yml
      dest: /home/ubuntu/
  
  - name: get gettext-base
    become: true
    apt:
      package: gettext-base
      state: present

  - name: change controlplane_endpoint and produce the clusterconfig.yml file
    shell: |
      export CONTROLPLANE_ENDPOINT={{ hostvars[inventory_hostname]['private_ip_address'] }}
      envsubst < /home/ubuntu/clusterconfig-base.yml > /home/ubuntu/clusterconfig.yml

  - name: initialize the Kubernetes cluster using kubeadm
    become: true
    shell: |
      kubeadm init --config /home/ubuntu/clusterconfig.yml
    
  - name: Setup kubeconfig for ubuntu user
    become: true
    command: "{{ item }}"
    with_items:
     - mkdir -p /home/ubuntu/.kube
     - cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
     - chown ubuntu:ubuntu /home/ubuntu/.kube/config

  - name: Install flannel pod network
    shell: kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

  - name: Generate join command
    become: true
    command: kubeadm token create --print-join-command
    register: join_command_for_workers

  - debug: msg='{{ join_command_for_workers.stdout.strip() }}'

  - name: register join command for workers
    add_host:
      name: "kube_master"
      worker_join: "{{ join_command_for_workers.stdout.strip() }}"


- hosts: role_worker
  become: true
  tasks:

  - name: Join workers to cluster
    shell: "{{ hostvars['kube_master']['worker_join'] }}"
    register: result_of_joining


- hosts: role_master
  become: false
  tasks:

  - name: Patch the instances
    become: false
    shell: |
      cd /home/ubuntu
      kubectl patch node {{ hostvars[groups['role_master'][0]]['private_dns_name'] }} -p '{"spec":{"providerID":"aws:///us-east-1a/{{ hostvars[groups['role_master'][0]]['instance_id'] }}" }}'
      kubectl patch node {{ hostvars[groups['role_worker'][0]]['private_dns_name'] }} -p '{"spec":{"providerID":"aws:///us-east-1a/{{ hostvars[groups['role_worker'][0]]['instance_id'] }}" }}'
      kubectl patch node {{ hostvars[groups['role_worker'][1]]['private_dns_name'] }} -p '{"spec":{"providerID":"aws:///us-east-1a/{{ hostvars[groups['role_worker'][1]]['instance_id'] }}" }}'

  - name: Deploy the required cloud-controller-manager 
    shell: |
      cd /home/ubuntu
      curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
      chmod 777 get_helm.sh
      ./get_helm.sh
      helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws
      helm repo update
      helm upgrade --install aws-cloud-controller-manager aws-cloud-controller-manager/aws-cloud-controller-manager --set image.tag=v1.20.0-alpha.0
      
  - name: Deploy Nginx Ingress 
    shell: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.2/deploy/static/provider/aws/deploy.yaml

  - name: Deploy AWS CSI Driver
    become: false
    shell: kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable"

  - name: copy the storage.yml file
    become: yes
    copy: 
      src: ./storage.yml
      dest: /home/ubuntu/

  - name: create StorageClass object
    become: false
    shell: kubectl apply -f storage.yml
```

- Commit the change, then push the ansible playbooks to the remote repo.

```bash
git add .
git commit -m 'added ansible playbooks for dev environment'
git push
```

- Configure `test-creating-qa-automation-infrastructure` job and replace the existing script with the one below in order to test the playbooks to create a Kubernetes cluster.

```bash
APP_NAME="Petclinic"
ANS_KEYPAIR="call-ansible-test-dev.key"
PATH="$PATH:/usr/local/bin"
export ANSIBLE_PRIVATE_KEY_FILE="${WORKSPACE}/${ANS_KEYPAIR}"
export ANSIBLE_HOST_KEY_CHECKING=False
# k8s setup
ansible-playbook -i ./ansible/inventory/dev_stack_dynamic_inventory_aws_ec2.yaml ./ansible/playbooks/k8s_setup.yaml
```

- After running the job above, replace the script with the one below in order to test tearing down the Kubernetes cluster infrastructure.

```bash
cd infrastructure/dev-k8s-terraform
terraform destroy -auto-approve
```

- After running the job above, replace the script with the one below in order to test deleting existing key pair using AWS CLI with following script.

```bash
PATH="$PATH:/usr/local/bin"
ANS_KEYPAIR="call-ansible-test-dev.key"
AWS_REGION="us-east-1"
aws ec2 delete-key-pair --region ${AWS_REGION} --key-name ${ANS_KEYPAIR}
rm -rf ${ANS_KEYPAIR}
```

- Create a script to create QA Automation infrastructure and save it as `create-qa-automation-environment.sh` under `infrastructure` folder. (This script shouldn't be used in one time. It should be applied step by step like above)

```bash
# Environment variables
PATH="$PATH:/usr/local/bin"
APP_NAME="Petclinic"
ANS_KEYPAIR="Call-$APP_NAME-dev-${BUILD_NUMBER}.key"
AWS_REGION="us-east-1"
export ANSIBLE_PRIVATE_KEY_FILE="${WORKSPACE}/${ANS_KEYPAIR}"
export ANSIBLE_HOST_KEY_CHECKING=False
# Create key pair for Ansible
aws ec2 create-key-pair --region ${AWS_REGION} --key-name ${ANS_KEYPAIR} --query "KeyMaterial" --output text > ${ANS_KEYPAIR}
chmod 400 ${ANS_KEYPAIR}
# Create infrastructure for kubernetes
cd infrastructure/dev-k8s-terraform
terraform init
terraform apply -auto-approve
# Install k8s cluster on the infrastructure
ansible-playbook -i ./ansible/inventory/dev_stack_dynamic_inventory_aws_ec2.yaml ./ansible/playbooks/k8s_setup.yaml
# Build, Deploy, Test the application
# Tear down the k8s infrastructure
cd infrastructure/dev-k8s-terraform
terraform destroy -auto-approve
# Delete key pair
aws ec2 delete-key-pair --region ${AWS_REGION} --key-name ${ANS_KEYPAIR}
rm -rf ${ANS_KEYPAIR}
```

- Commit the change, then push the script to the remote repo.

```bash
git add .
git commit -m 'added scripts for qa automation environment'
git push
git checkout dev
git merge feature/msp-16
git push origin dev
```
## MSP 17 - Prepare Petlinic Kubernetes YAML Files

* Create `feature/msp-17` branch from `release`.

``` bash
git checkout release
git branch feature/msp-17
git checkout feature/msp-17
```

* Create a folder with name of `k8s` for keeping the deployment files of Petclinic App on Kubernetes cluster.

* Create a `docker-compose.yml` under `k8s` folder with the following content as to be used in conversion the k8s files.

```yaml
version: '3'
services:
  config-server:
    image: "{{ .Values.IMAGE_TAG_CONFIG_SERVER }}"
    ports:
     - 8888:8888
    labels:
      kompose.image-pull-secret: "regcred"
  discovery-server:
    image: "{{ .Values.IMAGE_TAG_DISCOVERY_SERVER }}"
    ports:
     - 8761:8761
    labels:
      kompose.image-pull-secret: "regcred"
  customers-service:
    image: "{{ .Values.IMAGE_TAG_CUSTOMERS_SERVICE }}"
    deploy:
      replicas: 2
    ports:
    - 8081:8081
    labels:
      kompose.image-pull-secret: "regcred"
  visits-service:
    image: "{{ .Values.IMAGE_TAG_VISITS_SERVICE }}"
    deploy:
      replicas: 2
    ports:
     - 8082:8082
    labels:
      kompose.image-pull-secret: "regcred"
  vets-service:
    image: "{{ .Values.IMAGE_TAG_VETS_SERVICE }}"
    deploy:
      replicas: 2
    ports:
     - 8083:8083
    labels:
      kompose.image-pull-secret: "regcred"
  api-gateway:
    image: "{{ .Values.IMAGE_TAG_API_GATEWAY }}"
    deploy:
      replicas: 1
    ports:
     - 8080:8080
    labels:
      kompose.image-pull-secret: "regcred"
      kompose.service.expose: "{{ .Values.DNS_NAME }}"
      kompose.service.type: "nodeport"
  tracing-server:
    image: openzipkin/zipkin
    environment:
    - JAVA_OPTS=-XX:+UnlockExperimentalVMOptions -Djava.security.egd=file:/dev/./urandom
    ports:
     - 9411:9411
  admin-server:
    image: "{{ .Values.IMAGE_TAG_ADMIN_SERVER }}"
    ports:
     - 9090:9090
    labels:
      kompose.image-pull-secret: "regcred"
  hystrix-dashboard:
    image: "{{ .Values.IMAGE_TAG_HYSTRIX_DASHBOARD }}"
    ports:
     - 7979:7979
    labels:
      kompose.image-pull-secret: "regcred"
  grafana-server:
    image: "{{ .Values.IMAGE_TAG_GRAFANA_SERVICE }}"
    ports:
    - 3000:3000
    labels:
      kompose.image-pull-secret: "regcred"
  prometheus-server:
    image: "{{ .Values.IMAGE_TAG_PROMETHEUS_SERVICE }}"
    ports:
    - 9091:9090
    labels:
      kompose.image-pull-secret: "regcred"

  mysql-server:
    image: mysql:5.7.8
    environment: 
      MYSQL_ROOT_PASSWORD: petclinic
      MYSQL_DATABASE: petclinic
    ports:
    - 3306:3306
```

* Install [conversion tool](https://kompose.io/installation/) named `Kompose` on your Jenkins Server. [User Guide](https://kompose.io/user-guide/#user-guide)

```bash
curl -L https://github.com/kubernetes/kompose/releases/download/v1.26.1/kompose-linux-amd64 -o kompose
chmod +x kompose
sudo mv ./kompose /usr/local/bin/kompose
kompose version
```

* Install Helm [version 3+](https://github.com/helm/helm/releases) on Jenkins Server. [Introduction to Helm](https://helm.sh/docs/intro/). [Helm Installation](https://helm.sh/docs/intro/install/).

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version
```

* Create an helm chart named `petclinic_chart` under `k8s` folder.

```bash
cd k8s
helm create petclinic_chart
```

* Remove all files under the petclinic_chart/templates folder.

```bash
rm -r petclinic_chart/templates/*
```
  
* Convert the `docker-compose.yml` into k8s/petclinic_chart/templates objects and save under `k8s/petclinic_chart` folder.

```bash
kompose convert -f docker-compose.yml -o petclinic_chart/templates
```

* Update deployment files with `init-containers` to launch microservices in sequence. See [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/).

```yaml
# for discovery server
      initContainers:
      - name: init-config-server
        image: busybox
        command: ['sh', '-c', 'until nc -z config-server:8888; do echo waiting for config-server; sleep 2; done;']
# for all other microservices except config-server, discovery-server and mysql-server
      initContainers:
      - name: init-discovery-server
        image: busybox
        command: ['sh', '-c', 'until nc -z discovery-server:8761; do echo waiting for discovery-server; sleep 2; done;']
``` 

* Update `spec.rules.host` field of `api-gateway-ingress.yaml` file and add `ingressClassName: nginx` field under the `spec` field as below.

```yaml
spec:
  ingressClassName: nginx
  rules:
    - host: '{{ .Values.DNS_NAME }}'
      ...
```

* Add `nodePort: 30001` to `spec.ports` field of `api-gateway-service.yaml` file for selenium tests as below.

```yaml
...
spec:
  ports:
    - name: "8080"
      port: 8080
      targetPort: 8080
      nodePort: 30001
...
```

* Add `k8s/petclinic_chart/values-template.yaml` file as below.

```yaml
IMAGE_TAG_CONFIG_SERVER: "${IMAGE_TAG_CONFIG_SERVER}"
IMAGE_TAG_DISCOVERY_SERVER: "${IMAGE_TAG_DISCOVERY_SERVER}"
IMAGE_TAG_CUSTOMERS_SERVICE: "${IMAGE_TAG_CUSTOMERS_SERVICE}"
IMAGE_TAG_VISITS_SERVICE: "${IMAGE_TAG_VISITS_SERVICE}"
IMAGE_TAG_VETS_SERVICE: "${IMAGE_TAG_VETS_SERVICE}"
IMAGE_TAG_API_GATEWAY: "${IMAGE_TAG_API_GATEWAY}"
IMAGE_TAG_ADMIN_SERVER: "${IMAGE_TAG_ADMIN_SERVER}"
IMAGE_TAG_HYSTRIX_DASHBOARD: "${IMAGE_TAG_HYSTRIX_DASHBOARD}"
IMAGE_TAG_GRAFANA_SERVICE: "${IMAGE_TAG_GRAFANA_SERVICE}"
IMAGE_TAG_PROMETHEUS_SERVICE: "${IMAGE_TAG_PROMETHEUS_SERVICE}"
DNS_NAME: "DNS Name of your application"
```

### Set up a Helm v3 chart repository in Amazon S3

* This pattern helps you to manage Helm v3 charts efficiently by integrating the Helm v3 repository into Amazon Simple Storage Service (Amazon S3) on the Amazon Web Services (AWS) Cloud. (https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/set-up-a-helm-v3-chart-repository-in-amazon-s3.html)

* Create an S3 bucket for Helm charts. In the bucket, create a folder called stable/myapp. The example in this pattern uses s3://petclinic-helm-charts/stable/myapp as the target chart repository.

* Install the helm-s3 plugin for Amazon S3.

```bash
helm plugin install https://github.com/hypnoglow/helm-s3.git
```

* On some systems we need to install Helm S3 plugin as Jenkins user to be able to use S3 with pipeline script. 

``` bash
sudo su -s /bin/bash jenkins
export PATH=$PATH:/usr/local/bin
helm version
helm plugin install https://github.com/hypnoglow/helm-s3.git
``` 

* Initialize the Amazon S3 Helm repository.

```bash
AWS_REGION=us-east-1 helm s3 init s3://petclinic-helm-charts/stable/myapp 
```

* The command creates an index.yaml file in the target to track all the chart information that is stored at that location.

* Verify that the index.yaml file was created.

```bash
aws s3 ls s3://petclinic-helm-charts/stable/myapp/
```

* Add the Amazon S3 repository to Helm on the client machine. 

```bash
AWS_REGION=us-east-1 helm repo add stable-petclinicapp s3://petclinic-helm-charts/stable/myapp/
```

* Update `version` field of `k8s/petclinic_chart/Chart.yaml` file as below for testing.

```yaml
version: 1.1.1
```

* Package the local Helm chart.

```bash
cd k8s
helm package petclinic_chart/ 
```

* Store the local package in the Amazon S3 Helm repository.

```bash
HELM_S3_MODE=3 AWS_REGION=us-east-1 helm s3 push ./petclinic_chart-1.1.1.tgz stable-petclinicapp
```

* Search for the Helm chart.

```bash
helm search repo stable-petclinicapp
```

* You get an output as below.

```bash
NAME                                    CHART VERSION   APP VERSION     DESCRIPTION                
stable-petclinicapp/petclinic_chart     1.1.1           0.1.0           A Helm chart for Kubernetes
```

* In Chart.yaml, set the `version` value to `1.1.2` in Chart.yaml, and then package the chart, this time changing the version in Chart.yaml to 1.1.2. Version control is ideally achieved through automation by using tools like GitVersion or Jenkins build numbers in a CI/CD pipeline. 

```bash
helm package petclinic_chart/
```

* Push the new version to the Helm repository in Amazon S3.

```bash
HELM_S3_MODE=3 AWS_REGION=us-east-1 helm s3 push ./petclinic_chart-1.1.2.tgz stable-petclinicapp
```

* Verify the updated Helm chart.

```bash
helm repo update
helm search repo stable-petclinicapp
```

* You get an output as below.

```bash
NAME                                    CHART VERSION   APP VERSION     DESCRIPTION                
stable-petclinicapp/petclinic_chart     1.1.2           0.1.0           A Helm chart for Kubernetes
```

* To view all the available versions of a chart execute following command.

```bash
helm search repo stable-petclinicapp --versions
```

* Output:

```bash
NAME                                    CHART VERSION   APP VERSION     DESCRIPTION                
stable-petclinicapp/petclinic_chart     1.1.2           0.1.0           A Helm chart for Kubernetes
stable-petclinicapp/petclinic_chart     1.1.1           0.1.0           A Helm chart for Kubernetes
```

* In Chart.yaml, set the `version` value to `HELM_VERSION` in Chart.yaml for automation in jenkins pipeline.

* Commit the change, then push the script to the remote repo.

``` bash
git add .
git commit -m 'added Configuration YAML Files for Kubernetes Deployment'
git push --set-upstream origin feature/msp-24
git checkout release
git merge feature/msp-24
git push origin release
```

## MSP 18 - Prepare a QA Automation Pipeline for Nightly Builds

- Create `feature/msp-18` branch from `dev`.

```bash
git checkout dev
git branch feature/msp-18
git checkout feature/msp-18
```

- Prepare a script to package the app with maven Docker container and save it as `package-with-maven-container.sh` and save it under `jenkins` folder.

```bash
docker run --rm -v $HOME/.m2:/root/.m2 -v $WORKSPACE:/app -w /app maven:3.6-openjdk-11 mvn clean package
```

- Prepare a script to create ECR tags for the dev docker images and save it as `prepare-tags-ecr-for-dev-docker-images.sh` and save it under `jenkins` folder.

```bash
MVN_VERSION=$(. ${WORKSPACE}/spring-petclinic-admin-server/target/maven-archiver/pom.properties && echo $version)
export IMAGE_TAG_ADMIN_SERVER="${ECR_REGISTRY}/${APP_REPO_NAME}:admin-server-v${MVN_VERSION}-b${BUILD_NUMBER}"
MVN_VERSION=$(. ${WORKSPACE}/spring-petclinic-api-gateway/target/maven-archiver/pom.properties && echo $version)
export IMAGE_TAG_API_GATEWAY="${ECR_REGISTRY}/${APP_REPO_NAME}:api-gateway-v${MVN_VERSION}-b${BUILD_NUMBER}"
MVN_VERSION=$(. ${WORKSPACE}/spring-petclinic-config-server/target/maven-archiver/pom.properties && echo $version)
export IMAGE_TAG_CONFIG_SERVER="${ECR_REGISTRY}/${APP_REPO_NAME}:config-server-v${MVN_VERSION}-b${BUILD_NUMBER}"
MVN_VERSION=$(. ${WORKSPACE}/spring-petclinic-customers-service/target/maven-archiver/pom.properties && echo $version)
export IMAGE_TAG_CUSTOMERS_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:customers-service-v${MVN_VERSION}-b${BUILD_NUMBER}"
MVN_VERSION=$(. ${WORKSPACE}/spring-petclinic-discovery-server/target/maven-archiver/pom.properties && echo $version)
export IMAGE_TAG_DISCOVERY_SERVER="${ECR_REGISTRY}/${APP_REPO_NAME}:discovery-server-v${MVN_VERSION}-b${BUILD_NUMBER}"
MVN_VERSION=$(. ${WORKSPACE}/spring-petclinic-hystrix-dashboard/target/maven-archiver/pom.properties && echo $version)
export IMAGE_TAG_HYSTRIX_DASHBOARD="${ECR_REGISTRY}/${APP_REPO_NAME}:hystrix-dashboard-v${MVN_VERSION}-b${BUILD_NUMBER}"
MVN_VERSION=$(. ${WORKSPACE}/spring-petclinic-vets-service/target/maven-archiver/pom.properties && echo $version)
export IMAGE_TAG_VETS_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:vets-service-v${MVN_VERSION}-b${BUILD_NUMBER}"
MVN_VERSION=$(. ${WORKSPACE}/spring-petclinic-visits-service/target/maven-archiver/pom.properties && echo $version)
export IMAGE_TAG_VISITS_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:visits-service-v${MVN_VERSION}-b${BUILD_NUMBER}"
export IMAGE_TAG_GRAFANA_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:grafana-service"
export IMAGE_TAG_PROMETHEUS_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:prometheus-service"
```

- Prepare a script to build the dev docker images tagged for ECR registry and save it as `build-dev-docker-images-for-ecr.sh` and save it under `jenkins` folder.

```bash
docker build --force-rm -t "${IMAGE_TAG_ADMIN_SERVER}" "${WORKSPACE}/spring-petclinic-admin-server"
docker build --force-rm -t "${IMAGE_TAG_API_GATEWAY}" "${WORKSPACE}/spring-petclinic-api-gateway"
docker build --force-rm -t "${IMAGE_TAG_CONFIG_SERVER}" "${WORKSPACE}/spring-petclinic-config-server"
docker build --force-rm -t "${IMAGE_TAG_CUSTOMERS_SERVICE}" "${WORKSPACE}/spring-petclinic-customers-service"
docker build --force-rm -t "${IMAGE_TAG_DISCOVERY_SERVER}" "${WORKSPACE}/spring-petclinic-discovery-server"
docker build --force-rm -t "${IMAGE_TAG_HYSTRIX_DASHBOARD}" "${WORKSPACE}/spring-petclinic-hystrix-dashboard"
docker build --force-rm -t "${IMAGE_TAG_VETS_SERVICE}" "${WORKSPACE}/spring-petclinic-vets-service"
docker build --force-rm -t "${IMAGE_TAG_VISITS_SERVICE}" "${WORKSPACE}/spring-petclinic-visits-service"
docker build --force-rm -t "${IMAGE_TAG_GRAFANA_SERVICE}" "${WORKSPACE}/docker/grafana"
docker build --force-rm -t "${IMAGE_TAG_PROMETHEUS_SERVICE}" "${WORKSPACE}/docker/prometheus"
```

- Prepare a script to push the dev docker images to the ECR repo and save it as `push-dev-docker-images-to-ecr.sh` and save it under `jenkins` folder.

```bash
# Provide credentials for Docker to login the AWS ECR and push the images
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY} 
docker push "${IMAGE_TAG_ADMIN_SERVER}"
docker push "${IMAGE_TAG_API_GATEWAY}"
docker push "${IMAGE_TAG_CONFIG_SERVER}"
docker push "${IMAGE_TAG_CUSTOMERS_SERVICE}"
docker push "${IMAGE_TAG_DISCOVERY_SERVER}"
docker push "${IMAGE_TAG_HYSTRIX_DASHBOARD}"
docker push "${IMAGE_TAG_VETS_SERVICE}"
docker push "${IMAGE_TAG_VISITS_SERVICE}"
docker push "${IMAGE_TAG_GRAFANA_SERVICE}"
docker push "${IMAGE_TAG_PROMETHEUS_SERVICE}"
```

- Commit the change, then push the scripts to the remote repo.

```bash
git add .
git commit -m 'added scripts for qa automation environment'
git push --set-upstream origin feature/msp-18
```

  - OPTIONAL: Create a Jenkins job with the name of `test-msp-18-scripts` to test the scripts:
      * Select `Freestyle project` and click `OK`
      * Select github project and write the url to your repository's page into `Project url` (https://github.com/[your-github-account]/petclinic-microservices)
      * Under the `Source Code Management` select `Git` 
      * Write the url of your repository into the `Repository URL` (https://github.com/[your-github-account]/petclinic-microservices.git)
      * Add `*/feature/msp-18` branch to `Branches to build`
      * Click `Add build step` under `Build` and select `Execute Shell`
      * Write below script into the `Command`
        ```bash
        PATH="$PATH:/usr/local/bin"
        APP_REPO_NAME="clarusway-repo/petclinic-app-dev" # Write your own repo name
        AWS_REGION="us-east-1" #Update this line if you work on another region
        ECR_REGISTRY="046402772087.dkr.ecr.us-east-1.amazonaws.com" # Replace this line with your ECR name
        aws ecr create-repository \
            --repository-name ${APP_REPO_NAME} \
            --image-scanning-configuration scanOnPush=false \
            --image-tag-mutability MUTABLE \
            --region ${AWS_REGION}
        . ./jenkins/package-with-maven-container.sh
        . ./jenkins/prepare-tags-ecr-for-dev-docker-images.sh
        . ./jenkins/build-dev-docker-images-for-ecr.sh
        . ./jenkins/push-dev-docker-images-to-ecr.sh
        ```
      * Click `Save`
      * Click `Build now` to manually start the job.

- Create Ansible playbook for deploying application as `dev-petclinic-deploy-template` under `ansible/playbooks` folder.

```yaml
---
- hosts: role_master
  tasks:

  - name: Create .docker folder
    file:
      path: /home/ubuntu/.docker
      state: directory
      mode: '0755'

  - name: copy the docker config file
    become: yes
    copy: 
      src: $JENKINS_HOME/.docker/config.json
      dest: /home/ubuntu/.docker/config.json

  - name: deploy petclinic application
    shell: |
      helm plugin install https://github.com/hypnoglow/helm-s3.git
      kubectl create ns petclinic-dev
      kubectl delete secret regcred -n petclinic-dev || true
      kubectl create secret generic regcred -n petclinic-dev \
        --from-file=.dockerconfigjson=/home/ubuntu/.docker/config.json \
        --type=kubernetes.io/dockerconfigjson
      AWS_REGION=$AWS_REGION helm repo add stable-petclinic s3://petclinic-helm-charts/stable/myapp/
      AWS_REGION=$AWS_REGION helm repo update
      AWS_REGION=$AWS_REGION helm upgrade --install \
        petclinic-app-release stable-petclinic/petclinic_chart --version ${BUILD_NUMBER} \
        --namespace petclinic-dev
```

- Create Selenium dummy test with name of `dummy_selenium_test_headless.py` with following content to check the setup for the Selenium jobs and save it under `selenium-jobs` folder.

```python
from selenium import webdriver

chrome_options = webdriver.ChromeOptions()
chrome_options.add_argument("headless")
chrome_options.add_argument("no-sandbox")
chrome_options.add_argument("disable-dev-shm-usage")
driver = webdriver.Chrome(options=chrome_options)

base_url = "https://www.google.com/"
driver.get(base_url)
source = driver.page_source

if "I'm Feeling Lucky" in source:
  print("Test passed")
else:
  print("Test failed")
driver.close()
```

- Create Ansible playbook for running dummy selenium job and save it as `pb_run_dummy_selenium_job.yaml` under `ansible/playbooks` folder.

```yaml
- hosts: all
  tasks:
  - name: run dummy selenium job
    shell: "docker run --rm -v {{ workspace }}:{{ workspace }} -w {{ workspace }} callahanclarus/selenium-py-chrome:latest python {{ item }}"
    with_fileglob: "{{ workspace }}/selenium-jobs/dummy*.py"
    register: output
  
  - name: show results
    debug: msg="{{ item.stdout }}"
    with_items: "{{ output.results }}"
```

- Prepare a script to run the playbook for dummy selenium job on Jenkins Server (localhost) and save it as `run_dummy_selenium_job.sh` under `ansible/scripts` folder.

```bash
PATH="$PATH:/usr/local/bin"
ansible-playbook --connection=local --inventory 127.0.0.1, --extra-vars "workspace=${WORKSPACE}" ./ansible/playbooks/pb_run_dummy_selenium_job.yaml
```

- Commit the change, then push the scripts for dummy selenium job to the remote repo.

```bash
git add .
git commit -m 'added scripts for running dummy selenium job'
git push --set-upstream origin feature/msp-18
```

- Create a Jenkins job with name of `test-running-dummy-selenium-job` to check the setup for selenium tests by running dummy selenium job on `feature/msp-18` branch.

- Create Ansible playbook for running all selenium jobs under `selenium-jobs` folder and save it as `pb_run_selenium_jobs.yaml` under `ansible/playbooks` folder.

```yaml
- hosts: all
  tasks:
  - name: run all selenium jobs
    shell: "docker run --rm --env MASTER_PUBLIC_IP={{ master_public_ip }} -v {{ workspace }}:{{ workspace }} -w {{ workspace }} callahanclarus/selenium-py-chrome:latest python {{ item }}"
    register: output
    with_fileglob: "{{ workspace }}/selenium-jobs/test*.py"
  
  - name: show results
    debug: msg="{{ item.stdout }}"
    with_items: "{{ output.results }}"
```

- Change the `port of url field` in the `test_owners_all_headless.py, test_owners_register_headless.py and test_veterinarians_headless.py` as `30001` as below.

```py
...
APP_IP = os.environ['MASTER_PUBLIC_IP']
url = "http://"+APP_IP.strip()+":30001/"
...
```
 
- Prepare a script to run the playbook for all selenium jobs on Jenkins Server (localhost) and save it as `run_selenium_jobs.sh` under `ansible/scripts` folder.

```bash
PATH="$PATH:/usr/local/bin"
ansible-playbook -vvv --connection=local --inventory 127.0.0.1, --extra-vars "workspace=${WORKSPACE} master_public_ip=${GRAND_MASTER_PUBLIC_IP}" ./ansible/playbooks/pb_run_selenium_jobs.yaml
```

- Prepare a Jenkinsfile for `petclinic-nightly` builds and save it as `jenkinsfile-petclinic-nightly` under `jenkins` folder.

```groovy
pipeline {
    agent any
    environment {
        PATH=sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        APP_NAME="petclinic"
        APP_REPO_NAME="clarusway-repo/${APP_NAME}-app-dev"
        AWS_ACCOUNT_ID=sh(script:'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        AWS_REGION="us-east-1"
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ANS_KEYPAIR="call-${APP_NAME}-dev-${BUILD_NUMBER}.key"
        ANSIBLE_PRIVATE_KEY_FILE="${WORKSPACE}/${ANS_KEYPAIR}"
        ANSIBLE_HOST_KEY_CHECKING="False"
    }
    stages {
        stage('Create ECR Repo') {
            steps {
                echo "Creating ECR Repo for ${APP_NAME} app"
                sh """
                aws ecr create-repository \
                    --repository-name ${APP_REPO_NAME} \
                    --image-scanning-configuration scanOnPush=false \
                    --image-tag-mutability MUTABLE \
                    --region ${AWS_REGION}
                """
            }
        }
        stage('Package Application') {
            steps {
                echo 'Packaging the app into jars with maven'
                sh ". ./jenkins/package-with-maven-container.sh"
            }
        }
        stage('Prepare Tags for Docker Images') {
            steps {
                echo 'Preparing Tags for Docker Images'
                script {
                    MVN_VERSION=sh(script:'. ${WORKSPACE}/spring-petclinic-admin-server/target/maven-archiver/pom.properties && echo $version', returnStdout:true).trim()
                    env.IMAGE_TAG_ADMIN_SERVER="${ECR_REGISTRY}/${APP_REPO_NAME}:admin-server-v${MVN_VERSION}-b${BUILD_NUMBER}"
                    MVN_VERSION=sh(script:'. ${WORKSPACE}/spring-petclinic-api-gateway/target/maven-archiver/pom.properties && echo $version', returnStdout:true).trim()
                    env.IMAGE_TAG_API_GATEWAY="${ECR_REGISTRY}/${APP_REPO_NAME}:api-gateway-v${MVN_VERSION}-b${BUILD_NUMBER}"
                    MVN_VERSION=sh(script:'. ${WORKSPACE}/spring-petclinic-config-server/target/maven-archiver/pom.properties && echo $version', returnStdout:true).trim()
                    env.IMAGE_TAG_CONFIG_SERVER="${ECR_REGISTRY}/${APP_REPO_NAME}:config-server-v${MVN_VERSION}-b${BUILD_NUMBER}"
                    MVN_VERSION=sh(script:'. ${WORKSPACE}/spring-petclinic-customers-service/target/maven-archiver/pom.properties && echo $version', returnStdout:true).trim()
                    env.IMAGE_TAG_CUSTOMERS_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:customers-service-v${MVN_VERSION}-b${BUILD_NUMBER}"
                    MVN_VERSION=sh(script:'. ${WORKSPACE}/spring-petclinic-discovery-server/target/maven-archiver/pom.properties && echo $version', returnStdout:true).trim()
                    env.IMAGE_TAG_DISCOVERY_SERVER="${ECR_REGISTRY}/${APP_REPO_NAME}:discovery-server-v${MVN_VERSION}-b${BUILD_NUMBER}"
                    MVN_VERSION=sh(script:'. ${WORKSPACE}/spring-petclinic-hystrix-dashboard/target/maven-archiver/pom.properties && echo $version', returnStdout:true).trim()
                    env.IMAGE_TAG_HYSTRIX_DASHBOARD="${ECR_REGISTRY}/${APP_REPO_NAME}:hystrix-dashboard-v${MVN_VERSION}-b${BUILD_NUMBER}"
                    MVN_VERSION=sh(script:'. ${WORKSPACE}/spring-petclinic-vets-service/target/maven-archiver/pom.properties && echo $version', returnStdout:true).trim()
                    env.IMAGE_TAG_VETS_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:vets-service-v${MVN_VERSION}-b${BUILD_NUMBER}"
                    MVN_VERSION=sh(script:'. ${WORKSPACE}/spring-petclinic-visits-service/target/maven-archiver/pom.properties && echo $version', returnStdout:true).trim()
                    env.IMAGE_TAG_VISITS_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:visits-service-v${MVN_VERSION}-b${BUILD_NUMBER}"
                    env.IMAGE_TAG_GRAFANA_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:grafana-service"
                    env.IMAGE_TAG_PROMETHEUS_SERVICE="${ECR_REGISTRY}/${APP_REPO_NAME}:prometheus-service"
                }
            }
        }
        stage('Build App Docker Images') {
            steps {
                echo 'Building App Dev Images'
                sh ". ./jenkins/build-dev-docker-images-for-ecr.sh"
                sh 'docker image ls'
            }
        }
        stage('Push Images to ECR Repo') {
            steps {
                echo "Pushing ${APP_NAME} App Images to ECR Repo"
                sh ". ./jenkins/push-dev-docker-images-to-ecr.sh"
            }
        }
        stage('Create Key Pair for Ansible') {
            steps {
                echo "Creating Key Pair for ${APP_NAME} App"
                sh "aws ec2 create-key-pair --region ${AWS_REGION} --key-name ${ANS_KEYPAIR} --query KeyMaterial --output text > ${ANS_KEYPAIR}"
                sh "chmod 400 ${ANS_KEYPAIR}"
            }
        }

        stage('Create QA Automation Infrastructure') {
            steps {
                echo 'Creating QA Automation Infrastructure for Dev Environment'
                sh """
                    cd infrastructure/dev-k8s-terraform
                    sed -i "s/mattkey/$ANS_KEYPAIR/g" main.tf
                    terraform init
                    terraform apply -auto-approve
                """
                script {
                    echo "Kubernetes Master is not UP and running yet."
                    env.id = sh(script: 'aws ec2 describe-instances --filters Name=tag-value,Values=master Name=tag-value,Values=tera-kube-ans Name=instance-state-name,Values=running --query Reservations[*].Instances[*].[InstanceId] --output text',  returnStdout:true).trim()
                    sh 'aws ec2 wait instance-status-ok --instance-ids $id'
                }
            }
        }


        stage('Create Kubernetes Cluster for QA Automation Build') {
            steps {
                echo "Setup Kubernetes cluster for ${APP_NAME} App"
                sh "ansible-playbook -i ./ansible/inventory/dev_stack_dynamic_inventory_aws_ec2.yaml ./ansible/playbooks/k8s_setup.yaml"
            }
        }

        stage('Deploy App on Kubernetes cluster'){
            steps {
                echo 'Deploying App on Kubernetes'
                sh "envsubst < k8s/petclinic_chart/values-template.yaml > k8s/petclinic_chart/values.yaml"
                sh "sed -i s/HELM_VERSION/${BUILD_NUMBER}/ k8s/petclinic_chart/Chart.yaml"
                sh "helm repo add stable-petclinic s3://petclinic-helm-charts/stable/myapp/"
                sh "helm package k8s/petclinic_chart"
                sh "helm s3 push petclinic_chart-${BUILD_NUMBER}.tgz stable-petclinic"
                sh "envsubst < ansible/playbooks/dev-petclinic-deploy-template > ansible/playbooks/dev-petclinic-deploy.yaml"
                sh "sleep 60"    
                sh "ansible-playbook -i ./ansible/inventory/dev_stack_dynamic_inventory_aws_ec2.yaml ./ansible/playbooks/dev-petclinic-deploy.yaml"
            }
        }     

        stage('Test the Application Deployment'){
            steps {
                echo "Check if the ${APP_NAME} app is ready or not"
                script {
                    env.MASTER_PUBLIC_IP = sh(script:"aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag-value,Values=master Name=tag-value,Values=tera-kube-ans Name=instance-state-name,Values=running --query Reservations[*].Instances[*].[PublicIpAddress] --output text", returnStdout:true).trim()
                    while(true) {
                        try{
                            sh "curl -s ${MASTER_PUBLIC_IP}:30001"
                            echo "${APP_NAME} app is successfully deployed."
                            break
                        }
                        catch(Exception){
                            echo "Could not connect to ${APP_NAME} app"
                            sleep(5)
                        }
                    }
                }
            }
        }

        stage('Run QA Automation Tests'){
            steps {
                echo "Run the Selenium Functional Test on QA Environment"
                sh 'ansible-playbook -vvv --connection=local --inventory 127.0.0.1, --extra-vars "workspace=${WORKSPACE} master_public_ip=${MASTER_PUBLIC_IP}" ./ansible/playbooks/pb_run_selenium_jobs.yaml'
            }
        }
 }

    post {
        always {
            echo 'Deleting all local images'
            sh 'docker image prune -af'
            echo 'Delete the Image Repository on ECR'
            sh """
                aws ecr delete-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --region ${AWS_REGION}\
                  --force
                """
            echo 'Tear down the Kubernetes Cluster'
            sh """
            cd infrastructure/dev-k8s-terraform
            terraform destroy -auto-approve
            """
            echo "Delete existing key pair using AWS CLI"
            sh "aws ec2 delete-key-pair --region ${AWS_REGION} --key-name ${ANS_KEYPAIR}"
            sh "rm -rf ${ANS_KEYPAIR}"
        }
    }
}
```

- Create a Jenkins pipeline with name of `petclinic-nightly` with following script to run QA automation tests and configure a `cron job` to trigger the pipeline every night at midnight (`0 0 * * *`) on `dev` branch. Petclinic nightly build pipeline should be built on temporary QA automation environment.

- Commit the change, then push the script to the remote repo.

```bash
git add .
git commit -m 'added qa automation pipeline for dev'
git push
git checkout dev
git merge feature/msp-18
git push origin dev
```