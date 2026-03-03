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

bashio::log.info "Starting virtual display ${WIDTH}x${HEIGHT}"
Xvfb :0 -screen 0 "${WIDTH}x${HEIGHT}x24" -ac +extension GLX +render -noreset &
XVFB_PID=$!

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

CHROME_FLAGS=(
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

bashio::log.info "Starting Chromium at ${START_URL}"
chromium-browser "${CHROME_FLAGS[@]}" "${START_URL}" >/tmp/chromium.log 2>&1 &
CHROME_PID=$!

cleanup() {
  bashio::log.info "Stopping services"
  kill "${CHROME_PID}" "${NOVNC_PID}" "${VNC_PID}" "${FLUXBOX_PID}" "${XVFB_PID}" 2>/dev/null || true
}

trap cleanup SIGTERM SIGINT

wait -n "${CHROME_PID}" "${NOVNC_PID}" "${VNC_PID}" "${FLUXBOX_PID}" "${XVFB_PID}"
cleanup
wait || true
