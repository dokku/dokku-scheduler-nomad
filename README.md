# dokku-scheduler-nomad

A Dokku plugin to integrate with nomad.

## Testing

You can start a local testing server. This will:

- install consul
- install docker
- install levant (for deploy)
- install nomad
- install dokku in unattended mode with nginx disabled
- install the dokku-clone plugin
- install the dokku-registry plugin (both commercial)
- start hashi-ui and traefik in the nomad cluster
- set nomad as the scheduler

To start the server, you'll need to set some arguments to log into quay.io

```shell
# start the server
vagrant --quay-username="SOME_USERNAME" --quay-password="SOME_PASSWORD" up
```

## TODO

- trigger scheduler-logs-failed: figure out a way to show the last failed deploy (if there was one)
- trigger scheduler-run: figure out a way to express parameterized jobs
- trigger scheduler-stop: tell nomad to stop all jobs for this app
- trigger install: install levant binary
- levant: add support for configuring all it's environment variables
- jobs: add support for environment variables... somehow
