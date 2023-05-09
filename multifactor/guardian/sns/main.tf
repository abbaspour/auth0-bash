# User
resource "aws_iam_user" "auth0_guardian_agent" {
  name = "auth0_guardian_agent"
}

resource "aws_iam_access_key" "auth0_guardian_agent_access_key" {
  user = aws_iam_user.auth0_guardian_agent.name
}

resource "aws_iam_user_policy" "sns" {
  name = "guardian-push-notification-policy"
  user   = aws_iam_user.auth0_guardian_agent.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": [
        "${var.sns_apns_platform_application_arn}",
        "${aws_sns_topic.fcm.arn}"
      ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "sns:DeleteEndpoint",
            "sns:SetEndpointAttributes",
            "sns:ListEndpointsByPlatformApplication",
            "sns:GetEndpointAttributes",
            "sns:CreatePlatformEndpoint"
        ],
        "Resource": [
            "*"
        ]
    }
  ]
}
EOF
}

# APNS
/*
resource "aws_sns_topic" "apns" {
  name = "guardian-push-notification-apns-topic"
}

resource "aws_sqs_queue" "apns" {
  name = "guardian-push-notification-apns-queue"
}

resource "aws_sns_topic_subscription" "apns_sqs_target" {
  topic_arn = aws_sns_topic.apns.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.apns.arn
}

resource "aws_sns_platform_application" "apns_application" {
  name                = "apns_application"
  platform            = "APNS_SANDBOX"
  platform_credential = file("${path.module}/../apns/certificate.pem")
  platform_principal  = file("${path.module}/../apns/private-key.pem")
}
*/

# FCM
resource "aws_sns_topic" "fcm" {
  name = "guardian-push-notification-fcm-topic"
}

resource "aws_sqs_queue" "fcm" {
  name = "guardian-push-notification-fcm-queue"
}

resource "aws_sns_topic_subscription" "fcm_sqs_target" {
  topic_arn = aws_sns_topic.fcm.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.fcm.arn
}

# Outputs
output "aws_region" {
  value = var.region
}

output "fcm_arn" {
  value = aws_sns_topic.fcm.arn
}

output "aws_access_key_id" {
  value = aws_iam_access_key.auth0_guardian_agent_access_key.id
}

/*
output "aws_access_key_secret" {
  value = aws_iam_access_key.auth0_guardian_agent_access_key.secret
  sensitive = true
}

output "apns_queue_url" {
  value = aws_sqs_queue.apns.url
}
*/

output "fcm_queue_url" {
  value = aws_sqs_queue.fcm.url
}


# Auth0
resource "auth0_guardian" "my_guardian" {
  policy        = "all-applications"
  email = false
  push {
    enabled = true
    provider = "sns"

    amazon_sns {
      aws_region                        = var.region
      aws_access_key_id                 = aws_iam_access_key.auth0_guardian_agent_access_key.id
      aws_secret_access_key             = aws_iam_access_key.auth0_guardian_agent_access_key.secret
      sns_apns_platform_application_arn = var.sns_apns_platform_application_arn # aws_sns_topic.apns.arn
      sns_gcm_platform_application_arn  = aws_sns_topic.fcm.arn
    }
    custom_app {
      app_name        = var.guardian_app_name
      #apple_app_link  = "https://itunes.apple.com/us/app/my-app/id123121"
      #google_app_link = "https://play.google.com/store/apps/details?id=com.my.app"
    }
  }
}
