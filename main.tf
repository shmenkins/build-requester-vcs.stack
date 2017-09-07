variable "s3_bucket" {}

resource "aws_api_gateway_rest_api" "webhook" {
  name = "webhook"
}

resource "aws_api_gateway_method" "any" {
  rest_api_id   = "${aws_api_gateway_rest_api.webhook.id}"
  resource_id   = "${aws_api_gateway_rest_api.webhook.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "webhook_api" {
  rest_api_id             = "${aws_api_gateway_rest_api.webhook.id}"
  resource_id             = "${aws_api_gateway_rest_api.webhook.root_resource_id}"
  http_method             = "${aws_api_gateway_method.any.http_method}"
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${module.webhook_api_lambda.function_name}/invocations"
}

resource "aws_api_gateway_deployment" "prod" {
  depends_on        = ["aws_api_gateway_integration.webhook_api"]
  rest_api_id       = "${aws_api_gateway_rest_api.webhook.id}"
  stage_name        = "prod"
  stage_description = "${timestamp()}"                            // forces to 'create' a new deployment each run
}

resource "aws_lambda_permission" "allow_invocation_from_apigw" {
  function_name = "${module.webhook_api_lambda.function_name}"
  statement_id  = "allow_invocation_from_apigw"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_method.any.method_arn}"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.webhook.id}/*/*/"
}

# lambda
module "webhook_api_lambda" {
  source    = "github.com/rzhilkibaev/logging_lambda.tf"
  name      = "webhook_api"
  s3_bucket = "${var.s3_bucket}"
  s3_key    = "artifacts/webhook-api.zip"

  env_vars = {
    LOG_LEVEL = "DEBUG"
  }
}

module "allow_sns_publish" {
  source    = "github.com/rzhilkibaev/allow_sns_publish.tf"
  role_id   = "${module.webhook_api_lambda.role_id}"
  topic_arn = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:artifact_outdated"
}

data "aws_region" "current" {
  current = true
}

data "aws_caller_identity" "current" {}
