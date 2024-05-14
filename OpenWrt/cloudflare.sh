#!/bin/sh
AUTH=""
zone_identifier=""
rec_identifier=""
CFILE=/tmp/cloudflare

main() {
    touch $CFILE
    while [ -f $CFILE ]; do
        check_wan
        sleep 30
    done
}

check_wan() {
    uptime=$(ifstatus wan | jsonfilter -e '@["uptime"]')
    if [ $uptime -lt 100 ]; then
        renew_ip
    fi
}

renew_ip() {
    IP=$(ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address')
    payload=$(
        cat <<EOF
{
  "comment": "Router ip",
  "content": "${IP}",
  "name": "$NAME",
  "type": "A",
  "proxied": false,
  "ttl": 1
}
EOF
    )
logger -p notice -t cloudflare "$(curl --request PUT \
        --url https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$rec_identifier \
        --header 'Content-Type: application/json' \
        -H "Authorization: Bearer ${AUTH}" \
        --data "$payload")"
}

main
@antnn
