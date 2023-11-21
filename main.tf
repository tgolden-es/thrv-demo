terraform {
  required_version = ">= 1.5.7"
  required_providers {
    elasticstack = {
      source = "elastic/elasticstack"
      version = "0.10.0"
    }
  }
}

provider "elasticstack" {
  elasticsearch {}
  kibana {}
}

locals {
  services = {
    petclinic = {
      latency_threshold = 200,
      alerts_enabled = true,
      email_alerts_to = [
        "dummy@example.com"
      ]
    },
    thrvdemo = {
      latency_threshold = 300,
      alerts_enabled = false,
      email_alerts_to = [
        "dummy@example.com"
      ]
    }
  }
}

resource "elasticstack_kibana_alerting_rule" "latency-default-rule" {
  for_each = local.services
  name = "Latency threshold | ${each.key}"
  consumer = "apm"
  notify_when = "onActionGroupChange"
  rule_type_id = "apm.transaction_duration"
  interval = "1m"
  enabled = false
  params = jsonencode({
    aggregationType = "99th"
    environment     = "ENVIRONMENT_ALL"
    serviceName     = each.key
    threshold       = each.value.latency_threshold
    transactionType = "request"
    windowSize      = 5
    windowUnit      = "m"
  })
  tags = ["apm", "service.name:${each.key}"]
  actions {
    group = "threshold_met"
    id     = "elastic-cloud-email"
    params = jsonencode({
      subject = "{{context.serviceName}} latency threshold alert"
      to = each.value.email_alerts_to
      message = <<-EOT
          {{context.reason}}

          {{rule.name}} is active with the following conditions:

          - Service name: {{context.serviceName}}
          - Transaction type: {{context.transactionType}}
          - Transaction name: {{context.transactionName}}
          - Environment: {{context.environment}}
          - Latency: {{context.triggerValue}} over the last {{context.interval}}
          - Threshold: {{context.threshold}}ms

          [View alert details]({{context.alertDetailsUrl}})
      EOT
    })
  }
}
