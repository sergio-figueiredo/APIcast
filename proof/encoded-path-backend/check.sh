#!/bin/sh
# Usage: check.sh <apicast image> <group>
#   group "nginx-escaping": characters that nginx must percent-encode again after ngx.req.set_uri()
#   group "path-decoding":  "%3F" and "%2F", which APIcast decodes before routing to the upstream
# Sends each path through APIcast to an upstream that echoes the raw request-target it received
# and compares it with what the client sent. Exits non-zero if any path changed.
IMG=$1; GROUP=$2; DIR=$(cd "$(dirname "$0")" && pwd)
case "$GROUP" in
  nginx-escaping) PATHS="cards/id%7C42 a%22b a%3Cb%3E a%5Cb a%5Eb a%60b a%7Bb%7D a%20b" ;;
  path-decoding)  PATHS="files/a%3Fb files/a%3Fb?x=1 files/a%2Fb" ;;
  *) echo "unknown group: $GROUP"; exit 2 ;;
esac
docker rm -f apicast-under-test raw-path-upstream >/dev/null 2>&1
docker network create apicast-encoding >/dev/null 2>&1
docker run -d --name raw-path-upstream --network apicast-encoding -v "$DIR":/cfg mirror.gcr.io/library/python:3-alpine python3 /cfg/upstream.py >/dev/null
docker run -d --name apicast-under-test --network apicast-encoding --platform linux/amd64 -p 18080:8080 -v "$DIR":/cfg \
  -e THREESCALE_CONFIG_FILE=/cfg/config.json -e APICAST_CONFIGURATION_LOADER=boot "$IMG" >/dev/null
for i in $(seq 1 120); do [ "$(curl -s http://localhost:18080/REST/svc/ready)" = "/REST/svc/ready" ] && break; sleep 1; done
echo "== $IMG ($(docker exec apicast-under-test openresty -v 2>&1)) - $GROUP"
printf '%-30s %-30s %s\n' "client sent" "upstream received" "result"
rc=0
for p in $PATHS; do
  got=$(curl -s "http://localhost:18080/REST/svc/$p")
  exp="/REST/svc/$p"
  if [ "$got" = "$exp" ]; then st=ok; else st=CHANGED; rc=1; fi
  printf '%-30s %-30s %s\n' "$exp" "$got" "$st"
done
docker rm -f apicast-under-test raw-path-upstream >/dev/null 2>&1
exit $rc
