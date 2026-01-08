# SuperPlane GKE Installation with Terraform

This Terraform configuration deploys SuperPlane to Google Kubernetes Engine (GKE) with Cloud SQL
PostgreSQL.

## Prerequisites

Before you begin, ensure you have:

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0 installed
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated
- A GCP project with billing enabled
- Permission to create GKE clusters, Cloud SQL instances, and manage IAM

## Pre-deployment Steps

### 1. Authenticate with GCP

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Create a Static IP Address

Create a global static IP address for the ingress:

```bash
gcloud compute addresses create superplane-ip --global --ip-version=IPV4
```

Get the IP address:

```bash
gcloud compute addresses describe superplane-ip --global --format='get(address)'
```

### 3. Configure DNS

Create an A record in your DNS provider pointing your domain to the static IP address:

- **Type:** A
- **Name:** Your subdomain (e.g., `superplane`) or `@` for root domain
- **Value:** The static IP address from step 2
- **TTL:** 300 (or your preferred value)

Wait for DNS propagation (5-30 minutes typically).

## Usage

### 1. Create terraform.tfvars

Copy the example file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your configuration:

```hcl
project_id        = "my-gcp-project"
domain_name       = "superplane.example.com"
static_ip_name    = "superplane-ip"
letsencrypt_email = "admin@example.com"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

This will create:
- A GKE cluster
- A Cloud SQL PostgreSQL instance with VPC peering
- Kubernetes namespace and secrets
- cert-manager for SSL certificate management
- SuperPlane deployment with ingress

The deployment typically takes 15-20 minutes.

### 5. Configure kubectl

After deployment, configure kubectl:

```bash
# Use the command from Terraform output
gcloud container clusters get-credentials superplane --zone=us-central1-a --project=YOUR_PROJECT_ID
```

### 6. Verify the Installation

Check that all pods are running:

```bash
kubectl get pods -n superplane
```

Check the ingress status:

```bash
kubectl get ingress -n superplane
```

Check the certificate status:

```bash
kubectl get certificate -n superplane
```

## Accessing SuperPlane

Once the certificate is issued and DNS is configured, access SuperPlane at:

```
https://your-domain.com
```

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | (required) |
| `domain_name` | Domain name for SuperPlane | (required) |
| `static_ip_name` | Name of pre-created static IP | (required) |
| `letsencrypt_email` | Email for Let's Encrypt | (required) |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone | `us-central1-a` |
| `cluster_name` | GKE cluster name | `superplane` |
| `cluster_version` | Kubernetes version | `1.31` |
| `node_count` | Number of GKE nodes | `2` |
| `machine_type` | GKE node machine type | `e2-medium` |
| `db_instance_name` | Cloud SQL instance name | `superplane-db` |
| `db_tier` | Cloud SQL machine tier | `db-custom-2-4096` |
| `superplane_image_tag` | SuperPlane image tag | `stable` |

## Updating SuperPlane

To update SuperPlane to a new version, change the `superplane_image_tag` variable and run:

```bash
terraform apply
```

## Destroying the Infrastructure

To remove all resources:

```bash
terraform destroy
```

**Note:** The Cloud SQL instance has deletion protection enabled by default. To delete it, you must
first disable deletion protection:

```bash
gcloud sql instances patch superplane-db --no-deletion-protection
```

Then run `terraform destroy` again.

Don't forget to also delete the static IP if no longer needed:

```bash
gcloud compute addresses delete superplane-ip --global
```

## Troubleshooting

### Certificate not being issued

1. Check DNS resolution: `dig your-domain.com +short`
2. Verify the ClusterIssuer: `kubectl get clusterissuer letsencrypt-prod`
3. Check certificate status: `kubectl describe certificate -n superplane`
4. Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`

### Database connection issues

1. Check the database private IP: `terraform output database_private_ip`
2. Verify VPC peering: `gcloud compute networks peerings list`
3. Check pod logs: `kubectl logs -n superplane -l app=superplane`

### Pods not starting

1. Check pod status: `kubectl get pods -n superplane`
2. Describe the pod: `kubectl describe pod -n superplane <pod-name>`
3. Check secrets exist: `kubectl get secrets -n superplane`

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Static IP     │
                    │   (Global)      │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  GCE Ingress    │
                    │  (Load Balancer)│
                    └────────┬────────┘
                             │
┌────────────────────────────┼────────────────────────────────────┐
│                   GKE Cluster                                    │
│                            │                                     │
│                            ▼                                     │
│                   ┌─────────────────┐                           │
│                   │   SuperPlane    │                           │
│                   │   (Deployment)  │                           │
│                   └────────┬────────┘                           │
│                            │                                     │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             │ Private IP (VPC Peering)
                             ▼
                    ┌─────────────────┐
                    │   Cloud SQL     │
                    │   PostgreSQL    │
                    └─────────────────┘
```
