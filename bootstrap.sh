#!/usr/bin/env bash

set -euo pipefail

# Colores para salida limpia
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[BOOTSTRAP] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log "1. Actualizando paquetes del sistema e instalando utilitarios base..."
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

log "2. Verificando Docker..."
if ! command -v docker &> /dev/null; then
    log "Instalando Docker Engine..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo usermod -aG docker "$USER"
else
    log "Docker ya está instalado ($(docker --version)). Omitiendo."
fi

log "3. Verificando Helm..."
if ! command -v helm &> /dev/null; then
    log "Instalando Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    log "Helm ya está instalado ($(helm version --short)). Omitiendo."
fi

log "4. Verificando HashiCorp Terraform..."
if ! command -v terraform &> /dev/null; then
    log "Instalando Terraform..."
    sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    
    UBUNTU_CODENAME=$(lsb_release -cs)
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${UBUNTU_CODENAME} main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
    
    sudo apt-get update -y
    sudo apt-get install -y terraform
else
    log "Terraform ya está instalado ($(terraform -v | head -n 1)). Omitiendo."
fi

log "5. Verificando K3s..."
if ! command -v k3s &> /dev/null; then
    log "Instalando K3s..."
    # Instalación de K3s con permisos de lectura del kubeconfig para el usuario
    curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
    
    # Configurar KUBECONFIG para el usuario actual
    mkdir -p "$HOME/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    sudo chown "$USER:$USER" "$HOME/.kube/config"
    
    if ! grep -q "KUBECONFIG" "$HOME/.bashrc"; then
        echo "export KUBECONFIG=\$HOME/.kube/config" >> "$HOME/.bashrc"
    fi
else
    log "K3s ya está instalado. Omitiendo."
fi

log "6. Verificando Nginx (Host Reverse Proxy)..."
if ! command -v nginx &> /dev/null; then
    log "Instalando Nginx..."
    sudo apt-get install -y nginx
    sudo systemctl enable --now nginx
else
    log "Nginx ya está instalado ($(nginx -v 2>&1)). Omitiendo."
fi

log "7. Verificando k9s (CLI Dashboard para Kubernetes)..."
if ! command -v k9s &> /dev/null; then
    log "Instalando k9s..."
    # Descargar la última versión del binario para Linux amd64
    curl -sL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz -o /tmp/k9s.tar.gz
    
    # Descomprimir y mover al PATH del sistema
    tar -zxvf /tmp/k9s.tar.gz -C /tmp k9s
    sudo mv /tmp/k9s /usr/local/bin/
    
    # Limpiar archivo temporal
    rm -f /tmp/k9s.tar.gz
else
    log "k9s ya está instalado ($(k9s version --short 2>/dev/null || echo "installed")). Omitiendo."
fi

log "=================================================="
log "Bootstrap finalizado con éxito."
warn "IMPORTANTE: Si es la primera vez que se añade tu usuario a 'docker', ejecutá 'newgrp docker' o reiniciá sesión."
log "=================================================="