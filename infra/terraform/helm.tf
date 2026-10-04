# Cluster add-ons installed with Helm. Application workloads are deployed separately with Kustomize.

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = "ingress-nginx"
  create_namespace = true
  atomic           = true
  timeout          = 600

  values = [yamlencode({
    controller = {
      replicaCount = var.environment == "prod" ? 3 : 1
      service = {
        externalTrafficPolicy = "Local"
        annotations = {
          "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
          "service.beta.kubernetes.io/azure-load-balancer-resource-group"            = azurerm_resource_group.main.name
          "service.beta.kubernetes.io/azure-pip-name"                                = azurerm_public_ip.ingress.name
        }
      }
      metrics = { enabled = true }
      podDisruptionBudget = { enabled = var.environment == "prod", minAvailable = 1 }
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
      }
      config = {
        "use-forwarded-headers" = "true"
        "hsts"                  = "true"
        "server-tokens"         = "false"
      }
    }
  })]

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.user,
    azurerm_role_assignment.aks_network,
    azurerm_role_assignment.deployer_cluster_admin,
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = "cert-manager"
  create_namespace = true
  atomic           = true
  timeout          = 600

  values = [yamlencode({
    crds = { enabled = true }
    prometheus = { enabled = true }
  })]

  depends_on = [helm_release.ingress_nginx]
}

# Local chart: Let's Encrypt staging + production ClusterIssuers (needs cert-manager CRDs first).
resource "helm_release" "cluster_issuers" {
  name      = "cluster-issuers"
  chart     = "${path.module}/../helm/cluster-issuers"
  namespace = "cert-manager"
  atomic    = true

  values = [yamlencode({
    email        = var.letsencrypt_email
    ingressClass = "nginx"
  })]

  depends_on = [helm_release.cert_manager]
}
