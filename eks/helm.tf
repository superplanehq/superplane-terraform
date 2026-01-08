# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Role
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.superplane.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_eks_cluster.superplane.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.aws_load_balancer_controller.name
}

# Additional policy for ALB controller
resource "aws_iam_role_policy" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-alb-controller-policy"
  role = aws_iam_role.aws_load_balancer_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeInternetGateways",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller Helm Release
# -----------------------------------------------------------------------------

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  depends_on = [
    aws_eks_node_group.superplane,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

# -----------------------------------------------------------------------------
# cert-manager Helm Release
# -----------------------------------------------------------------------------

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    aws_eks_node_group.superplane
  ]
}

# -----------------------------------------------------------------------------
# ClusterIssuer for Let's Encrypt
# -----------------------------------------------------------------------------

resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = "alb"
            }
          }
        }]
      }
    }
  }

  depends_on = [
    helm_release.cert_manager
  ]
}

# -----------------------------------------------------------------------------
# SuperPlane Helm Release
# -----------------------------------------------------------------------------

resource "helm_release" "superplane" {
  name             = "superplane"
  repository       = "oci://ghcr.io/superplanehq"
  chart            = "superplane-chart"
  namespace        = var.superplane_namespace
  create_namespace = false

  # Database configuration
  set {
    name  = "database.secretName"
    value = "superplane-db-credentials"
  }

  set {
    name  = "database.host"
    value = aws_db_instance.superplane.address
  }

  set {
    name  = "database.port"
    value = "5432"
  }

  set {
    name  = "database.username"
    value = var.db_username
  }

  set_sensitive {
    name  = "database.password"
    value = local.db_password
  }

  set {
    name  = "database.ssl"
    value = "true"
  }

  set {
    name  = "database.local.enabled"
    value = "false"
  }

  # Image configuration
  set {
    name  = "image.registry"
    value = "ghcr.io/superplanehq"
  }

  set {
    name  = "image.name"
    value = "superplane"
  }

  set {
    name  = "image.tag"
    value = var.superplane_image_tag
  }

  set {
    name  = "image.pullPolicy"
    value = "IfNotPresent"
  }

  # Domain configuration
  set {
    name  = "domain.name"
    value = var.domain_name
  }

  # Ingress configuration for AWS ALB
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.className"
    value = "alb"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
  }

  # SSL configuration
  set {
    name  = "ingress.ssl.enabled"
    value = "true"
  }

  set {
    name  = "ingress.ssl.type"
    value = "cert-manager"
  }

  set {
    name  = "ingress.ssl.certManager.issuerRef.name"
    value = "letsencrypt-prod"
  }

  set {
    name  = "ingress.ssl.certManager.issuerRef.kind"
    value = "ClusterIssuer"
  }

  set {
    name  = "ingress.ssl.certManager.secretName"
    value = "superplane-tls-secret"
  }

  # Authentication (disabled by default)
  set {
    name  = "authentication.github.enabled"
    value = "false"
  }

  set {
    name  = "authentication.google.enabled"
    value = "false"
  }

  # Telemetry (disabled by default)
  set {
    name  = "telemetry.opentelemetry.enabled"
    value = "false"
  }

  set {
    name  = "telemetry.opentelemetry.endpoint"
    value = ""
  }

  # Secrets
  set {
    name  = "session.secretName"
    value = "superplane-session"
  }

  set {
    name  = "jwt.secretName"
    value = "superplane-jwt"
  }

  set {
    name  = "encryption.secretName"
    value = "superplane-encryption"
  }

  depends_on = [
    kubernetes_namespace.superplane,
    kubernetes_secret.db_credentials,
    kubernetes_secret.session,
    kubernetes_secret.jwt,
    kubernetes_secret.encryption,
    helm_release.cert_manager,
    helm_release.aws_load_balancer_controller,
    kubernetes_manifest.letsencrypt_issuer,
    aws_db_instance.superplane
  ]
}
