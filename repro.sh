#!/usr/bin/env bash
# Sends requests through the explicit and the implicit upstream and prints the
# response codes and the TIME_WAIT sockets on both sides of the connection.
set -o errexit -o nounset -o pipefail

readonly requests="${REQUESTS:-300}"

send_requests() {
  local port="$1"
  # curl expands [1-N] into N requests to /1 ... /N.
  docker compose run --rm client curl --silent --output /dev/null \
    --write-out 'code: %{http_code}\n' "http://proxy:${port}/[1-${requests}]" | uniq --count
}

count_time_wait() {
  local service="$1"
  # -t is TCP, -n is numeric.
  docker compose exec --no-tty "${service}" netstat -tn | grep --count TIME_WAIT || true
}

# Recreating the containers gives a fresh network namespace without leftover TIME_WAIT sockets.
docker compose up --force-recreate --detach --wait proxy backend
docker compose exec --no-tty proxy nginx -v

for target in explicit:8081 implicit:8080; do
  echo "== ${target%%:*} upstream, ${requests} requests"
  send_requests "${target##*:}"
  echo "TIME_WAIT sockets: proxy=$(count_time_wait proxy) backend=$(count_time_wait backend)"
done
