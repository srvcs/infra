resource "cloudflare_dns_record" "www_ingress" {
  for_each = var.hostnames

  zone_id = var.cloudflare_zone_id
  name    = each.value
  type    = "A"
  content = var.origin_ipv4
  proxied = var.proxied
  ttl     = 1
  comment = "srvcs production ingress for www"
}

resource "cloudflare_dns_record" "preview_ingress" {
  for_each = var.preview_hostnames

  zone_id = var.cloudflare_zone_id
  name    = each.value
  type    = "A"
  content = var.origin_ipv4
  proxied = var.proxied
  ttl     = 1
  comment = "srvcs preview ingress wildcard"
}
