#!/usr/bin/with-contenv bashio
set -euo pipefail

START_URL="$(bashio::config 'start_url')"
WIDTH="$(bashio::config 'window_width')"
HEIGHT="$(bashio::config 'window_height')"
KIOSK="$(bashio::config 'kiosk')"
INCOGNITO="$(bashio::config 'incognito')"
DISABLE_GPU="$(bashio::config 'disable_gpu')"
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

bashio::log.info "Starting virtual display ${WIDTH}x${HEIGHT}"
Xvfb :0 -screen 0 "${WIDTH}x${HEIGHT}x24" -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!

# Give Xvfb time to initialize before other X clients start.
sleep 1

fluxbox >/tmp/fluxbox.log 2>&1 &
FLUXBOX_PID=$!

x11vnc -display :0 -rfbport 5900 -forever -shared -passwd "${VNC_PASSWORD}" >/tmp/x11vnc.log 2>&1 &
VNC_PID=$!

NOVNC_PATH="/usr/share/novnc"
if [ -x "${NOVNC_PATH}/utils/novnc_proxy" ]; then
  "${NOVNC_PATH}/utils/novnc_proxy" --listen 6080 --vnc localhost:5900 >/tmp/novnc.log 2>&1 &
else
  websockify --web "${NOVNC_PATH}" 6080 localhost:5900 >/tmp/novnc.log 2>&1 &
fi
NOVNC_PID=$!

for svc in XVFB_PID FLUXBOX_PID VNC_PID NOVNC_PID; do
  pid="${!svc}"
  if ! kill -0 "${pid}" 2>/dev/null; then
    bashio::log.error "${svc} failed to start (pid ${pid})."
    bashio::log.error "xvfb log:"; tail -n 50 /tmp/xvfb.log 2>/dev/null || true
    bashio::log.error "fluxbox log:"; tail -n 50 /tmp/fluxbox.log 2>/dev/null || true
    bashio::log.error "x11vnc log:"; tail -n 50 /tmp/x11vnc.log 2>/dev/null || true
    bashio::log.error "novnc log:"; tail -n 50 /tmp/novnc.log 2>/dev/null || true
    exit 1
  fi
done

CHROME_FLAGS=(
  --no-sandbox
  --disable-setuid-sandbox
  --no-first-run
  --no-default-browser-check
  --disable-dev-shm-usage
  --disable-software-rasterizer
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
  CHROME_FLAGS+=(--disable-gpu)
fi

if [ -e /dev/dri ]; then
  CHROME_FLAGS+=(--use-gl=egl)
fi

cleanup() {
  bashio::log.info "Stopping services"
  kill "${CHROME_PID:-}" "${NOVNC_PID}" "${VNC_PID}" "${FLUXBOX_PID}" "${XVFB_PID}" 2>/dev/null || true
}

trap cleanup SIGTERM SIGINT

# Keep add-on alive even if Chromium crashes once; restart browser automatically.
while true; do
  bashio::log.info "Starting Chromium at ${START_URL}"
  "${CHROMIUM_CMD}" "${CHROME_FLAGS[@]}" "${START_URL}" >/tmp/chromium.log 2>&1 &
  CHROME_PID=$!

  wait "${CHROME_PID}" || true
  bashio::log.warning "Chromium exited. Restarting in 3 seconds..."
  tail -n 50 /tmp/chromium.log 2>/dev/null || true
  sleep 3

  # Stop loop if any core service has died; container should then restart.
  if ! kill -0 "${XVFB_PID}" 2>/dev/null || ! kill -0 "${VNC_PID}" 2>/dev/null || ! kill -0 "${NOVNC_PID}" 2>/dev/null; then
    bashio::log.error "One of the core services stopped unexpectedly."
    bashio::log.error "xvfb log:"; tail -n 50 /tmp/xvfb.log 2>/dev/null || true
    bashio::log.error "x11vnc log:"; tail -n 50 /tmp/x11vnc.log 2>/dev/null || true
    bashio::log.error "novnc log:"; tail -n 50 /tmp/novnc.log 2>/dev/null || true
    exit 1
  fi
done
