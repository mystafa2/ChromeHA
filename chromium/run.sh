#!/usr/bin/with-contenv bashio
set -euo pipefail

START_URL="$(bashio::config 'start_url')"
WIDTH="$(bashio::config 'window_width')"
HEIGHT="$(bashio::config 'window_height')"
KIOSK="$(bashio::config 'kiosk')"
INCOGNITO="$(bashio::config 'incognito')"
DISABLE_GPU="$(bashio::config 'disable_gpu')"
COLOR_DEPTH="$(bashio::config 'color_depth')"
VNC_PASSWORD="$(bashio::config 'vnc_password')"

mkdir -p "${CHROME_USER_DATA_DIR}" /tmp/chrome

if command -v chromium-browser >/dev/null 2>&1; then
  CHROMIUM_CMD="chromium-browser"
elif command -v chromium >/dev/null 2>&1; then
  CHROMIUM_CMD="chromium"
else
  bashio::log.error "Chromium binary not found in PATH"
  exit 1
fi

cat > /tmp/xstartup <<'XSTART'
#!/usr/bin/env sh
openbox-session &
XSTART
chmod +x /tmp/xstartup

if command -v tigervncserver >/dev/null 2>&1; then
  VNCSERVER_CMD="tigervncserver"
elif command -v vncserver >/dev/null 2>&1; then
  VNCSERVER_CMD="vncserver"
else
  bashio::log.error "TigerVNC server binary not found"
  exit 1
fi

# Configure VNC password file (or disable auth when empty string is provided).
VNC_AUTH_ARGS=(-SecurityTypes VncAuth)
if [ -n "${VNC_PASSWORD}" ]; then
  if command -v vncpasswd >/dev/null 2>&1; then
    printf '%s' "${VNC_PASSWORD}" | vncpasswd -f > /tmp/vnc.pass 2>/dev/null || true
    chmod 600 /tmp/vnc.pass 2>/dev/null || true
  fi
  if [ -s /tmp/vnc.pass ]; then
    VNC_AUTH_ARGS=(-PasswordFile /tmp/vnc.pass)
  else
    bashio::log.warning "Could not create VNC password file; fallback to no auth"
    VNC_AUTH_ARGS=(-SecurityTypes None --I-KNOW-THIS-IS-INSECURE)
  fi
else
  VNC_AUTH_ARGS=(-SecurityTypes None --I-KNOW-THIS-IS-INSECURE)
fi

bashio::log.info "Starting TigerVNC ${WIDTH}x${HEIGHT} depth=${COLOR_DEPTH}"
"${VNCSERVER_CMD}" \
  -geometry "${WIDTH}x${HEIGHT}" \
  -depth "${COLOR_DEPTH}" \
  -localhost no \
  -xstartup /tmp/xstartup \
  "${VNC_AUTH_ARGS[@]}" \
  "${DISPLAY}" >/tmp/tigervnc.log 2>&1 &
VNC_PID=$!

# Wait VNC to be ready.
for _ in $(seq 1 30); do
  if nc -z 127.0.0.1 5900 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! nc -z 127.0.0.1 5900 >/dev/null 2>&1; then
  bashio::log.error "TigerVNC failed to start"
  tail -n 100 /tmp/tigervnc.log 2>/dev/null || true
  exit 1
fi

bashio::log.info "Starting websockify/noVNC"
websockify --web /usr/share/novnc 6080 127.0.0.1:5900 >/tmp/novnc.log 2>&1 &
NOVNC_PID=$!

CHROME_FLAGS=(
  --no-first-run
  --no-default-browser-check
  --disable-dev-shm-usage
  --disable-translate
  --disable-features=TranslateUI
  --window-size="${WIDTH},${HEIGHT}"
  --user-data-dir="${CHROME_USER_DATA_DIR}"
)

if bashio::var.true "${KIOSK}"; then
  CHROME_FLAGS+=(--kiosk)
fi
if bashio::var.true "${INCOGNITO}"; then
  CHROME_FLAGS+=(--incognito)
fi
if bashio::var.true "${DISABLE_GPU}"; then
  CHROME_FLAGS+=(--disable-gpu --disable-software-rasterizer)
fi
if [ -e /dev/dri ]; then
  CHROME_FLAGS+=(--use-gl=egl)
fi

cleanup() {
  bashio::log.info "Stopping services"
  kill "${CHROME_PID:-}" "${NOVNC_PID:-}" "${VNC_PID:-}" 2>/dev/null || true
  "${VNCSERVER_CMD}" -kill "${DISPLAY}" >/dev/null 2>&1 || true
}
trap cleanup SIGTERM SIGINT

while true; do
  bashio::log.info "Starting Chromium at ${START_URL}"
  DISPLAY="${DISPLAY}" "${CHROMIUM_CMD}" "${CHROME_FLAGS[@]}" "${START_URL}" >/tmp/chromium.log 2>&1 &
  CHROME_PID=$!

  wait "${CHROME_PID}" || true
  bashio::log.warning "Chromium exited. Restart in 2s"
  tail -n 60 /tmp/chromium.log 2>/dev/null || true
  sleep 2

  if ! kill -0 "${NOVNC_PID}" 2>/dev/null || ! kill -0 "${VNC_PID}" 2>/dev/null; then
    bashio::log.error "Core VNC services stopped"
    tail -n 100 /tmp/tigervnc.log 2>/dev/null || true
    tail -n 100 /tmp/novnc.log 2>/dev/null || true
    exit 1
  fi
done
