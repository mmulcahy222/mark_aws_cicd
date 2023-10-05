
resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "Default VPC"
  }
}

variable "subnet_default_1" {
  description = "Subnet 1 in the default VPC"
  default     = "subnet-0d803ec41d0ce19a5" 
}

variable "default_security_group" {
  description = "Security Group Open Default"
  default     = "sg-06cb6cc7195fb5076"
}




////////////////////
//
//  S3
//
////////////////////

# Create an S3 bucket for the website
resource "aws_s3_bucket" "mark_bucket" {
  bucket = "mmulcahy222-aws-website-cicd" 
}



////////////////////
//
//  IAM
//
////////////////////
resource "aws_iam_role" "mark_cicd_role" {
  name = "mark-cicd-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = [
           "codebuild.amazonaws.com",
           "codecommit.amazonaws.com",
           "codepipeline.amazonaws.com",
           "codedeploy.amazonaws.com",
           "ecs.amazonaws.com",
           "ecs-tasks.amazonaws.com",
           "ecr.amazonaws.com",
        ]
      }
    }]
  })
}

resource "aws_iam_policy" "mark_cicd_policy" {
  name        = "mark-cicd-policy"
  description = "Temporary policy for CI/CD services"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "codebuild:*",
          "codedeploy:*",
          "codepipeline:*",
          "codestar-connections:*",
          "codecommit:*",
          "ecs:*",
          "ecr:*",
          //EC2 permissions are needed so CodeBuild can work with EC2
          "ec2:*",
          "s3:*",
          "iam:PassRole",
          "cloudwatch:*",
          "logs:*"
        ],
        Effect   = "Allow",
        Resource = "*",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "attach_cicd_policy" {
  policy_arn = aws_iam_policy.mark_cicd_policy.id
  role       = aws_iam_role.mark_cicd_role.id
}


////////////////////
//
//  ECS
//
////////////////////

resource "aws_ecs_cluster" "mark_ecs_cluster" {
  name = "mark-ecs-cluster"
  tags = {
    Name = "mark-ecs-cluster"
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_ecs_cluster_capacity_providers" "mark_ecs_cluster_capacity_providers" {
  cluster_name = aws_ecs_cluster.mark_ecs_cluster.name
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight = 100
  }
}

resource "aws_ecs_service" "mark_ecs_service" {
  name            = "mark_ecs_service"
  cluster         = aws_ecs_cluster.mark_ecs_cluster.name
  task_definition = aws_ecs_task_definition.mark_ecs_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets = [var.subnet_default_1]
    security_groups = [var.default_security_group]
    assign_public_ip = true
  }

}


resource "aws_ecs_task_definition" "mark_ecs_task_definition" {
  family                   = "mark_ecs_task_definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.mark_cicd_role.arn
  cpu                      = "256"
  memory                   = "512"
  container_definitions = jsonencode([
    {
      //
      //
      //   NOTE: The container name here must match what's inside of buildspec.yml in the image definition
      //
      //
      name  = "mark_container_nginx"
      image = "${aws_ecr_repository.mark_ecr.repository_url}:mark_nginx"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}


////////////////////
//
//  CODE BUILD (CODEBUILD -> ECR -> CODEDEPLOY -> ECS)
//
//  You will need to put DOCKERFILE & BUILDSPEC.YML in the github repository
//
//  Build has phrases, and build itself is a part of CodePipeline
//
////////////////////


# Create a CodeBuild source credential resource with the GitHub personal access token
resource "aws_codebuild_source_credential" "github_token" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token = ""
}

# Create a CodeBuild project that uses GitHub as the source and personal access token as the authentication method
resource "aws_codebuild_project" "mark_codebuild" {
  name        = "mark_codebuild"
  description = "mark_codebuild"
  service_role = aws_iam_role.mark_cicd_role.arn 

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/mmulcahy222/mark_aws_cicd" 
    git_clone_depth = 1
    buildspec       = "buildspec.yml"
  }
}


////////////////////
//
//  ECR
//
////////////////////

resource "aws_ecr_repository" "mark_ecr" {
  name = "mark_ecr_repository"
  image_tag_mutability = "MUTABLE" 
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.mark_ecr.name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.mark_ecr.repository_url
}

/*
data "aws_ecs_task" "mark_ecs_task" {
  task_definition = aws_ecs_task_definition.mark_ecs_task_definition.arn
  cluster         = aws_ecs_cluster.mark_ecs_cluster.id
}

output "public_ip" {
  value = data.aws_ecs_task.mark_ecs_task.eni_network_interface_ids[0].public_ipv4_address
}
*/


////////////////////
//
//  CODEPIPELINE
//
////////////////////

resource "aws_codestarconnections_connection" "github_connection" {
  name          = "github-connection"
  provider_type = "GitHub"
}


resource "aws_codepipeline" "mark_codepipeline" {
  name     = "mark_codepipeline_terraform"
  role_arn = aws_iam_role.mark_cicd_role.arn
  artifact_store {
    location = aws_s3_bucket.mark_bucket.id
    type     = "S3"
  }

  stage {
  name = "Source"
  action {
    name     = "SourceAction"
    category = "Source"
    owner    = "AWS"
    provider = "CodeStarSourceConnection"
    version  = "1"
    output_artifacts = ["source_output"] 
    configuration = {
      ConnectionArn   = aws_codestarconnections_connection.github_connection.arn
      FullRepositoryId = "mmulcahy222/mark_aws_cicd"
      BranchName       = "master"
      OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name     = "BuildAction"
      category = "Build"
      owner    = "AWS"
      provider = "CodeBuild"
      version  = "1"
      input_artifacts = ["source_output"] 
      output_artifacts = ["build_output"] 

      configuration = {
        ProjectName = aws_codebuild_project.mark_codebuild.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name     = "DeployAction"
      category = "Deploy"
      owner    = "AWS"
      provider = "ECS"
      version  = "1"
      input_artifacts = ["build_output"]
      configuration = {
        ClusterName = aws_ecs_cluster.mark_ecs_cluster.name
        ServiceName = aws_ecs_service.mark_ecs_service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
