# Local AI Workload on Kubernetes (K3s)

This repository automates the provisioning of a local Kubernetes cluster and deploys a lightweight Large Language Model (LLM) inference server with a graphical web interface. 

The entire lifecycle—from bare VMs to a functional AI chat interface—is managed locally via **Terraform** and **GitOps-ready Kubernetes manifests**.

The README was generated with AI because all engineers hate READMEs (but it was checked for accuracy).

## 🏗️ Architecture Overview

The infrastructure consists of a 2-node K3s (Lightweight Kubernetes) cluster running on local virtual machines, serving an Ollama backend and an Open WebUI frontend.

* **Infrastructure Provisioning:** Terraform connects to the VMs via SSH, bootstraps the K3s Control Plane, extracts the join tokens, and attaches the Worker node.
* **Control Plane (Master Node):** `192.168.2.253`. Hosts the Kubernetes API, core DNS, and the Traefik Ingress Controller.
* **Data Plane (Worker Node):** `192.168.2.91`. Executes the heavy lifting. Hosts the `ollama` inference pod and the `open-webui` interface pod.
* **AI Workload:** Runs `TinyLlama` via **Ollama**. Model weights (~650MB) are cached locally using a `local-path` PersistentVolumeClaim (PVC) with a `Retain` policy to prevent re-downloading upon pod eviction or destruction.
* **Networking:** Internal cluster traffic routes through standard Kubernetes Services. External host traffic is secured and routed via a Traefik Ingress.

---

## 🛠️ Prerequisites

To run this automation, the executing machine (your local PC) must have the following tools installed:

1. **Terraform** (v1.0.0+)
2. **Kubectl**
3. **Make**
4. **sshpass:** *Crucial for automation.* This utility allows Terraform's `local-exec` provisioner to securely transfer cluster tokens in the background without hanging on interactive password prompts.
   * **Ubuntu/Debian:** `sudo apt install sshpass -y`
   * **macOS:** `brew install sshpass`
   * **Fedora/RHEL:** `sudo dnf install sshpass -y`

*Note: The target VMs must be accessible at `192.168.2.253` and `192.168.2.91` with the user `stratos` and password `123`.*

---

# 🚀 Deployment Instructions

## 1. Initialize Terraform
Downloads the required providers.

```bash
make init
```

*Alternatively:*
```bash
cd terraform && terraform init
```

---

## 2. Provision Cluster & Deploy Workloads
Builds the cluster and applies all YAML manifests found in the `k8s/` directory.

```bash
make deploy
```

*Alternatively:*
```bash
cd terraform && terraform apply -auto-approve
```

> **Note:**  
> The initial deployment may take **3–5 minutes**.  
> The Ollama pod must download the container image and pull the TinyLlama model into the persistent volume before the API becomes responsive.

---

# 🧪 Testing the AI Endpoint

Once the deployment is complete, you can test the raw LLM inference API by sending a direct curl request to the master node.  
We pass the host header `tinyllama.local` to satisfy the Ingress rules.

```bash
curl -X POST http://192.168.2.253/api/generate \
  -H "Content-Type: application/json" \
  -H "Host: tinyllama.local" \
  -d '{
    "model": "tinyllama",
    "prompt": "Explain Kubernetes in one simple sentence.",
    "stream": false
  }'
```

### Expected JSON Response

```json
{
  "model": "tinyllama",
  "created_at": "2026-04-22T17:00:00.000Z",
  "response": "Kubernetes is an open-source platform that automatically manages, scales, and deploys containerized applications.",
  "done": true
}
```

---

# 🌐 Accessing the Web UI

To interact with the AI via a ChatGPT-like graphical interface, we need to map the ingress hostname (`kube.worker.lab`) to your master node's IP address.

## 1. Update your local hosts file

Add the following line to your local machine's hosts file (requires Administrator/Sudo privileges):

- **Windows:** `C:\Windows\System32\drivers\etc\hosts`  
- **Mac/Linux:** `/etc/hosts`

```plaintext
192.168.2.253   kube.worker.lab
```

---

## 2. Open your Browser

Navigate to:

```
http://kube.worker.lab
```

> The first account you create on the Open WebUI login screen will automatically become the administrator account.  
> From there, you can select the `tinyllama` model from the dropdown and begin chatting.

---

# 🧹 Teardown

To destroy the AI workloads and completely uninstall K3s from both virtual machines, run:

```bash
make destroy
```