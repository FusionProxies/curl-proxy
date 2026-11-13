<p align="center">
  <a href="https://fusionproxy.net/?utm_source=github&utm_medium=referral&utm_campaign=curl-proxy">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/FusionProxies/.github/main/assets/logo-on-dark.png">
      <img src="https://raw.githubusercontent.com/FusionProxies/.github/main/assets/logo-on-light.png" alt="Fusion Proxy" height="52">
    </picture>
  </a>
</p>

# How to use a proxy with cURL

Everything you need to send cURL requests through a proxy: `-x` and `-U`, proxy authentication, HTTPS and SOCKS5 proxies, environment variables, a `.curlrc` default, rotating and sticky residential IPs, timing a proxy and fixing the usual errors. [`examples.sh`](examples.sh) runs every example.

## Contents

1. [Basic proxy: -x](#1-basic-proxy--x)
2. [Proxy authentication: -U](#2-proxy-authentication--u)
3. [SOCKS5 proxy](#3-socks5-proxy)
4. [HTTPS proxy (TLS to the proxy)](#4-https-proxy-tls-to-the-proxy)
5. [Environment variables](#5-environment-variables)
6. [Make a proxy the default with .curlrc](#6-make-a-proxy-the-default-with-curlrc)
7. [Rotating and sticky IPs](#7-rotating-and-sticky-ips)
8. [Measure how fast a proxy is](#8-measure-how-fast-a-proxy-is)
9. [Errors and fixes](#9-errors-and-fixes)

## 1. Basic proxy: -x

```bash
curl -x http://203.0.113.10:8080 https://ipinfo.io/json
```

`-x` (or `--proxy`) takes `[scheme://]host:port`. Without a scheme cURL assumes `http://`. For an `https://` website cURL asks the proxy to open a `CONNECT` tunnel and does TLS with the website inside it, so the proxy does not see the content.

## 2. Proxy authentication: -U

```bash
curl -x http://resi.fusionproxy.net:12286 -U "USERNAME:PASSWORD" https://ipinfo.io/json
```

`-U` (or `--proxy-user`) sends the credentials to the proxy, not to the website. You can also put them in the proxy URL:

```bash
curl -x "http://USERNAME:PASSWORD@resi.fusionproxy.net:12286" https://ipinfo.io/json
```

In the URL form, special characters in the password must be percent-encoded (`@` becomes `%40`, `:` becomes `%3A`). With `-U` they don't, which is why `-U` is the safer habit. Quote the argument so the shell leaves characters like `!` and `$` alone.

## 3. SOCKS5 proxy

```bash
curl -x "socks5h://USERNAME:PASSWORD@resi.fusionproxy.net:5390" https://ipinfo.io/json
```

| Scheme | Who resolves the host name |
|---|---|
| `socks5h://` (or `--socks5-hostname`) | The proxy. Use this one: DNS happens in the proxy's country and does not leak from your machine |
| `socks5://` (or `--socks5`) | Your machine, which then sends the IP to the proxy |
| `socks4://` | Your machine; SOCKS4 has no authentication with a password |

## 4. HTTPS proxy (TLS to the proxy)

An `https://` **proxy** URL means cURL also encrypts the connection to the proxy itself. It needs a proxy that speaks TLS on that port; most proxies, including residential gateways, use plain `http://` and still carry HTTPS websites safely through the tunnel.

```bash
curl -x https://proxy.example.com:443 -U "USERNAME:PASSWORD" https://ipinfo.io/json
```

## 5. Environment variables

```bash
export http_proxy="http://USERNAME:PASSWORD@resi.fusionproxy.net:12286"
export https_proxy="$http_proxy"
export no_proxy="localhost,127.0.0.1,.internal.example"
curl https://ipinfo.io/json
```

- cURL reads `http_proxy` only in **lowercase**. Uppercase `HTTP_PROXY` is ignored on purpose, because CGI web servers can set it from a request header.
- `https_proxy` / `HTTPS_PROXY` and `all_proxy` / `ALL_PROXY` work in both cases.
- `--noproxy "*"` ignores the variables for one command; `-x ""` does the same.

## 6. Make a proxy the default with .curlrc

cURL reads `~/.curlrc` (`%APPDATA%\_curlrc` on Windows) on every run:

```
proxy = "http://resi.fusionproxy.net:12286"
proxy-user = "USERNAME:PASSWORD"
```

Skip it for one command with `curl -q ...` (`-q` must be the first argument).

## 7. Rotating and sticky IPs

A rotating residential gateway gives every connection a new IP, and options in the username choose the location or keep one IP:

```bash
# new US IP on every request
curl -x http://resi.fusionproxy.net:12286 -U "USERNAME-country-us:PASSWORD" https://ipinfo.io/ip

# the same German IP for 10 minutes
curl -x http://resi.fusionproxy.net:12286 -U "USERNAME-country-de-sessid-4821937-sessTime-600s:PASSWORD" https://ipinfo.io/ip
```

The username format is explained in the [endpoint generator guide](https://fusionproxy.net/guides/endpoint-generator?utm_source=github&utm_medium=referral&utm_campaign=curl-proxy).

## 8. Measure how fast a proxy is

```bash
curl -s -o /dev/null -x http://resi.fusionproxy.net:12286 -U "USERNAME:PASSWORD" \
  -w "proxy connect %{time_connect}s | tunnel + TLS %{time_appconnect}s | first byte %{time_starttransfer}s | total %{time_total}s\n" \
  https://www.example.com/
```

`time_connect` is your connection to the proxy; the jump to `time_appconnect` is the proxy reaching the website plus the TLS handshake. Run it a few times: one request says little about a rotating pool.

To check many proxies at once, use [proxy-checker](https://github.com/FusionProxies/proxy-checker) or the [online proxy checker](https://fusionproxy.net/tools/proxy-checker?utm_source=github&utm_medium=referral&utm_campaign=curl-proxy).

## 9. Errors and fixes

| cURL error | Meaning | Fix |
|---|---|---|
| `(56) CONNECT tunnel failed, response 407` | The proxy rejected the credentials | Check `-U`; percent-encode special characters if they are in the URL |
| `(7) Failed to connect to ... port ...` | The proxy does not answer on that host and port | Wrong port, proxy down, or a firewall |
| `(97) ... SOCKS` | SOCKS handshake failed | Wrong scheme (HTTP proxy used as SOCKS or the other way round) or wrong credentials |
| `(35) SSL connect error` | TLS with the website failed inside the tunnel | Retry; if it repeats with one proxy, drop that proxy |
| `(60) SSL certificate problem` | The certificate does not match | Do not reach for `-k`; a proxy that replaces certificates is reading your traffic |
| `(28) Operation timed out` | No answer in time | Add `--max-time 30` and try another IP |

Add `-v` to see the `CONNECT` exchange. The verbose log contains your `Proxy-Authorization` header (base64, readable by anyone), so remove it before you paste a log anywhere.

## Run the examples

```bash
export FUSION_USER="your_username"   # from the Fusion Proxy dashboard
export FUSION_PASS="your_password"
bash examples.sh
```

No proxy yet? [Fusion Proxy residential proxies](https://fusionproxy.net/proxies/residential?utm_source=github&utm_medium=referral&utm_campaign=curl-proxy) start at $2.95/GB, with a [free trial](https://fusionproxy.net/free-trial?utm_source=github&utm_medium=referral&utm_campaign=curl-proxy).

## Related

- [python-requests-proxy](https://github.com/FusionProxies/python-requests-proxy): proxies in Python requests
- [nodejs-proxy](https://github.com/FusionProxies/nodejs-proxy): proxies in Node.js

## License

MIT, see [LICENSE](LICENSE).
