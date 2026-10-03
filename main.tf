# ==============================================================================
# ÉTAPE 1 : Configuration des outils AWS et du fournisseur
# ==============================================================================
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

data "aws_caller_identity" "compte_actuel" {}


# ==============================================================================
# ÉTAPE 2 : Déclaration des variables de secrets (Discord)
# ==============================================================================
variable "url_webhook_discord" {
  type        = string
  description = "URL du Webhook Discord pour recevoir les alertes"
  sensitive   = true
  default     = ""
}

variable "id_utilisateur_discord" {
  type        = string
  description = "ID Discord de l'utilisateur à mentionner"
  sensitive   = true
  default     = ""
}


# ==============================================================================
# ÉTAPE 3 : Création de l'utilisateur piège (Le Honey-Token / L'appât)
# ==============================================================================
resource "aws_iam_user" "utilisateur_piege" {
  name = "service-admin-sauvegarde"
  tags = {
    Type        = "Cle-Piege"
    Description = "Compte leurre - Ne pas utiliser"
  }
}

resource "aws_iam_access_key" "cle_piege" {
  user = aws_iam_user.utilisateur_piege.name
}


# ==============================================================================
# ÉTAPE 4 : Création de la traçabilité (Bucket S3 + CloudTrail)
# ==============================================================================
resource "random_id" "suffixe_dossier" {
  byte_length = 4
}

resource "aws_s3_bucket" "dossier_journaux" {
  bucket        = "journaux-surveillance-cle-piege-${random_id.suffixe_dossier.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "politique_dossier_journaux" {
  bucket = aws_s3_bucket.dossier_journaux.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VerificationDroitsCloudTrail"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.dossier_journaux.arn
      },
      {
        Sid    = "AutoriserEcritureLogsCloudTrail"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.dossier_journaux.arn}/AWSLogs/${data.aws_caller_identity.compte_actuel.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "suivi_activite_piege" {
  name                          = "suivi-activite-cle-piege"
  s3_bucket_name                = aws_s3_bucket.dossier_journaux.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  depends_on = [aws_s3_bucket_policy.politique_dossier_journaux]
}


# ==============================================================================
# ÉTAPE 5 : Affichage des identifiants pièges (Outputs)
# ==============================================================================
output "identifiant_cle_piege" {
  value       = aws_iam_access_key.cle_piege.id
  description = "Identifiant de la clé d'accès piège (Access Key ID)"
}

output "cle_secrete_piege" {
  value       = aws_iam_access_key.cle_piege.secret
  sensitive   = true
  description = "Clé d'accès secrète piège (Secret Access Key)"
}


# ==============================================================================
# ÉTAPE 6 : Règle de détection EventBridge et Alerte Lambda
# ==============================================================================
data "archive_file" "zip_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_iam_role" "role_lambda" {
  name = "role-execution-lambda-alerte"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "logs_lambda" {
  role       = aws_iam_role.role_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Fonction Lambda configurée avec les variables d'environnement
resource "aws_lambda_function" "lambda_alerte" {
  filename         = data.archive_file.zip_lambda.output_path
  function_name    = "detection-honeytoken-alerte"
  role             = aws_iam_role.role_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.zip_lambda.output_base64sha256

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.url_webhook_discord
      DISCORD_USER_ID     = var.id_utilisateur_discord
    }
  }
}

resource "aws_cloudwatch_event_rule" "regle_detection_piege" {
  name        = "regle-detection-cle-piege"
  description = "Déclenche une alerte si le Honey-Token est utilisé"

  event_pattern = jsonencode({
    "detail-type" = ["AWS API Call via CloudTrail"],
    "detail" = {
      "userIdentity" = {
        "userName" = ["service-admin-sauvegarde"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "cible_lambda" {
  rule      = aws_cloudwatch_event_rule.regle_detection_piege.name
  target_id = "EnvoyerVersLambda"
  arn       = aws_lambda_function.lambda_alerte.arn
}

resource "aws_lambda_permission" "autoriser_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_alerte.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.regle_detection_piege.arn
}