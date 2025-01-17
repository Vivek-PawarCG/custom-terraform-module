resource "aws_iam_role" "lambda_ec2_role" {
  name = "lambda_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
}

resource "aws_iam_policy" "lambda_ec2_policy" {
  name        = "lambda_ec2_policy"
  description = "Policy for Lambda to start EC2 instance"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:StartInstances",
          "ec2:DescribeInstances"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_role_policy_attach" {
  role       = aws_iam_role.lambda_ec2_role.name
  policy_arn = aws_iam_policy.lambda_ec2_policy.arn
}

resource "aws_instance" "my_instance" {
  ami           = "ami-0022f774911c1d690"
  instance_type = var.instance_type

  tags = {
    Name = "custom-terraform-instance"
  }
}

data "template_file" "lambda_function" {
  template = <<-EOF
    import boto3
    import os

    def lambda_handler(event, context):
        ec2_client = boto3.client('ec2')
        instance_id = os.environ['INSTANCE_ID']

        response = ec2_client.start_instances(
            InstanceIds=[instance_id],
        )

        return response
  EOF
}

data "archive_file" "lambda_zip" {
  depends_on = [data.template_file.lambda_function]

  type        = "zip"
  output_path = "${path.module}/lambda_function_payload.zip"
  
  source {
    content  = data.template_file.lambda_function.rendered
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "start_ec2_instance" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "startEC2Instance"
  role          = aws_iam_role.lambda_ec2_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      INSTANCE_ID = aws_instance.my_instance.id
    }
  }
}
