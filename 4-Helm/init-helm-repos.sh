#!/bin/bash
set -e

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo add external-secrets https://charts.external-secrets.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add juicefs https://juicedata.github.io/charts
helm repo add qdrant https://qdrant.github.io/qdrant-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kedacore https://kedacore.github.io/charts

helm repo update
helm repo list