{
  "subject": {{ toJson .Subject }},
  "keyUsage": ["certSign", "crlSign"],
  "basicConstraints": {
    "isCA": true,
    "maxPathLen": 0
  },
  "nameConstraints": {
    "critical": true,
    "permittedDNSDomains": [{{ toJson .Insecure.User.domain }}],
    "permittedIPRanges": [{{ toJson .Insecure.User.cidr }}, "127.0.0.1/32"]
  }
}
