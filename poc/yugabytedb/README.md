# YugabyteDB Local Test (Podman)

Compose file: `compose.yml`

## Make Targets

```bash
make init
make status
make sql
make logs
make destroy
make destroy-all
```

## Start

```bash
podman machine start
mkdir -p /tmp/podman-docker-config
DOCKER_CONFIG=/tmp/podman-docker-config podman compose up -d
```

## Check

```bash
DOCKER_CONFIG=/tmp/podman-docker-config podman compose ps
DOCKER_CONFIG=/tmp/podman-docker-config podman compose logs -f yugabytedb
```

UI:

- Master UI: http://localhost:7000
- TServer UI: http://localhost:9000

Connect:

```bash
podman exec -it yugabytedb-local ysqlsh -h 127.0.0.1 -p 5433 -U yugabyte -d yugabyte
```

## Stop

```bash
DOCKER_CONFIG=/tmp/podman-docker-config podman compose down
```

Remove data volume:

```bash
DOCKER_CONFIG=/tmp/podman-docker-config podman compose down -v
```

## Notes

- Local test only; the image is intentionally left as `latest` for quick setup.
- For repeatable tests, pin the image tag before sharing with others.
- This host currently uses an external compose provider under `podman compose`, so `DOCKER_CONFIG=/tmp/podman-docker-config` avoids the missing `docker-credential-desktop` helper.
