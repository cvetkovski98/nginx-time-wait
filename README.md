# NGINX 1.29.7 implicit upstream repro

Since 1.29.7, `proxy_pass` without an `upstream {}` block makes NGINX close every upstream connection itself. Each request leaves a `TIME_WAIT` socket on the proxy, and the proxy runs out of local ports.

## Usage

```sh
$ ./repro.sh
$ NGINX_VERSION=1.29.6 ./repro.sh
$ REQUESTS=1000 ./repro.sh
$ docker compose down
```

`repro.sh` recreates the containers on every run, so results do not carry over between runs.

## Setup

- `proxy`: the NGINX under test, with `proxy.conf` mounted
  - port 8080: `proxy_pass http://backend:80;` (implicit upstream)
  - port 8081: `proxy_pass http://backend_pool;` (explicit `upstream {}` block)
- `backend`: stock NGINX serving `ok` over HTTP/1.1 with keepalive
- `client`: curl, used by `repro.sh`

The proxy's local port range is reduced to 100 ports, so the exhaustion shows up within a few hundred requests by setting:

```yml
sysctls:
  net.ipv4.ip_local_port_range: "40000 40099"
```

## Expected results of this repro

`TIME_WAIT` counts accumulate over both blocks of one run.

- 1.29.7, explicit: all `200`, almost no TIME_WAIT sockets, because connections are pooled
- 1.29.7, implicit: about 100 `200`, the rest `502`, about 100 TIME_WAIT sockets on the proxy. `docker compose logs proxy` shows `connect() ... failed (99: Cannot assign requested address)`
- 1.29.6, both: all `200`, TIME_WAIT sockets on the backend, because the backend closes the connection after `Connection: close`
