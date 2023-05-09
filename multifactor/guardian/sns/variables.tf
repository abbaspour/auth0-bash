variable "region" {
  default = "ap-southeast-2"
}

variable "auth0_domain" {
}

variable "auth0_tf_client_id" {
}

variable "auth0_tf_client_secret" {
  sensitive = true
}

variable "guardian_app_name" {
  default = "auth0-bash"
}

variable "sns_apns_platform_application_arn" {
}