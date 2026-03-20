# @name: kubetoken
# @description: Copy the Kubernetes dashboard admin token to clipboard (macOS) or print it
# @usage: kubetoken

kubetoken() {
    kubectl get secret dashboard-admin-sa -o jsonpath={".data.token"} | base64 -d | pbcopy
}
alias kt='kubetoken'
