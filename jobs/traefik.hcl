job "traefik" {
  datacenters = ["dc1"]
  priority    = 75
  type        = "system"

  group "traefik" {
    count = 1

    task "traefik" {
      driver = "docker"
      leader = true

      config {
        image        = "traefik:1.7.0"
        network_mode = "host"
        args         = ["--configfile=/local/traefik.conf"]
      }

      template {
        destination     = "local/traefik.conf"
        change_mode     = "noop"
        left_delimiter  = "//"
        right_delimiter = "\\\\"

        data = <<EOH
checkNewVersion = false
defaultEntryPoints = ["http"]

[web.statistics]

[retry]
attempts = 2

[consulCatalog]
endpoint         = "127.0.0.1:8500"
exposedByDefault = true
frontEndRule     = "Host:{{ .ServiceName }}.service.consul"
stale            = true

[entryPoints]
  [entryPoints.http]
  address  = ":80"
  compress = true
  [entryPoints.admin]
  address = ":81"

[ping]
entryPoint = "admin"

[api]
entryPoint = "admin"
  [api.statistics]
        EOH
      }

      service {
        name = "traefik-http"
        port = "http"

        check {
          name     = "http"
          port     = "http"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      service {
        name = "traefik-admin"
        port = "admin"

        check {
          name     = "admin"
          port     = "admin"
          type     = "http"
          path     = "/ping"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 256
        memory = 256

        network {
          mbits = 10

          port "admin" {
            static = 81
          }

          port "http" {
            static = 80
          }
        }
      }
    }
  }
}
