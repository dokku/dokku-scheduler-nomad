.PHONY: dig
dig:
	dig +short consul.service.consul SRV
	dig @127.0.0.1 -p 53 +short consul.service.consul SRV
	sudo systemctl restart systemd-resolved.service
	dig +short consul.service.consul SRV
	dig @127.0.0.1 -p 53 +short consul.service.consul SRV

.PHONY: nomad-jobs
nomad-jobs:
	sleep 10
	levant deploy -force-count jobs/hashi-ui.hcl
	levant deploy -force-count jobs/traefik.hcl

.PHONY: restart-consul
restart-consul:
	systemctl daemon-reload && sudo systemctl restart consul.service

.PHONY: restart-nomad
restart-nomad:
	systemctl daemon-reload && sudo systemctl restart nomad.service

.PHONY: clear
clear: stop-all clear-all start-all

.PHONY: clear-all
clear-all: clear-consul clear-nomad

.PHONY: clear-consul
clear-consul:
	sudo rm -rf /var/lib/consul/*

.PHONY: clear-nomad
clear-nomad:
	sudo rm -rf /var/lib/nomad/*

.PHONY: start-all
start-all: start-consul start-nomad

.PHONY: start-consul
start-consul:
	sudo systemctl start consul.service

.PHONY: start-nomad
start-nomad:
	sudo systemctl start nomad.service

.PHONY: stop-all
stop-all: stop-consul stop-nomad

.PHONY: stop-consul
stop-consul:
	sudo systemctl stop consul.service

.PHONY: stop-nomad
stop-nomad:
	sudo systemctl stop nomad.service

.PHONY: sync
sync:
	sudo mkdir -p /var/lib/dokku/plugins/available/scheduler-nomad
	sudo rsync -a /vagrant/ /var/lib/dokku/plugins/available/scheduler-nomad --exclude .vagrant --exclude .git --exclude jobs --exclude Vagrantfile
	sudo chown -R dokku:dokku /var/lib/dokku/plugins/available/scheduler-nomad
	sudo dokku plugin:disable scheduler-nomad || true
	sudo dokku plugin:enable scheduler-nomad
	sudo dokku plugin:install
	dokku config:set --global DOKKU_SCHEDULER=nomad
