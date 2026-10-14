{ pkgs, lib, ... }:

{
  packages = with pkgs; [
    kubectl
    minikube
    kubernetes-helm
    k9s
    kustomize
    yq-go
    jq
    git
  ];

  enterShell = ''
    # Standard CKAD exam aliases & shortcuts
    alias k=kubectl
    complete -o default -F __start_kubectl k 2>/dev/null || true
    source <(kubectl completion bash 2>/dev/null) 2>/dev/null || true

    export do="--dry-run=client -o yaml"
    export now="--force --grace-period=0"

    echo "☸️  CKAD & Kubernetes Environment Loaded!"
    echo "   • kubectl $(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1 | awk '{print $2}')"
    echo "   • minikube $(minikube version --short 2>/dev/null)"
    echo "   • Quick aliases: 'k' -> kubectl, \$do -> '--dry-run=client -o yaml'"
    echo "   • Start cluster: minikube start --driver=podman (or --driver=docker)"
  '';
}
