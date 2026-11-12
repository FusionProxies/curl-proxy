#!/usr/bin/env bash
# Every example from the README, against a Fusion Proxy residential gateway.
#   export FUSION_USER=... FUSION_PASS=...
#   bash examples.sh
set -u
: "${FUSION_USER:?set FUSION_USER}" "${FUSION_PASS:?set FUSION_PASS}"
GW="resi.fusionproxy.net"
IP="https://ipinfo.io/ip"

step() { printf '\n== %s\n' "$1"; }

step "1-2. HTTP proxy with -x and -U (US exit)"
curl -s --max-time 30 -x "http://$GW:12286" -U "$FUSION_USER-country-us:$FUSION_PASS" "$IP"; echo

step "3. SOCKS5 with remote DNS (socks5h, German exit)"
curl -s --max-time 30 -x "socks5h://$GW:5390" -U "$FUSION_USER-country-de:$FUSION_PASS" "$IP"; echo

step "5. Environment variable (https_proxy)"
https_proxy="http://$FUSION_USER-country-gb:$FUSION_PASS@$GW:12286" curl -s --max-time 30 "$IP"; echo

step "7. Rotating: three requests, three IPs"
for i in 1 2 3; do curl -s --max-time 30 -x "http://$GW:12286" -U "$FUSION_USER-country-us:$FUSION_PASS" "$IP"; echo; done

step "7. Sticky: three requests, one IP for 10 minutes"
S="$RANDOM$RANDOM"
for i in 1 2 3; do curl -s --max-time 30 -x "http://$GW:12286" -U "$FUSION_USER-country-us-sessid-$S-sessTime-600s:$FUSION_PASS" "$IP"; echo; done

step "8. Timing"
curl -s -o /dev/null --max-time 30 -x "http://$GW:12286" -U "$FUSION_USER:$FUSION_PASS" \
  -w "proxy connect %{time_connect}s | tunnel + TLS %{time_appconnect}s | first byte %{time_starttransfer}s | total %{time_total}s\n" \
  https://www.example.com/

step "9. Wrong password shows the 407 error"
curl -sS --max-time 30 -x "http://$GW:12286" -U "$FUSION_USER:wrong-password" "$IP" 2>&1 | tail -1
