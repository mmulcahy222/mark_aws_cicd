# CI/CD OF CONTAINERS IN TERRAFORM

This gets three birds with one stone:

1) Docker Containers in the Cloud (ECS/ECR)
2) Continuous Integration/Continuous Deployment (CI/CD)
3) Terraform

This was done in TERRAFORM, so easier customization by text & easier takedowns of entire infrastructure can happen with 1 or a few keystrokes.

When a commit happens in GitHub, it starts off a process that will build a container, push the container into the Elastic Container Repository, which would then deployed into ECS as a task. 

To see the picture better, it goes from CodeBuild to Elastic Container Registry (ECR) to Elastic Container (ECS).

What is stitching all of this together. Great question! This is coming from CodePipeline. 

CodePipeline will listen to the changes from GitHub, very much likely from Webhooks. This will prompt this flow of CodeBuild, then ECR, to ECS.

CodePipeline will even handle the deployment for us, which doesn't even necessitate the configuration of CodeDeploy! This I found out the hard arduous time-consuming way.

CodePipeline is in three steps. Source, Build & Deploy. Source is connecting to GitHub, Build is running a buildspec.yml on a high-spec machine under the hood, and Deploy does what it says to almost anywhere you wish. 

Three stages in CodePipeline.

However, there's a poetic irony.

CodeBuild adds more stages, in three phases. Pre-Build, Build, Post-Build.

Pre-Build sets up the environment variables, Build makes the container, and Post-Build pushes the container to ECR.

Going through the error messages is like escaping a cage like Houdini but I managed, such as the line "aws ecr get-login-password | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

As you can see, CodePipeline calls three stages and one of those stages call three phrases, so it's a big pipeline calling a mini one with build.

But this works. And it was hard. And rewarding. Done in Terraform.

Don't bother using any tokens. They're deactivated.

buildspec.yml

![](images/buildspec.png)

ci_cd.tf

![](images/terraform_cicd_polacode.png)

other screenshots

![](images/cicd_4.png)
![](images/cicd_3.png)
![](images/cicd_1.png)
![](images/cicd_2.png)
