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
- install the dokku-registry plugin
- start hashi-ui and traefik in the nomad cluster
- set nomad as the scheduler

To start the server, you'll need to set some arguments to log into quay.io

```shell
# start the server
vagrant --quay-username="SOME_USERNAME" --quay-password="SOME_PASSWORD" up
```
