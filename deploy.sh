#!/bin/bash

# ==============================================================================
# Script: deploy.sh
# Deskripsi: Mengotomatiskan deployment manifest Kubernetes ke klaster lokal.
# Kelompok: Kelompok 1 - DevOps
# ==============================================================================

# Hentikan script jika terjadi error
set -e

# Warna output terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}    STARTING KUBERNETES MANIFEST DEPLOYMENT           ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Menyiapkan Namespace
echo -e "\n${YELLOW}[Langkah 1/3] Menyiapkan Namespace...${NC}"
if [ -f "kubernetes/namespace-dev.yaml" ] && [ -f "kubernetes/namespace-prod.yaml" ]; then
    kubectl apply -f kubernetes/namespace-dev.yaml
    kubectl apply -f kubernetes/namespace-prod.yaml
    echo -e "${GREEN}✓ Namespace taskflow-dev dan taskflow-prod berhasil dibuat/diperbarui.${NC}"
else
    echo -e "${YELLOW}⚠️ File namespace tidak ditemukan di folder kubernetes/. Membuat namespace secara manual...${NC}"
    kubectl create namespace taskflow-dev --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace taskflow-prod --dry-run=client -o yaml | kubectl apply -f -
fi

# 2. Deploy ke Production Environment (Namespace: taskflow-prod)
echo -e "\n${YELLOW}[Langkah 2/3] Mendeploy Resources ke Production (taskflow-prod)...${NC}"
if [ -f "kubernetes/deployment.yaml" ] && [ -f "kubernetes/service.yaml" ]; then
    kubectl apply -f kubernetes/deployment.yaml -n taskflow-prod
    kubectl apply -f kubernetes/service.yaml -n taskflow-prod
    echo -e "${GREEN}✓ Deployment dan Service sukses diterapkan di namespace taskflow-prod.${NC}"
else
    echo -e "❌ Error: File kubernetes/deployment.yaml atau service.yaml tidak ditemukan!"
    exit 1
fi

# 3. Deploy ke Development Environment (Namespace: taskflow-dev)
echo -e "\n${YELLOW}[Langkah 3/3] Mendeploy Resources ke Development (taskflow-dev)...${NC}"
kubectl apply -f kubernetes/deployment.yaml -n taskflow-dev
kubectl apply -f kubernetes/service.yaml -n taskflow-dev
echo -e "${GREEN}✓ Deployment dan Service sukses diterapkan di namespace taskflow-dev.${NC}"

# 4. Verifikasi Hasil Deployment
echo -e "\n${BLUE}======================================================${NC}"
echo -e "${GREEN}🎉 DEPLOYMENT SELESAI DENGAN SUKSES!${NC}"
echo -e "${BLUE}======================================================${NC}"

echo -e "\n${YELLOW}🔎 Resource Status di Namespace taskflow-prod:${NC}"
kubectl get all -n taskflow-prod

echo -e "\n${YELLOW}🔎 Resource Status di Namespace taskflow-dev:${NC}"
kubectl get all -n taskflow-dev

echo -e "\n${GREEN}Tips: Untuk mengakses API secara lokal di Minikube, jalankan:${NC}"
echo -e "${BLUE}  minikube service taskflow-api -n taskflow-prod --url${NC}\n"
