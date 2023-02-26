terraform {
  required_version = ">=1.0.0.0, < 2.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version =  "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}


module "webserives-cluster" {

  source = "../../../modules/services/webserver-cluster"
  // https dhould not be there.

 // source = "github.com/apulijala/terraform-module//services/webserver-cluster?ref=v0.0.1"
  cluster_name = "stage"
  db_remote_state_bucekt = "terraform-up-and-running-state-datta"
  db_remote_state_key = "stage/data-stores/mysql/terraform.tfstate"
  server_port = "8080"
  instance_type = "t2.micro"
  max_size = 2
  min_size = 1
  text = "Jaya Guru Datta !!"

  custom_tags = {
    Owner = "new-team"
    ManagedBy = "terraform"
  }


}



resource "aws_security_group_rule" "allow_testing_inbound" {
  from_port = 12345
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = module.webserives-cluster.alb_security_id
  to_port = 12345
  type = "ingress"
}



resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0
  autoscaling_group_name = module.webserives-cluster.asg_name
  scheduled_action_name = "scale-in-at-night"
  min_size = 2
  max_size = 4
  desired_capacity = 3
  recurrence = "0 9 * * *"
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count =  var.enable_autoscaling == false ? 1 : 0
  autoscaling_group_name = module.webserives-cluster.asg_name
  scheduled_action_name = "scale-in-at-night"
  min_size =1
  max_size = 2
  desired_capacity = 2
  recurrence = "0 17 * * *"

}

// Create an IAM Policy with Cloudwatch read only.

resource "aws_iam_policy" "cloudwatch_read_only" {
  name = "cloudwatch-read-only"
  policy = data.aws_iam_policy_document.cloudwatch_read_only.json
}

data "aws_iam_policy_document" "cloudwatch_read_only" {

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*"
    ]
    resources = ["*"]
  }
}

// Create an IAM Policy with Cloudwatch Full access.

resource "aws_iam_policy" "cloudwatch_full_access" {
  name = "cloudwatch_full_access"
  policy = data.aws_iam_policy_document.cloudwatch_full_access.json
}

// Data Policy document.

data "aws_iam_policy_document" "cloudwatch_full_access" {

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user" "user" {
  name = var.users[count.index]
  count = length(var.users)
}



resource "aws_iam_user_policy_attachment" "neo_full_access" {

  count = var.give_neo_full_access ? 1 : 0
  policy_arn = aws_iam_policy.cloudwatch_full_access.arn
  user = aws_iam_user.user[0].name
}

resource "aws_iam_user_policy_attachment" "neo_read_only" {
  policy_arn = aws_iam_policy.cloudwatch_read_only.arn
  user = aws_iam_user.user[0].name
  count = var.give_neo_full_access ? 0 : 1
}


output "neo_cloudwatch_policy_arn" {
  value = (
          var.give_neo_full_access ?
            aws_iam_user_policy_attachment.neo_full_access[0].policy_arn
           : aws_iam_user_policy_attachment.neo_read_only[0].policy_arn
  )
}

output "neo_cloudwatch_policy_arn_with_concat" {

  value = one(concat(aws_iam_user_policy_attachment.neo_full_access[*].policy_arn,
          aws_iam_user_policy_attachment.neo_read_only[*].policy_arn
        ))

}

data aws_availability_zones "all" {}

resource "random_integer" "new_integer" {
  max = 3
  min = 1
}

/*
resource "aws_instance" "example-2" {

  ami = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"
  count = random_integer.new_integer.result

}
*/



terraform {
  backend "s3" {
    key = "stage/services/webserver-cluster/terraform.tfstate"
  }
}