job "hashi-ui" {
  datacenters = ["dc1"]
  priority    = 75
  type        = "service"

  update {
    auto_revert      = false
    canary           = 0
    health_check     = "checks"
    healthy_deadline = "9m"
    max_parallel     = 2
    min_healthy_time = "10s"
    stagger          = "10s"
  }

  group "hashi-ui" {
    count = 1

    task "hashi-ui" {
      driver = "docker"
      leader = true

      config {
        image        = "jippi/hashi-ui"
        network_mode = "host"
        port_map {
          http = 3000
        }
      }

      service {
        name = "hashi-ui"
        port = "http"

        check {
          name     = "http"
          port     = "http"
          type     = "http"
          path     = "/_status"
          interval = "10s"
          timeout  = "2s"
        }
      }

      env {
        BUMP              = 1
        NOMAD_ENABLE      = 1
        NOMAD_ADDR        = "http://http.nomad.service.consul:4646"
        NOMAD_ALLOW_STALE = true
        CONSUL_ENABLE     = 1
        CONSUL_ADDR       = "consul.service.consul:8500"
      }

      resources {
        cpu    = 500
        memory = 100

        network {
          mbits = 1

          port "http" {
            static = 3000
          }
        }
      }
    }
  }
}
