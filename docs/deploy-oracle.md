# Deploying to Oracle Cloud Always Free (SQLite + Rails + React)

Oracle Cloud's **Always Free** tier is the one genuinely free option that can run the whole
app (Rails serving the React SPA) with a **persistent SQLite file** on the VM's disk — no
PaaS disk fee, no expiry.

> **Why not a free PaaS?** Free PaaS tiers (Render, Koyeb, …) have an *ephemeral*
> filesystem, so a SQLite file is wiped on every deploy/restart, and persistent disks
> require a paid plan. A free VM with a real disk is the only "$0, data persists" path.

## What you get (Always Free)

- **VM.Standard.A1.Flex** (ARM): up to **4 OCPU / 24 GB RAM**, or 2× `VM.Standard.E2.1.Micro`.
- **200 GB** block storage, 10 TB egress — free, indefinitely.
- A credit card is required to **create the Oracle account** (verification only; Always
  Free resources aren't charged).

## 1. Create the VM

1. Sign up at <https://www.oracle.com/cloud/free/> (card required for verification).
2. **Compute → Instances → Create instance**.
3. Image: **Ubuntu 24.04**. Shape: **VM.Standard.A1.Flex**, 2 OCPU / 12 GB (within Always Free).
   - If you get **"out of host capacity"**, try another availability domain or retry later —
     it's common for the free ARM shape.
4. Add your **SSH public key** (paste `~/.ssh/id_ed25519.pub`).
5. Note the instance's **public IP** when it's running.

## 2. Open the firewall (two layers)

**a) Oracle VCN security list** — add ingress rules:

| Source | Protocol | Port |
|---|---|---|
| 0.0.0.0/0 | TCP | 80 |
| 0.0.0.0/0 | TCP | 443 |

(Networking → Virtual Cloud Networks → your VCN → Security Lists → Default → Add Ingress Rule.)

**b) The VM's own iptables** (Oracle's Ubuntu images block these by default):

```bash
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

## 3. Install Docker

```bash
ssh ubuntu@<PUBLIC_IP>
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker          # or log out/in
docker compose version # verify the compose plugin is present
```

## 4. Get the app

```bash
git clone https://github.com/saipriyagorrela1729-gif/acme-payroll.git
cd acme-payroll
```

## 5. Configure environment

```bash
cp .env.example .env
```

Edit `.env`:

```bash
SECRET_KEY_BASE=<paste output of: openssl rand -hex 64>
DOMAIN=203-0-113-10.sslip.io          # your public IP with dots -> dashes + .sslip.io
```

> `sslip.io` is a free wildcard DNS that resolves `a-b-c-d.sslip.io` to the IP `a.b.c.d`,
> so Caddy can obtain a real Let's Encrypt certificate without you owning a domain. If you
> do have a domain, point an A record at the VM and set `DOMAIN` to it.

## 6. Build, start, seed

```bash
docker compose up -d --build          # builds frontend + Rails image, starts app + Caddy
docker compose exec app bin/rails db:seed   # ~7s, creates 10,000 employees
docker compose logs -f caddy          # watch for the certificate being issued
```

Open **https://YOUR-DOMAIN** — the dashboard loads with INR default.

## 7. Day-to-day

```bash
# deploy a new version
git pull && docker compose up -d --build

# Rails console
docker compose exec app bin/rails console

# back up the SQLite database (it lives on the `sqlite_data` volume)
docker compose exec app sh -c 'cp storage/production.sqlite3 storage/backup-$(date +%F).sqlite3'
docker cp $(docker compose ps -q app):/app/storage/backup-*.sqlite3 .
```

## 8. Keep it from being reclaimed

Oracle reclaims Always Free instances that stay **idle for 7 days** (CPU, memory *and*
network all below 20%). A live web app normally clears this, but to be safe point a free
uptime monitor (e.g. UptimeRobot) at `https://YOUR-DOMAIN/api/v1/health` every 5 minutes —
that keeps network activity up and the app warm.

## Notes

- The database is a file on the `sqlite_data` Docker volume at
  `/app/storage/production.sqlite3`; `db:prepare` runs migrations at container boot.
- Production config is entirely ENV-based: `SECRET_KEY_BASE` and `DATABASE_PATH`
  (see `config/database.yml`). No `master.key`/credentials file is used.
- `config.assume_ssl = true` + `force_ssl = true`, with Caddy terminating TLS and forwarding
  `X-Forwarded-Proto: https`.
