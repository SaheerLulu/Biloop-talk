# Fixing mailcow → Gmail "Spam" for `biloop.ai`

> **TL;DR** — Gmail sends mail from a fresh mailcow server to Spam when the
> message can't be **authenticated**. For Gmail you need **all** of:
> a valid **PTR / reverse DNS**, **SPF**, **DKIM**, and **DMARC**, plus a
> matching **HELO hostname** and **TLS**. Set the four DNS records below,
> make sure your VPS provider has set reverse DNS, send a test, and you're done.
>
> Run [`check-deliverability.sh`](check-deliverability.sh) from any machine
> with internet to see exactly which of these is currently missing.

This server: **`mail.biloop.ai`** (mailcow), sending domain **`biloop.ai`**.

Since February 2024 Gmail **requires** SPF + DKIM + DMARC for senders. A
mailcow install does *not* set these for you — mailcow generates the DKIM key
but **you must publish the DNS records yourself** at your DNS provider
(Cloudflare / your registrar). Missing any one of them is enough for Gmail to
spam-foldering (or reject) your mail.

---

## 1. The four DNS records you must publish

Replace `203.0.113.10` with your server's **real public IPv4** (the A record of
`mail.biloop.ai`). If your server also has IPv6 (AAAA), include it in SPF too.

| # | Type | Host / Name | Value |
|---|------|-------------|-------|
| 1 | A | `mail` | `203.0.113.10` (your server IP) |
| 2 | MX | `@` (biloop.ai) | `10 mail.biloop.ai.` |
| 3 | TXT (**SPF**) | `@` (biloop.ai) | `v=spf1 mx ~all` |
| 4 | TXT (**DKIM**) | `dkim._domainkey` | *(public key from mailcow — see §3)* |
| 5 | TXT (**DMARC**) | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:postmaster@biloop.ai; ruf=mailto:postmaster@biloop.ai; fo=1; adkim=s; aspf=s` |

Notes:
- **SPF** — `v=spf1 mx ~all` authorises whatever your MX (`mail.biloop.ai`)
  resolves to. If you send from an IP that isn't your MX, use
  `v=spf1 mx ip4:203.0.113.10 ~all` instead. **Only one** SPF TXT record per
  domain — don't add a second.
- **DMARC** — start with `p=none` if you want to monitor first, then move to
  `p=quarantine` and eventually `p=reject` once SPF+DKIM pass reliably. The
  `adkim=s; aspf=s` (strict alignment) is optional but recommended once things
  work; drop to relaxed (`r`) if a legit stream fails alignment.

---

## 2. Reverse DNS (PTR) — the #1 cause, and it's NOT in mailcow

Gmail demands **Forward-Confirmed reverse DNS (FCrDNS)**: the PTR record of your
sending IP must resolve to a hostname, and that hostname's A record must point
back to the same IP. For you:

```
PTR of 203.0.113.10  ->  mail.biloop.ai
A of mail.biloop.ai  ->  203.0.113.10
```

**You cannot set PTR in mailcow or in your normal DNS zone.** It is set by
**whoever owns the IP** — your VPS / hosting provider (Hetzner, OVH, DigitalOcean,
Contabo, AWS, etc.), usually in their control panel under *"Reverse DNS / rDNS /
PTR"* for the server. Set it to `mail.biloop.ai`. If your provider won't let you
set rDNS, you generally cannot run a deliverable mail server on that IP.

Also confirm mailcow's **HELO/EHLO hostname** is `mail.biloop.ai` (it is, if you
set the hostname to `mail.biloop.ai` during install). HELO, PTR, A record, and
the cert hostname should all be `mail.biloop.ai`.

---

## 3. Get the DKIM key out of mailcow

1. Log into the mailcow admin UI: `https://mail.biloop.ai`.
2. **Configuration → ARC/DKIM keys** (older builds: *Configuration & Details →
   Configuration → ARC/DKIM*).
3. If no key exists for `biloop.ai`, add one: domain `biloop.ai`, selector
   `dkim`, key length **2048** bits, click **Add**.
4. mailcow shows the **public key** as a ready-to-paste DNS record. The name is
   `dkim._domainkey` and the value looks like
   `v=DKIM1;k=rsa;t=s;p=MIIBIjANBgkq...` (one long string).
5. Publish it as record **#4** above. If your DNS provider rejects the long
   value, split it into 255-char quoted chunks (Cloudflare/most providers handle
   it automatically).

> The DKIM **selector** must match between mailcow (`dkim`) and the DNS host
> (`dkim._domainkey`). If you chose a different selector, adjust the host name.

---

## 4. TLS, ports, and IP reputation

- **TLS** — mailcow auto-provisions a Let's Encrypt cert for `mail.biloop.ai`.
  In the UI check **System → Configuration → Let's Encrypt** shows a valid cert
  (not the self-signed snakeoil one). Gmail prefers (and bulk-requires) TLS.
- **Port 25 outbound** — must be open. Many clouds (AWS, GCP, Oracle, Azure,
  some Hetzner accounts) **block outbound 25 by default**; you must request an
  unblock. If 25 is blocked your mail either never leaves or routes oddly.
- **Blocklists** — fresh VPS IPs are often pre-listed on Spamhaus/SORBS/etc.
  Check at <https://multirbl.valli.org/lookup/> or
  <https://www.mail-tester.com>. If listed, request delisting from each RBL.

---

## 5. Verify

1. Run the diagnostic from a networked machine:
   ```bash
   mail/check-deliverability.sh biloop.ai mail.biloop.ai dkim
   ```
   Every check should be **OK**.
2. Send a message from a `@biloop.ai` mailbox to **a fresh Gmail address** and:
   - Click **"Show original"** in Gmail. You want
     `SPF: PASS`, `DKIM: PASS`, `DMARC: PASS`.
   - It should land in **Inbox**, not Spam.
3. Or send to the address shown at <https://www.mail-tester.com> — aim for
   **10/10**. It itemises anything still wrong.
4. Register the domain in **Google Postmaster Tools**
   (<https://postmaster.google.com>) to watch your domain/IP reputation over time.

---

## Why this lives in the `Biloop-talk` repo

This repository builds the **Biloop Talk desktop app** and isn't the mailcow
server's config repo — the actual fix is **DNS records + your VPS provider's
rDNS panel**, which live outside any code repo. These docs and the diagnostic
script are committed here as the convenient home for Biloop infra notes. Move
them to a dedicated `biloop-infra` / mailcow repo if you start one.
