output "managed_hostnames" {
  description = "Hostnames routed to the production ingress."
  value = sort(concat(
    [for record in cloudflare_dns_record.www_ingress : record.name],
    [for record in cloudflare_dns_record.preview_ingress : record.name],
  ))
}

output "origin_ipv4" {
  description = "Public IPv4 address used by Cloudflare DNS records."
  value       = var.origin_ipv4
}
