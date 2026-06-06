#!/usr/bin/env bash
#
# check-deliverability.sh — diagnose why a mailcow domain lands in Gmail Spam.
#
# Checks the authentication records Gmail requires (PTR/FCrDNS, SPF, DKIM,
# DMARC) plus MX/A/TLS, and prints OK / WARN / FAIL for each.
#
# Usage:
#   ./check-deliverability.sh <domain> [mail-host] [dkim-selector]
#
# Examples:
#   ./check-deliverability.sh biloop.ai
#   ./check-deliverability.sh biloop.ai mail.biloop.ai dkim
#
# Needs internet. Uses `dig` if available, otherwise falls back to DNS-over-HTTPS
# via `curl` (so it works even on a box without dig). `openssl` is optional
# (for the TLS check).

set -uo pipefail

DOMAIN="${1:-}"
MAILHOST="${2:-mail.${DOMAIN}}"
SELECTOR="${3:-dkim}"

if [[ -z "$DOMAIN" ]]; then
  echo "usage: $0 <domain> [mail-host] [dkim-selector]" >&2
  exit 2
fi

# ----- pretty output -------------------------------------------------------
if [[ -t 1 ]]; then
  G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; Z=$'\e[0m'
else
  G=; R=; Y=; B=; Z=
fi
fails=0; warns=0
ok()   { printf '  %sOK%s   %s\n'   "$G" "$Z" "$*"; }
warn() { printf '  %sWARN%s %s\n'   "$Y" "$Z" "$*"; ((warns++)); }
fail() { printf '  %sFAIL%s %s\n'   "$R" "$Z" "$*"; ((fails++)); }
section() { printf '\n%s== %s ==%s\n'  "$B" "$*" "$Z"; }

# ----- DNS helper: dig if present, else DNS-over-HTTPS ----------------------
HAVE_DIG=0; command -v dig >/dev/null 2>&1 && HAVE_DIG=1

# dns_query <name> <type>  -> prints one record value per line (TXT unquoted)
dns_query() {
  local name="$1" type="$2"
  if [[ $HAVE_DIG -eq 1 ]]; then
    dig +short "$type" "$name" 2>/dev/null | sed 's/^"//;s/"$//;s/" "//g'
  else
    curl -s -m 15 "https://dns.google/resolve?name=${name}&type=${type}" \
      -H 'accept: application/dns-json' 2>/dev/null \
    | python3 -c '
import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for a in (d.get("Answer") or []):
    v=a.get("data","")
    if v[:1]=="\"" and v[-1:]=="\"": v=v[1:-1]
    print(v.replace("\" \"",""))'
  fi
}

# reverse pointer name for an IPv4
ptr_name() { awk -F. '{print $4"."$3"."$2"."$1".in-addr.arpa"}' <<<"$1"; }

echo "${B}Deliverability check for ${DOMAIN} (mail host ${MAILHOST}, selector ${SELECTOR})${Z}"
[[ $HAVE_DIG -eq 1 ]] || echo "(dig not found — using DNS-over-HTTPS via curl)"

# ----- A record of the mail host -------------------------------------------
section "A record — ${MAILHOST}"
IP="$(dns_query "$MAILHOST" A | grep -E '^[0-9.]+$' | head -1)"
if [[ -n "$IP" ]]; then ok "${MAILHOST} -> ${IP}"; else fail "${MAILHOST} has no A record"; fi

# ----- MX -------------------------------------------------------------------
section "MX record — ${DOMAIN}"
MX="$(dns_query "$DOMAIN" MX)"
if [[ -n "$MX" ]]; then
  echo "$MX" | while read -r l; do echo "       $l"; done
  if grep -qi "$MAILHOST" <<<"$MX"; then ok "MX includes ${MAILHOST}"
  else warn "MX does not mention ${MAILHOST}"; fi
else
  fail "no MX record for ${DOMAIN}"
fi

# ----- PTR / reverse DNS (FCrDNS) ------------------------------------------
section "Reverse DNS (PTR / FCrDNS)"
if [[ -n "$IP" ]]; then
  PTR="$(dns_query "$(ptr_name "$IP")" PTR | sed 's/\.$//' | head -1)"
  if [[ -z "$PTR" ]]; then
    fail "no PTR for ${IP} — set reverse DNS to ${MAILHOST} in your VPS panel"
  elif [[ "$PTR" == "$MAILHOST" ]]; then
    ok "PTR ${IP} -> ${PTR} (matches mail host)"
    # forward-confirm
    if [[ "$(dns_query "$PTR" A | head -1)" == "$IP" ]]; then ok "FCrDNS confirmed (A of ${PTR} -> ${IP})"
    else warn "PTR host ${PTR} does not resolve back to ${IP}"; fi
  else
    warn "PTR ${IP} -> ${PTR} (does NOT match ${MAILHOST}; Gmail prefers a match)"
  fi
else
  warn "skipped (no IP resolved for ${MAILHOST})"
fi

# ----- SPF ------------------------------------------------------------------
section "SPF — ${DOMAIN}"
SPF="$(dns_query "$DOMAIN" TXT | grep -i 'v=spf1')"
n_spf="$(grep -c . <<<"${SPF:-}")"
if [[ -z "$SPF" ]]; then
  fail "no SPF record. Add TXT @  ->  v=spf1 mx ~all"
elif [[ "$n_spf" -gt 1 ]]; then
  fail "multiple SPF records (only one allowed):"; echo "$SPF" | sed 's/^/       /'
else
  ok "SPF: $SPF"
  grep -qiE '[~-]all' <<<"$SPF" || warn "SPF has no ~all / -all qualifier"
fi

# ----- DKIM -----------------------------------------------------------------
section "DKIM — ${SELECTOR}._domainkey.${DOMAIN}"
DKIM="$(dns_query "${SELECTOR}._domainkey.${DOMAIN}" TXT | grep -i 'v=DKIM1\|p=')"
if [[ -z "$DKIM" ]]; then
  fail "no DKIM record at ${SELECTOR}._domainkey — publish the key from mailcow (Configuration -> ARC/DKIM keys)"
elif grep -qiE 'p=([A-Za-z0-9+/]{20,})' <<<"$DKIM"; then
  ok "DKIM present (selector ${SELECTOR})"
else
  warn "DKIM record found but public key looks empty/revoked: $DKIM"
fi

# ----- DMARC ----------------------------------------------------------------
section "DMARC — _dmarc.${DOMAIN}"
DMARC="$(dns_query "_dmarc.${DOMAIN}" TXT | grep -i 'v=DMARC1')"
if [[ -z "$DMARC" ]]; then
  fail "no DMARC record. Add TXT _dmarc -> v=DMARC1; p=quarantine; rua=mailto:postmaster@${DOMAIN}"
else
  ok "DMARC: $DMARC"
  grep -qiE 'p=(quarantine|reject)' <<<"$DMARC" || warn "DMARC policy is p=none (monitoring only — tighten to quarantine/reject once SPF+DKIM pass)"
fi

# ----- TLS on the mail host -------------------------------------------------
section "TLS / SMTP (port 25 STARTTLS on ${MAILHOST})"
if command -v openssl >/dev/null 2>&1 && [[ -n "$IP" ]]; then
  cert="$(echo QUIT | timeout 15 openssl s_client -connect "${MAILHOST}:25" \
            -starttls smtp -servername "$MAILHOST" 2>/dev/null \
          | openssl x509 -noout -subject -enddate 2>/dev/null)"
  if [[ -n "$cert" ]]; then
    ok "STARTTLS works:"; echo "$cert" | sed 's/^/       /'
    grep -qi "$MAILHOST\|$DOMAIN" <<<"$cert" || warn "cert subject does not mention ${MAILHOST}"
  else
    warn "could not complete STARTTLS on :25 (port 25 blocked by your network, or no cert). Test from the server's network."
  fi
else
  warn "skipped (need openssl + a resolved IP). Check the cert in the mailcow UI."
fi

# ----- summary --------------------------------------------------------------
section "Summary"
if [[ $fails -eq 0 && $warns -eq 0 ]]; then
  echo "  ${G}All checks passed.${Z} Send a test to a Gmail address and to https://mail-tester.com"
else
  echo "  ${R}${fails} FAIL${Z}, ${Y}${warns} WARN${Z} — fix the FAILs first (see mail/README.md), then re-run."
fi
exit $(( fails > 0 ? 1 : 0 ))
