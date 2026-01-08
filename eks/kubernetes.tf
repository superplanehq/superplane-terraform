# -----------------------------------------------------------------------------
# Kubernetes Namespace
# -----------------------------------------------------------------------------

resource "kubernetes_namespace" "superplane" {
  metadata {
    name = var.superplane_namespace
  }

  depends_on = [
    aws_eks_node_group.superplane
  ]
}

# -----------------------------------------------------------------------------
# Database Credentials Secret
# -----------------------------------------------------------------------------

resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "superplane-db-credentials"
    namespace = kubernetes_namespace.superplane.metadata[0].name
  }

  data = {
    DB_HOST         = aws_db_instance.superplane.address
    DB_PORT         = "5432"
    DB_NAME         = var.db_name
    DB_USERNAME     = var.db_username
    DB_PASSWORD     = local.db_password
    POSTGRES_DB_SSL = "true"
  }
}

# -----------------------------------------------------------------------------
# Session Secret
# -----------------------------------------------------------------------------

resource "kubernetes_secret" "session" {
  metadata {
    name      = "superplane-session"
    namespace = kubernetes_namespace.superplane.metadata[0].name
  }

  data = {
    SESSION_SECRET = random_password.session_secret.result
  }
}

# -----------------------------------------------------------------------------
# JWT Secret
# -----------------------------------------------------------------------------

resource "kubernetes_secret" "jwt" {
  metadata {
    name      = "superplane-jwt"
    namespace = kubernetes_namespace.superplane.metadata[0].name
  }

  data = {
    JWT_SECRET = random_password.jwt_secret.result
  }
}

# -----------------------------------------------------------------------------
# Encryption Key Secret
# -----------------------------------------------------------------------------

resource "kubernetes_secret" "encryption" {
  metadata {
    name      = "superplane-encryption"
    namespace = kubernetes_namespace.superplane.metadata[0].name
  }

  data = {
    ENCRYPTION_KEY = random_password.encryption_key.result
  }
}
