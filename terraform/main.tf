terraform {
  required_version = ">= 1.0.0"
}

resource "null_resource" "k3s_master" {
  triggers = {
    master_ip    = var.master_ip
    ssh_user     = var.ssh_user
    ssh_password = var.ssh_password
  }

  connection {
    type     = "ssh"
    host     = self.triggers.master_ip
    user     = self.triggers.ssh_user
    password = self.triggers.ssh_password
  }

  provisioner "remote-exec" {
    inline = [

      "echo '${self.triggers.ssh_password}' | sudo -S sh -c 'curl -sfL https://get.k3s.io | sh -'",
      "sleep 15",
      

      "echo '${self.triggers.ssh_password}' | sudo -S cp /etc/rancher/k3s/k3s.yaml /tmp/kubeconfig.yaml",
      "echo '${self.triggers.ssh_password}' | sudo -S chmod 644 /tmp/kubeconfig.yaml",
      "echo '${self.triggers.ssh_password}' | sudo -S sed -i 's/127.0.0.1/${self.triggers.master_ip}/g' /tmp/kubeconfig.yaml",
      

      "echo '${self.triggers.ssh_password}' | sudo -S cp /var/lib/rancher/k3s/server/node-token /tmp/node-token.txt",
      "echo '${self.triggers.ssh_password}' | sudo -S chmod 644 /tmp/node-token.txt"
    ]
  }

  provisioner "local-exec" {

    command = <<EOT
      sshpass -p '${self.triggers.ssh_password}' scp -o StrictHostKeyChecking=no ${self.triggers.ssh_user}@${self.triggers.master_ip}:/tmp/node-token.txt ./node-token.txt
      sshpass -p '${self.triggers.ssh_password}' scp -o StrictHostKeyChecking=no ${self.triggers.ssh_user}@${self.triggers.master_ip}:/tmp/kubeconfig.yaml ./kubeconfig.yaml
    EOT
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "echo '${self.triggers.ssh_password}' | sudo -S /usr/local/bin/k3s-uninstall.sh || true"
    ]
  }
}

resource "null_resource" "k3s_worker" {
  depends_on = [null_resource.k3s_master]

  triggers = {
    master_ip    = var.master_ip
    worker_ip    = var.worker_ip
    ssh_user     = var.ssh_user
    ssh_password = var.ssh_password
  }

  connection {
    type     = "ssh"
    host     = self.triggers.worker_ip
    user     = self.triggers.ssh_user
    password = self.triggers.ssh_password
  }


  provisioner "file" {
    source      = "./node-token.txt"
    destination = "/tmp/node-token.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "TOKEN=$(cat /tmp/node-token.txt | tr -d '\n')",
      "echo '${self.triggers.ssh_password}' | sudo -S sh -c \"curl -sfL https://get.k3s.io | K3S_URL=https://${self.triggers.master_ip}:6443 K3S_TOKEN=$TOKEN sh -\""
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "echo '${self.triggers.ssh_password}' | sudo -S /usr/local/bin/k3s-agent-uninstall.sh || true"
    ]
  }
}

resource "null_resource" "k8s_workloads" {
  depends_on = [null_resource.k3s_worker]
  triggers = {
    manifests_hash = sha1(join("", [for f in fileset("../k8s", "*.yaml"): filesha1("../k8s/${f}")]))
  }

  provisioner "local-exec" {
    command = <<EOT
      for file in $(ls ../k8s/*.yaml | sort); do
        echo "Applying $file..."
        KUBECONFIG=./kubeconfig.yaml kubectl apply -f "$file"
        sleep 2
      done
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "KUBECONFIG=./kubeconfig.yaml kubectl delete -f ../k8s/ --ignore-not-found=true"
  }
}