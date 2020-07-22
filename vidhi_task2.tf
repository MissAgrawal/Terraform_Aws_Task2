provider "aws" {
  region  = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16
  instance_tenancy = "default"

  tags = {
    Name = "lwvpc2"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "lwsubnet2"
  }
}

resource "aws_internet_gateway" "myvidhiig" {
  vpc_id = "${aws_vpc.main.id}" 

  tags = {
    Name = "lwig2"
  }
}  
resource "aws_s3_bucket" "vidhi_bucket" {
  bucket = "agr-terra-bucket-3223"
  acl = "public-read"
  
  tags = {
    Name = "agr-terra-bucket-3223"
  }
}
resource "aws_s3_bucket_object" "vidhi_object" {
  bucket = aws_s3_bucket.vidhi_bucket.bucket
  key = "image.jpg"
}

locals {
  s3_origin_id = "aws_s3_bucket.vidhi_bucket.bucket"
  depends_on = [aws_s3_bucket.vidhi_bucket]
}

resource "aws_security_group" "vidhi_sg1"{
  name = "vidhi_sg1"
  vpc_id = "${aws_vpc.main.id}" 

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  ingress {
    description = "NFS"
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  
  egress { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "lwsg2
 }
}

resource "aws_efs_file_system" "lwefs" {
  creation_token = "lwefs"
  performance_mode = "generalPurpose"
  
  tags = {
    Name = "lwefs2"
  }
}

resource "aws_efs_mount_target" "lwtarget" {
  file_system_id = aws_efs_file_system.lwefs.id
  subnet_id = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.vidhi_sg1.id]
}

resource "aws_instance" "vidhiins"{
  depends_on = [aws_efs_mount_target.lwtarget]
  ami = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name = "vidhikey"
  vpc_security_group_ids = [aws_security_group.vidhi_sg1.id]
  subnet_id = "${aws_subnet.subnet1.id}"

  tags = {
    Name = "task2os"
  }
}

resource "null_resource" "null" {
  depends_on = [aws_instance.vidhiins]
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("vidhikey.pem")
    host = aws_instance.vidhiins.public.ip
}

provisioner "remote-exec" {
  inline = [
    "sudo yum install https php git amazon-efs-utils nfs-utils -y",
    "sudo setemforce 0",
    "sudo systemctl start httpd",
    "sudo systemctl enable httpd",
    "sudo mount-t efs ${aws_efs_file_system.lwefs.id}:/ /var/www/html",
    "sudo echo '${aws_efs_file_system.lwefs.id}:/ /var/www/html efs defaults,_netdev 0 0' >> /etc/fstab",
    "sudo rm -rf /var/www/html/*",
    "sudo git clone https://github.com/MissAgrawal/Terraform_Aws_Task2.git /var/www/html/"
  ]
}

resource "aws_cloudfront_origin_access_identity" "lwcf" {
  comment = "lwcomment"
}

data "aws_iam_policy_document" "lwpolicy" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.vidhi_bucket.arn/*"]
    principals = {
      type = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket_poLicy" "lwpolicy1" {
  bucket = aws_s3_bucket.vidhi_bucket.id
  policy = data.aws_iam_policy_document.lwpolicy.json
}

resource "aws_cloudfront_distribution" "lwcfd" {
  origin {
    domain_name = "${aws_s3_bucket.vidhi_bucket.bucket_regional_domain_name}"
    origin_id   = local.s3_origin_id
   
    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }
  enabled = true
  is_ipv6_enabled = true
  wait_for_deployment = false
    
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "DELETE", "OPTION", "PATCH", "PUSH", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

restrictions {
  geo_restriction {
    restriction_type = "none"
  }
}

viewer_certificate {
  cloudfront_default_certificate = true
}
}