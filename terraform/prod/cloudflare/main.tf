locals {
  tags = [
    "managed-by:terraform",
    "environment:prod",
    "system:srvcs",
    "service:www",
  ]
}

resource "cloudflare_dns_record" "www_ingress" {
  for_each = var.hostnames

  zone_id = var.cloudflare_zone_id
  name    = each.value
  type    = "A"
  content = var.origin_ipv4
  proxied = var.proxied
  ttl     = 1
  comment = "srvcs production ingress for www"
  tags    = local.tags
}
