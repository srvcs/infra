variable "cloudflare_zone_id" {
  description = "Cloudflare zone identifier for srvcs.cloud."
  type        = string
}

variable "origin_ipv4" {
  description = "Public IPv4 address of the production ingress host."
  type        = string

  validation {
    condition     = can(cidrhost("${var.origin_ipv4}/32", 0))
    error_message = "origin_ipv4 must be a valid IPv4 address."
  }
}

variable "hostnames" {
  description = "Fully-qualified hostnames routed to the production ingress."
  type        = set(string)
  default     = ["srvcs.cloud", "www.srvcs.cloud"]
}

variable "preview_hostnames" {
  description = "Wildcard hostnames routed to preview ingress."
  type        = set(string)
  default     = ["*.srvcs.cloud"]
}

variable "proxied" {
  description = "Whether Cloudflare should proxy these records."
  type        = bool
  default     = true
}
