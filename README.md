# Trading Service Kubernetes Deployment

This repository is a Kubernetes-based migration of the original [trading-service](https://github.com/roarceus/trading-service) app. It leverages modern cloud-native technologies to deploy a Go-based trading service with automated database migrations, enhanced observability, and continuous deployment capabilities.

---

## Overview

The trading service is a RESTful API built in Go that processes trade orders. In this migration, the backend remains unchanged (with the same `cmd/` and `internal/` directories and Dockerfile), but the deployment architecture has been completely revamped to run on AWS EKS with RDS for PostgreSQL. Key components include:

- **Kubernetes (EKS)** for orchestration
- **RDS PostgreSQL** for persistent order data storage
- **Helm Charts** for application deployment and configuration management
- **Argo CD** for continuous deployment and GitOps
- **Istio** for service mesh, observability, and traffic management
- **Terraform** for provisioning the EKS cluster and RDS instance

The CI/CD pipeline is now managed through GitHub Actions, which performs Docker image builds, pushes, and Terraform validations on pull requests and commits.

---

## Tech Stack

- **Golang** (using Gin/Echo framework) for REST API development
- **PostgreSQL (RDS)** for database storage
- **Docker** for containerization
- **AWS EKS** for managed Kubernetes clusters
- **Helm** for packaging and deploying Kubernetes applications
- **Argo CD** for GitOps-based continuous deployment
- **Istio** for service mesh and observability
- **Terraform** for infrastructure provisioning
- **GitHub Actions** for CI/CD pipelines

---

## Repository Structure

```
trading-service-k8s/
├── .github/workflows/
│   ├── terraform-validate.yml    # Validates Terraform configuration on PRs
│   ├── docker-build.yml          # Builds Docker image on PRs
│   ├── docker-push.yml           # Pushes Docker image on push to main branch
│
├── charts/
│   ├── trading-service/
│       ├── Chart.yaml            # Helm chart metadata
│       ├── values.yaml           # Default Helm chart values
│       └── templates/
│           ├── _helpers.tpl      # Template helper definitions
│           ├── deployment.yaml   # Kubernetes Deployment definition
│           ├── istio-gateway.yaml# Istio Gateway configuration
│           ├── migrations-configmap.yaml # ConfigMap for database migrations
│           └── service.yaml      # Kubernetes Service definition
│
├── cmd/
│   └── trading-service/
│       └── main.go               # Application entry point
│
├── internal/
│   ├── app/
│   │   └── server.go             # Server setup and routing
│   ├── config/
│   │   └── config.go             # Configuration management
│   ├── database/
│   │   └── database.go           # Database connection and migrations
│   ├── model/
│   │   └── order.go              # Order struct and schema
│   ├── repository/
│   │   └── repository.go         # Order repository methods
│   └── websocket/
│       └── hub.go                # WebSocket implementation
│
├── k8s/
│   ├── main.tf                   # Root Terraform configuration for K8s infra
│   ├── variables.tf              # Global Terraform variables
│   ├── outputs.tf                # Global Terraform outputs
│   ├── eks/                      # EKS cluster related Terraform files
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── rds/                      # RDS instance related Terraform files
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── argocd/                   # Argo CD application manifest
│       └── trading-service.yaml
│
├── Dockerfile                    # Docker image creation
└── README.md                     # This file
```

---

## CI/CD Pipeline

The repository utilizes GitHub Actions to automate key processes:

- **terraform-validate.yml:** Runs Terraform configuration validation on pull requests to ensure that infrastructure definitions are syntactically correct and follow best practices.
- **docker-build.yml:** Builds the Docker image during pull requests to catch any build issues early.
- **docker-push.yml:** Pushes the Docker image to DockerHub when code is merged into the `main` branch.

These workflows ensure that only valid changes are promoted, keeping the deployment pipeline smooth and reliable.

---

## Deployment Process

Below are the steps required to deploy the trading service on EKS. Each command is explained with its purpose:

### 1. Docker Image Build & Push

Before deploying to Kubernetes, build the Docker image and push it to DockerHub.

```sh
# Build the Docker image locally
docker build -t trading-service-k8s .

# Tag the Docker image for DockerHub
docker tag trading-service-k8s:latest <dockerhub-username>/trading-service-k8s:latest

# Push the Docker image to DockerHub
docker push <dockerhub-username>/trading-service-k8s:latest
```

*These commands ensure your application container image is available in DockerHub for Kubernetes deployments.*

---

### 2. Provision Infrastructure with Terraform

Navigate to the `k8s` folder and apply the Terraform configuration to provision the EKS cluster and RDS PostgreSQL instance.

```sh
terraform apply -var-file=trading.tfvars
```

**Sample `trading.tfvars`:**

```hcl
region       = "us-east-1"
cluster_name = "trading-cluster"
db_name      = "trading_db"
db_username  = "username"
db_password  = "password"
```

*This step provisions the required infrastructure components, including the EKS cluster and RDS instance, using Terraform.*

---

### 3. Configure Local Kubernetes CLI Access

After the EKS cluster is up, update your local kubeconfig to access the cluster:

```sh
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

*This command fetches the cluster's configuration and updates your local kubeconfig, allowing you to manage the cluster with `kubectl`.*

---

### 4. Install Istio for Service Mesh and Observability

Install Istio to manage traffic routing and monitor service interactions:

```sh
istioctl install --set profile=demo -y
```

Then enable sidecar injection in the default namespace (disable if application pods fail):

```sh
kubectl label namespace default istio-injection=enabled --overwrite
```

*Istio provides advanced traffic management, security, and observability for your microservices.*

---

### 5. Install Argo CD for Continuous Deployment

Create the `argocd` namespace and install Argo CD:

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

You can check the status of Istio and Argo CD pods:

```sh
kubectl get pods -n istio-system
kubectl get pods -n argocd
```

Port-forward to access the Argo CD web UI:

```sh
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access Argo CD at [https://localhost:8080](https://localhost:8080).

Retrieve the initial admin password:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

*Argo CD provides GitOps-based continuous delivery, enabling automated application deployments on your EKS cluster.*

---

### 6. Deploy the Trading Service

You have two options for deploying the trading service:

#### Option A: Deploy with Helm Locally

```sh
helm install trading-service ./charts/trading-service --namespace default
```

*This command deploys the trading service using the Helm chart, managing configurations and Kubernetes resources.*

#### Option B: Deploy via Argo CD

Apply the Argo CD manifest:

```sh
kubectl apply -f k8s/argocd/trading-service.yaml -n argocd
```

Or create the application directly using the Argo CD CLI:

```sh
argocd app create trading-service \
  --repo https://github.com/yourusername/trading-service-k8s.git \
  --path charts/trading-service \
  --dest-namespace default \
  --dest-server https://kubernetes.default.svc
```

*This method leverages GitOps to synchronize your desired state with the live cluster.*

---

### 7. Verify the Deployment

Check the status of deployments and pods:

```sh
kubectl get deployments -n default
kubectl get pods -n default
```

*Ensure that the trading service is running correctly on your cluster.*

---

### 8. Updating the Application

To deploy updates, choose one of the following methods:

- **Using Helm:**

  ```sh
  helm upgrade trading-service ./charts/trading-service --namespace default
  ```

- **Using kubectl:**

  ```sh
  kubectl rollout restart deployment trading-service-trading-service -n default
  ```

- **Using Argo CD:**

  ```sh
  argocd app sync trading-service
  ```

*These commands trigger a rolling update of the application with the latest configuration and Docker image.*

---

### 9. Stopping the Service

To stop the service, you can remove the deployment by any of the following methods:

- **With Helm:**

  ```sh
  helm uninstall trading-service --namespace default
  ```

- **With kubectl:**

  ```sh
  kubectl delete namespace argocd
  kubectl delete deployment trading-service-trading-service -n default
  ```

- **With Argo CD:**

  ```sh
  argocd app delete trading-service --cascade
  ```

*These commands remove the trading service and related resources from the cluster.*

---

### 10. Destroying the Infrastructure

Finally, to tear down the infrastructure created by Terraform:

```sh
terraform destroy --var-file=trading.tfvars -target=module.eks
```

*This command destroys the EKS cluster and associated resources, ensuring a clean environment shutdown.*

---

## API Endpoints

### 1. Submit Trade Order

**Endpoint:**  
`POST http://<cluster-ip>:<port>/orders`

**Request Body:**

```json
{
  "symbol": "GOOGL",
  "price": 150.50,
  "quantity": 100,
  "order_type": "SELL"
}
```

**Response:**

```json
{
  "id": 1,
  "symbol": "GOOGL",
  "price": 150.5,
  "quantity": 100,
  "order_type": "SELL",
  "status": "PENDING",
  "created_at": "2025-02-24T21:02:49.665972Z",
  "updated_at": "2025-02-24T21:02:49.665972Z"
}
```

### 2. Get All Orders

**Endpoint:**  
`GET http://<cluster-ip>:<port>/orders`

**Response:**

```json
[
  {
    "id": 1,
    "symbol": "GOOGL",
    "price": 150.5,
    "quantity": 100,
    "order_type": "SELL",
    "status": "PENDING",
    "created_at": "2025-02-24T21:02:49.665972Z",
    "updated_at": "2025-02-24T21:02:49.665972Z"
  }
]
```

*These endpoints expose the trading service API for submitting and querying trade orders.*

---

## References

- [Gin Web Framework](https://gin-gonic.com/)
- [Docker Documentation](https://docs.docker.com/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Helm Documentation](https://helm.sh/docs/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Terraform Documentation](https://www.terraform.io/)

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

*This repository is a modern evolution of the original [trading-service](https://github.com/roarceus/trading-service) project, now optimized for cloud-native deployments on Kubernetes with enhanced scalability, reliability, and observability.*