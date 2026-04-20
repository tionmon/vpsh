#!/usr/bin/env python3
"""
cfddns - Cloudflare DNS Scheduled Resolver
Automatically updates DNS A records at specified times.
"""

import sys
import time
import signal
import logging
import ipaddress
from pathlib import Path
from datetime import datetime

import yaml
import requests
import schedule

# ──────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────
CF_API_BASE = "https://api.cloudflare.com/client/v4"
CONFIG_PATH = Path(__file__).parent / "config.yaml"
LOG_DIR = Path(__file__).parent / "logs"
VERSION = "1.0.0"

# ──────────────────────────────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────────────────────────────
def setup_logging(log_level: str = "INFO") -> logging.Logger:
    """Configure logging to both file and stdout."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOG_DIR / "cfddns.log"

    logger = logging.getLogger("cfddns")
    logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))

    fmt = logging.Formatter(
        "[%(asctime)s] %(levelname)-7s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # File handler (append, with rotation-friendly naming)
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    # Stdout handler
    sh = logging.StreamHandler(sys.stdout)
    sh.setFormatter(fmt)
    logger.addHandler(sh)

    return logger


# ──────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────
def load_config(path: Path) -> dict:
    """Load and validate the YAML configuration file."""
    if not path.exists():
        print(f"[FATAL] Config file not found: {path}")
        sys.exit(1)

    with open(path, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    # Validate auth
    cf = cfg.get("cloudflare", {})
    if cf.get("api_token"):
        pass  # Token auth is sufficient
    elif cf.get("email") and cf.get("api_key"):
        pass  # Key + email auth
    else:
        print("[FATAL] cloudflare.api_token OR (cloudflare.email + cloudflare.api_key) required")
        sys.exit(1)

    # Validate schedules
    schedules = cfg.get("schedules", [])
    if not schedules:
        print("[FATAL] No schedules defined in config")
        sys.exit(1)

    for sch in schedules:
        if not sch.get("domain"):
            print("[FATAL] Each schedule must have a 'domain' field")
            sys.exit(1)
        records = sch.get("records", [])
        if not records:
            print(f"[FATAL] No records defined for domain: {sch['domain']}")
            sys.exit(1)
        for rec in records:
            if not rec.get("time") or not rec.get("ip"):
                print(f"[FATAL] Each record must have 'time' and 'ip': {rec}")
                sys.exit(1)
            # Validate IPv4
            try:
                ipaddress.IPv4Address(rec["ip"])
            except ipaddress.AddressValueError:
                print(f"[FATAL] Invalid IPv4 address: {rec['ip']}")
                sys.exit(1)
            # Validate time format HH:MM
            try:
                datetime.strptime(rec["time"], "%H:%M")
            except ValueError:
                print(f"[FATAL] Invalid time format (expected HH:MM): {rec['time']}")
                sys.exit(1)

    return cfg


# ──────────────────────────────────────────────────────────────────────
# Cloudflare API Client
# ──────────────────────────────────────────────────────────────────────
class CloudflareClient:
    """Lightweight Cloudflare API v4 client for DNS operations."""

    def __init__(self, cfg: dict, logger: logging.Logger):
        self.logger = logger
        self.session = requests.Session()
        self.session.headers["Content-Type"] = "application/json"

        cf = cfg["cloudflare"]
        if cf.get("api_token"):
            self.session.headers["Authorization"] = f"Bearer {cf['api_token']}"
            self.auth_mode = "token"
        else:
            self.session.headers["X-Auth-Email"] = cf["email"]
            self.session.headers["X-Auth-Key"] = cf["api_key"]
            self.auth_mode = "key"

        # Cache: zone_name -> zone_id
        self._zone_cache: dict[str, str] = {}
        # Cache: (zone_id, record_name) -> record_id
        self._record_cache: dict[tuple[str, str], str] = {}

    def _request(self, method: str, path: str, **kwargs) -> dict:
        """Make an API request and return the JSON response."""
        url = f"{CF_API_BASE}{path}"
        resp = self.session.request(method, url, timeout=30, **kwargs)

        try:
            data = resp.json()
        except ValueError:
            self.logger.error("Non-JSON response from CF API: %s", resp.text[:500])
            raise RuntimeError(f"CF API returned non-JSON: {resp.status_code}")

        if not data.get("success"):
            errors = data.get("errors", [])
            err_msg = "; ".join(e.get("message", str(e)) for e in errors)
            self.logger.error("CF API error: %s", err_msg)
            raise RuntimeError(f"CF API error: {err_msg}")

        return data

    def _extract_zone_name(self, domain: str) -> str:
        """Extract the root zone (e.g., test.com) from a fully qualified domain."""
        parts = domain.rstrip(".").split(".")
        if len(parts) < 2:
            raise ValueError(f"Invalid domain: {domain}")
        return ".".join(parts[-2:])

    def get_zone_id(self, domain: str) -> str:
        """Get the zone ID for a domain, with caching."""
        zone_name = self._extract_zone_name(domain)
        if zone_name in self._zone_cache:
            return self._zone_cache[zone_name]

        data = self._request("GET", f"/zones?name={zone_name}&status=active")
        results = data.get("result", [])
        if not results:
            raise RuntimeError(f"Zone not found for: {zone_name}")

        zone_id = results[0]["id"]
        self._zone_cache[zone_name] = zone_id
        self.logger.info("Resolved zone: %s -> %s", zone_name, zone_id)
        return zone_id

    def get_record(self, zone_id: str, name: str) -> dict | None:
        """Get an existing A record, or None if not found."""
        data = self._request("GET", f"/zones/{zone_id}/dns_records?type=A&name={name}")
        results = data.get("result", [])
        if results:
            rec = results[0]
            self._record_cache[(zone_id, name)] = rec["id"]
            return rec
        return None

    def update_record(self, zone_id: str, record_id: str, name: str, ip: str, proxied: bool = False, ttl: int = 1) -> dict:
        """Update an existing DNS A record."""
        payload = {
            "type": "A",
            "name": name,
            "content": ip,
            "ttl": ttl,
            "proxied": proxied,
        }
        data = self._request("PUT", f"/zones/{zone_id}/dns_records/{record_id}", json=payload)
        return data["result"]

    def create_record(self, zone_id: str, name: str, ip: str, proxied: bool = False, ttl: int = 1) -> dict:
        """Create a new DNS A record."""
        payload = {
            "type": "A",
            "name": name,
            "content": ip,
            "ttl": ttl,
            "proxied": proxied,
        }
        data = self._request("POST", f"/zones/{zone_id}/dns_records", json=payload)
        rec = data["result"]
        self._record_cache[(zone_id, name)] = rec["id"]
        return rec

    def ensure_record(self, domain: str, ip: str, proxied: bool = False, ttl: int = 1) -> None:
        """Create or update a DNS A record to point to the given IP."""
        zone_id = self.get_zone_id(domain)
        existing = self.get_record(zone_id, domain)

        if existing:
            if existing["content"] == ip:
                self.logger.info("⏭  %s already points to %s — skipped", domain, ip)
                return
            self.update_record(zone_id, existing["id"], domain, ip, proxied, ttl)
            self.logger.info("✅ Updated  %s -> %s  (was %s)", domain, ip, existing["content"])
        else:
            self.create_record(zone_id, domain, ip, proxied, ttl)
            self.logger.info("✅ Created  %s -> %s", domain, ip)


# ──────────────────────────────────────────────────────────────────────
# Scheduler
# ──────────────────────────────────────────────────────────────────────
class DNSScheduler:
    """Registers and runs DNS update jobs at configured times."""

    def __init__(self, cfg: dict, logger: logging.Logger):
        self.cfg = cfg
        self.logger = logger
        self.client = CloudflareClient(cfg, logger)

    def _make_job(self, domain: str, ip: str, proxied: bool, ttl: int):
        """Create a closure for the scheduled job."""
        def job():
            now = datetime.now().strftime("%H:%M:%S")
            self.logger.info("⏰ Triggered: %s -> %s  (time: %s)", domain, ip, now)
            try:
                self.client.ensure_record(domain, ip, proxied, ttl)
            except Exception as e:
                self.logger.error("❌ Failed to update %s -> %s : %s", domain, ip, e)
        return job

    def register_all(self) -> int:
        """Register all scheduled jobs. Returns the total count."""
        count = 0
        for sch in self.cfg["schedules"]:
            domain = sch["domain"]
            proxied = sch.get("proxied", False)
            ttl = sch.get("ttl", 1)  # 1 = Auto

            for rec in sch["records"]:
                t = rec["time"]   # "HH:MM"
                ip = rec["ip"]
                job_fn = self._make_job(domain, ip, proxied, ttl)
                schedule.every().day.at(t).do(job_fn)
                self.logger.info("📋 Registered: %s -> %s  at %s daily", domain, ip, t)
                count += 1

        return count

    def run_forever(self):
        """Main loop — runs pending jobs every 30 seconds."""
        self.logger.info("🚀 Scheduler running. Checking every 30s…")
        while True:
            schedule.run_pending()
            time.sleep(30)


# ──────────────────────────────────────────────────────────────────────
# Graceful shutdown
# ──────────────────────────────────────────────────────────────────────
_running = True

def _shutdown(signum, frame):
    global _running
    _running = False

# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────
def cmd_run(cfg: dict, logger: logging.Logger):
    """Start the scheduler daemon."""
    scheduler = DNSScheduler(cfg, logger)
    count = scheduler.register_all()
    logger.info("Total jobs: %d", count)

    # Verify CF connectivity
    logger.info("Verifying Cloudflare connectivity…")
    for sch in cfg["schedules"]:
        try:
            zone_id = scheduler.client.get_zone_id(sch["domain"])
            logger.info("✅ Zone OK: %s (%s)", sch["domain"], zone_id)
        except Exception as e:
            logger.error("❌ Zone error for %s: %s", sch["domain"], e)
            sys.exit(1)

    scheduler.run_forever()


def cmd_test(cfg: dict, logger: logging.Logger):
    """Test connectivity and show current DNS state."""
    client = CloudflareClient(cfg, logger)
    for sch in cfg["schedules"]:
        domain = sch["domain"]
        try:
            zone_id = client.get_zone_id(domain)
            logger.info("Zone: %s -> %s", domain, zone_id)
            rec = client.get_record(zone_id, domain)
            if rec:
                logger.info("Current record: %s -> %s (proxied=%s, ttl=%s)",
                            domain, rec["content"], rec["proxied"], rec["ttl"])
            else:
                logger.info("No existing A record for %s", domain)
        except Exception as e:
            logger.error("Error for %s: %s", domain, e)


def cmd_now(cfg: dict, logger: logging.Logger, domain_filter: str | None = None):
    """Immediately apply the next upcoming schedule (or force a specific one)."""
    client = CloudflareClient(cfg, logger)
    now = datetime.now().strftime("%H:%M")

    for sch in cfg["schedules"]:
        domain = sch["domain"]
        if domain_filter and domain != domain_filter:
            continue

        proxied = sch.get("proxied", False)
        ttl = sch.get("ttl", 1)

        # Find the current or most recent applicable schedule entry
        records = sorted(sch["records"], key=lambda r: r["time"])
        target = records[0]  # default to first entry
        for rec in records:
            if rec["time"] <= now:
                target = rec

        logger.info("Applying now: %s -> %s (scheduled for %s)", domain, target["ip"], target["time"])
        try:
            client.ensure_record(domain, target["ip"], proxied, ttl)
        except Exception as e:
            logger.error("❌ Failed: %s", e)


def cmd_set(cfg: dict, logger: logging.Logger, domain: str, ip: str):
    """Manually set a domain to a specific IP right now."""
    client = CloudflareClient(cfg, logger)
    # Find the schedule entry for this domain to get proxied/ttl defaults
    proxied = False
    ttl = 1
    for sch in cfg["schedules"]:
        if sch["domain"] == domain:
            proxied = sch.get("proxied", False)
            ttl = sch.get("ttl", 1)
            break

    try:
        ipaddress.IPv4Address(ip)
    except ipaddress.AddressValueError:
        logger.error("Invalid IPv4: %s", ip)
        sys.exit(1)

    logger.info("Manual set: %s -> %s", domain, ip)
    try:
        client.ensure_record(domain, ip, proxied, ttl)
    except Exception as e:
        logger.error("❌ Failed: %s", e)


def print_usage():
    print(f"""cfddns v{VERSION} — Cloudflare DNS Scheduled Resolver

Usage:
  cfddns run              Start the scheduler (runs as daemon)
  cfddns test             Test CF connectivity and show current DNS state
  cfddns now [domain]     Immediately apply the current time-appropriate record
  cfddns set <domain> <ip> Manually set a domain to a specific IP
  cfddns status           Show all configured schedules
  cfddns help             Show this help message

Config: {CONFIG_PATH}
""")


def cmd_status(cfg: dict, logger: logging.Logger):
    """Print all configured schedules in a readable table."""
    print(f"\n{'Domain':<30} {'Time':<8} {'IP':<18} {'Proxied':<9} {'TTL'}")
    print("─" * 80)
    for sch in cfg["schedules"]:
        domain = sch["domain"]
        proxied = sch.get("proxied", False)
        ttl = sch.get("ttl", "auto")
        for rec in sorted(sch["records"], key=lambda r: r["time"]):
            print(f"{domain:<30} {rec['time']:<8} {rec['ip']:<18} {str(proxied):<9} {ttl}")


# ──────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────
def main():
    signal.signal(signal.SIGINT, _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)

    if len(sys.argv) < 2 or sys.argv[1] in ("help", "-h", "--help"):
        print_usage()
        sys.exit(0)

    cmd = sys.argv[1]

    cfg = load_config(CONFIG_PATH)
    log_level = cfg.get("log_level", "INFO")
    logger = setup_logging(log_level)

    logger.info("cfddns v%s — auth mode: %s",
                VERSION,
                "token" if cfg["cloudflare"].get("api_token") else "key+email")

    if cmd == "run":
        cmd_run(cfg, logger)
    elif cmd == "test":
        cmd_test(cfg, logger)
    elif cmd == "now":
        domain_filter = sys.argv[2] if len(sys.argv) > 2 else None
        cmd_now(cfg, logger, domain_filter)
    elif cmd == "set":
        if len(sys.argv) < 4:
            print("Usage: cfddns set <domain> <ip>")
            sys.exit(1)
        cmd_set(cfg, logger, sys.argv[2], sys.argv[3])
    elif cmd == "status":
        cmd_status(cfg, logger)
    else:
        print(f"Unknown command: {cmd}")
        print_usage()
        sys.exit(1)


if __name__ == "__main__":
    main()
