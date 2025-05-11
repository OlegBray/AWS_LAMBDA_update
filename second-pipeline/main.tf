provider "aws" {
  region = "il-central-1"  # adjust if needed
}

# IAM Role for Lambda
resource "aws_iam_role" "oleg_lambda_role" {
  name = "oleg-tf-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Inline policy: minimal DynamoDB & CloudWatch Logs access
resource "aws_iam_role_policy" "oleg_lambda_policy" {
  name = "dynamodb_access"
  role = aws_iam_role.oleg_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Scan"]
        Resource = "arn:aws:dynamodb:*:*:table/imtech"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "oleg_lambda" {
  function_name    = "oleg-tf-lambda"
  role             = aws_iam_role.oleg_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")
}

# Lookup existing API Gateway by name
data "aws_api_gateway_rest_api" "imtech_api" {
  name = "imtech"
}

# Create the /oleg-tf-lambda resource
resource "aws_api_gateway_resource" "lambda_resource" {
  rest_api_id = data.aws_api_gateway_rest_api.imtech_api.id
  parent_id   = data.aws_api_gateway_rest_api.imtech_api.root_resource_id
  path_part   = "oleg-tf-lambda"
}

# ANY method with Lambda proxy integration
resource "aws_api_gateway_method" "any_method" {
  rest_api_id   = data.aws_api_gateway_rest_api.imtech_api.id
  resource_id   = aws_api_gateway_resource.lambda_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = data.aws_api_gateway_rest_api.imtech_api.id
  resource_id             = aws_api_gateway_resource.lambda_resource.id
  http_method             = aws_api_gateway_method.any_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.oleg_lambda.invoke_arn
}

# Grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.oleg_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_api_gateway_rest_api.imtech_api.execution_arn}/*/*"
}

# Deployment: no stage_name, so Terraform won't manage stages implicitly
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  rest_api_id = data.aws_api_gateway_rest_api.imtech_api.id

  # Force a new deployment whenever the API changes
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.lambda_resource.id,
      aws_api_gateway_method.any_method.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Adopt and manage the existing "default" stage
resource "aws_api_gateway_stage" "default_stage" {
  rest_api_id   = data.aws_api_gateway_rest_api.imtech_api.id
  stage_name    = "default"
  deployment_id = aws_api_gateway_deployment.deployment.id

  description = "Terraform-managed default stage"
}
