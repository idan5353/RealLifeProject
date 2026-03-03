# 🚀 Task Platform — Full-Stack DevOps Project on AWS

A production-grade task management SaaS application built to demonstrate end-to-end DevOps practices on AWS — from infrastructure provisioning to GitOps deployment, observability, and cost optimization.

![diagram](https://github.com/user-attachments/assets/ea51ee48-a29e-4452-8e49-ac03aa1fca94)


---

## 📐 Architecture Overview

Developer (git push)
↓
GitHub (develop branch)
↓ webhook
Jenkins (CI — lint → test → build → ECR push → update Helm values)
↓ git push values.yaml
GitHub (updated image tag)
↓ ArgoCD polls every 3 min
ArgoCD (GitOps CD — helm upgrade)
↓
EKS Cluster (dev namespace)
├── Backend — Node.js/Express → RDS PostgreSQL
├── Frontend — React/Vite → Nginx
└── ALB → internet traffic

text
Prometheus → scrapes metrics every 15s
Grafana    → dashboards + Alertmanager → Slack alerts
text

![apppic](https://github.com/user-attachments/assets/3745b22a-83b2-48ca-b2fc-dbb03fe09f27)

---

## 🛠️ Tech Stack

### Application
| Layer | Technology |
|---|---|
| Frontend | React, Vite, Nginx |
| Backend | Node.js, Express, JWT Auth |
| Database | PostgreSQL 16 (AWS RDS) |

### Infrastructure (IaC)
| Tool | Purpose |
|---|---|
| Terraform | All AWS resources — VPC, EKS, RDS, ECR, S3, IAM |
| AWS EKS | Managed Kubernetes (v1.29, Spot instances) |
| AWS RDS | Managed PostgreSQL with encryption + Secrets Manager |
| AWS ECR | Private container registries |
| AWS ALB | Internet-facing ingress via AWS Load Balancer Controller |
| AWS Secrets Manager | Secure credential storage with IRSA access |
| S3 + DynamoDB | Terraform remote state + locking |

### Kubernetes & Deployment
| Tool | Purpose |
|---|---|
| Helm | Kubernetes package manager (custom charts) |
| ArgoCD | GitOps continuous delivery |
| HPA | Horizontal Pod Autoscaler (2–5 replicas) |
| IRSA | IAM Roles for Service Accounts (least-privilege) |

### CI/CD
| Tool | Purpose |
|---|---|
| Jenkins | CI pipeline — lint, test, Docker build, ECR push |
| GitHub | Source of truth + ArgoCD sync target |
| Docker | Multi-stage production images |

### Observability
| Tool | Purpose |
|---|---|
| Prometheus | Metrics collection (cluster + app) |
| Grafana | Dashboards — Kubernetes, Nodes, App metrics |
| Alertmanager | Slack alerts — pod crashes, high CPU, HPA saturation |
| prom-client | Custom Node.js metrics (`/metrics` endpoint) |


## 🚀 How to Deploy

### Prerequisites
- AWS CLI configured
- Terraform >= 1.6
- kubectl + helm installed
- Docker running

### 1. Provision Infrastructure
```bash
cd terraform/
terraform init
terraform apply
2. Configure kubectl
bash
aws eks update-kubeconfig --region us-east-1 --name task-platform-cluster
3. Install Cluster Add-ons
bash
# AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=task-platform-cluster

# ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
4. Deploy Applications
bash
# Backend
helm upgrade --install backend ./helm/backend -n dev --create-namespace

# Frontend
helm upgrade --install frontend ./helm/frontend -n dev
5. CI/CD — Jenkins Pipeline
Jenkins is configured with a webhook on the develop branch. On every push:

Lint & test

Build Docker images

Push to ECR

Update values.yaml with new image tag

Push to GitHub → ArgoCD auto-syncs within 3 minutes

```



# 📊 Observability

## Grafana Dashboards

Access Grafana via port-forward:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
```

Open in your browser:

http://localhost:3000

Default credentials:
- Username: admin
- Password: prom-operator

### Available Dashboards

- Kubernetes Cluster Overview
- Node Exporter (CPU, memory, disk)
- Pod Metrics
- Task Platform — Custom Application Dashboard

---

## 🚨 Alertmanager Slack Alerts

### Configured Alerts

- 🔴 Pod CrashLooping
- 🟡 High CPU / Memory usage
- 🔴 Backend service down
- 🟡 HPA at maximum replicas

---

# 💰 Infrastructure Cost

| Resource | Monthly Cost |
|----------|-------------|
| EKS Control Plane | $7.20 |
| 2x t3.medium (Spot) | ~$12 |
| RDS db.t3.micro | ~$13 |
| ALB | ~$5 |
| ECR + S3 + Secrets Manager | ~$1 |
| **Total** | **~$38/month** |

### 💡 Cost Optimization Notes

- Spot instances save ~60% vs On-Demand
- No NAT Gateways used — saving ~$32/month vs standard VPC design

---

# 🔐 Security Highlights

- IRSA — Backend pods access AWS services via IAM role (no static credentials)
- AWS Secrets Manager — RDS password auto-generated, never stored in code or environment variables
- ECR Lifecycle Policies — Old images auto-deleted automatically
- S3 Public Access Blocked — Assets bucket not publicly accessible
- RDS Encryption at Rest — Enabled by default

---

# 🗺️ Project Roadmap

-✅ Phase 1 — Git structure
-✅ Phase 2 — Terraform
-✅ Phase 3 — Production Dockerfiles + ECR
-✅ Phase 4 — Helm charts live on EKS
-✅ Phase 5 — Jenkins CI pipeline
-✅ Phase 6 — ArgoCD GitOps
-✅ Phase 7 — Monitoring


---

# 👤 Author

Idan Uziel
