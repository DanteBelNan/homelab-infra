#!/usr/bin/env bash

set -euo pipefail

# Colores para salida limpia
GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[BOOTSTRAP] $1${NC}"
}

log "1. Actualizando paquetes del sistema..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    ca-certificates \
    gnupg \
    lsb-release \
    net-tools \
    htop \
    ufw

log "2. Instalando Docker Engine..."
if ! command -v docker &> /dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Permitir usar docker al usuario actual sin sudo
    sudo usermod -aG docker "$USER"
else
    log "Docker ya está instalado. Omitiendo."
fi

log "3. Instalando Helm..."
if ! command -v helm &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    log "Helm ya está instalado. Omitiendo."
fi

log "4. Instalando HashiCorp Terraform..."
if ! command -v terraform &> /dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com/$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update -y
    sudo apt-get install -y terraform
else
    log "Terraform ya está instalado. Omitiendo."
fi

log "5. Instalando K3s..."
if ! command -v k3s &> /dev/null; then
    # Instalación de K3s con permisos de lectura del kubeconfig para el usuario
    curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
    
    # Configurar KUBECONFIG para el usuario actual
    mkdir -p "$HOME/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    sudo chown "$USER:$USER" "$HOME/.kube/config"
    echo "export KUBECONFIG=$HOME/.kube/config" >> "$HOME/.bashrc"
else
    log "K3s ya está instalado. Omitiendo."
fi

log "6. Instalando Nginx no-cluster (Host Reverse Proxy)..."
if ! command -v nginx &> /dev/null; then
    sudo apt-get install -y nginx
    sudo systemctl enable --now nginx
else
    log "Nginx ya está instalado. Omitiendo."
fi

log "=================================================="
log "Bootstrap finalizado con éxito."
log "RECOMENDACIÓN: Reiniciá sesión para que impacten los permisos del grupo 'docker'."
log "=================================================="