#!/usr/bin/env bash
set -euo pipefail

# Detect compromised litellm installations (versions 1.82.7 and 1.82.8)
# Reference: https://blog.pypi.org/posts/2025-03-litellm-breach/

MALICIOUS_PROXY="a0d229be8efcb2f9135e2ad55ba275b76ddcfeb55fa4370e0a522a5bdee0120b"
MALICIOUS_PTH="71e35aef03099cd1f2d6446734273025a163597de93912df321ef118bf135238"

found=0

warn() {
  echo "WARNING: $1" >&2
  found=1
}

info() {
  echo "[*] $1"
}

# --- Backdoor persistence ---

info "Checking for sysmon backdoor..."
for dir in "$HOME/.config/sysmon" "/root/.config/sysmon"; do
  if [[ -f "$dir/sysmon.py" ]]; then
    warn "BACKDOOR FOUND: $dir/sysmon.py"
  fi
done

info "Checking for systemd persistence service..."
if [[ -f "$HOME/.config/systemd/user/sysmon.service" ]]; then
  warn "PERSISTENCE SERVICE FOUND: $HOME/.config/systemd/user/sysmon.service"
fi
if command -v systemctl &>/dev/null; then
  if systemctl --user is-enabled sysmon.service &>/dev/null; then
    warn "PERSISTENCE SERVICE ENABLED via systemctl"
  fi
fi

# --- Exfiltration artifacts ---

info "Checking for exfiltration artifacts in /tmp..."
for artifact in /tmp/tpcp.tar.gz /tmp/session.key /tmp/payload.enc /tmp/session.key.enc; do
  if [[ -f "$artifact" ]]; then
    warn "EXFIL ARTIFACT FOUND: $artifact"
  fi
done

# --- DNS / network indicators ---

info "Checking /etc/hosts for known C2 domains..."
if grep -qE "litellm\.cloud|checkmarx\.zone" /etc/hosts 2>/dev/null; then
  warn "Suspicious entries in /etc/hosts"
  grep -E "litellm\.cloud|checkmarx\.zone" /etc/hosts
fi

if [[ -f /var/log/syslog ]]; then
  info "Checking syslog for C2 domains..."
  if grep -qE "models\.litellm\.cloud|checkmarx\.zone" /var/log/syslog 2>/dev/null; then
    warn "C2 domain references found in syslog"
  fi
fi

# --- Suspicious .pth files in site-packages ---

info "Checking for suspicious .pth files in Python site-packages..."
if command -v python3 &>/dev/null; then
  site_dirs=$(python3 -c "import site; print(' '.join(site.getsitepackages()))" 2>/dev/null || true)
  if [[ -n "$site_dirs" ]]; then
    while IFS= read -r pth_file; do
      [[ -z "$pth_file" ]] && continue
      warn "Suspicious .pth file: $pth_file"
    done < <(find $site_dirs -name "*.pth" -exec grep -l "base64\|subprocess\|exec" {} \; 2>/dev/null)
  fi
fi

# --- Malicious file hash checks ---

info "Scanning for litellm/proxy/proxy_server.py (malicious SHA in 1.82.7)..."
while IFS=' ' read -r hash file; do
  [[ -z "$hash" ]] && continue
  if [[ "$hash" == "$MALICIOUS_PROXY" ]]; then
    warn "MALICIOUS proxy_server.py (1.82.7): $file"
  else
    echo "  OK: $file"
  fi
done < <(find / -path "*/litellm/proxy/proxy_server.py" 2>/dev/null -exec shasum -a 256 {} \;)

info "Scanning for litellm_init.pth (malicious SHA in 1.82.8)..."
while IFS=' ' read -r hash file; do
  [[ -z "$hash" ]] && continue
  if [[ "$hash" == "$MALICIOUS_PTH" ]]; then
    warn "MALICIOUS litellm_init.pth (1.82.8): $file"
  else
    echo "  OK: $file"
  fi
done < <(find / -name "litellm_init.pth" 2>/dev/null -exec shasum -a 256 {} \;)

# --- Summary ---

echo ""
if [[ "$found" -ne 0 ]]; then
  echo "RESULT: Potential compromise detected. Review warnings above."
  exit 1
else
  echo "RESULT: No indicators of compromise found."
  exit 0
fi
