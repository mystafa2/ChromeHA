#!/usr/bin/with-contenv bashio
set -euo pipefail

START_URL="$(bashio::config 'start_url')"
WIDTH="$(bashio::config 'window_width')"
HEIGHT="$(bashio::config 'window_height')"
KIOSK="$(bashio::config 'kiosk')"
INCOGNITO="$(bashio::config 'incognito')"
DISABLE_GPU="$(bashio::config 'disable_gpu')"
VNC_PASSWORD="$(bashio::config 'vnc_password')"

mkdir -p "${CHROME_USER_DATA_DIR}" /tmp/chrome /tmp/.X11-unix

if command -v chromium-browser >/dev/null 2>&1; then
  CHROMIUM_CMD="chromium-browser"
elif command -v chromium >/dev/null 2>&1; then
  CHROMIUM_CMD="chromium"
else
  bashio::log.error "Chromium binary not found in PATH"
  exit 1
fi

# Cleanup stale display artifacts that can prevent Xvfb startup.
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0

XAUTH_FILE="/tmp/Xauthority"
XAUTH_COOKIE="$(mcookie)"
touch "${XAUTH_FILE}"
xauth -f "${XAUTH_FILE}" add :0 . "${XAUTH_COOKIE}" >/dev/null 2>&1 || true

bashio::log.info "Starting virtual display ${WIDTH}x${HEIGHT}"
Xvfb :0 -screen 0 "${WIDTH}x${HEIGHT}x24" -ac -nolisten tcp -auth "${XAUTH_FILE}" +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!

for _ in $(seq 1 20); do
  if [ -S /tmp/.X11-unix/X0 ]; then
    break
  fi
  sleep 1
done

if [ ! -S /tmp/.X11-unix/X0 ]; then
  bashio::log.error "Xvfb did not create display socket :0"
  tail -n 120 /tmp/xvfb.log 2>/dev/null || true
  exit 1
fi

fluxbox >/tmp/fluxbox.log 2>&1 &
WM_PID=$!

x11vnc_args=(-display :0 -auth "${XAUTH_FILE}" -rfbport 5900 -forever -shared)
if [ -n "${VNC_PASSWORD}" ]; then
  x11vnc_args+=(-passwd "${VNC_PASSWORD}")
else
  x11vnc_args+=(-nopw)
fi

x11vnc "${x11vnc_args[@]}" >/tmp/x11vnc.log 2>&1 &
VNC_PID=$!

for _ in $(seq 1 20); do
  if nc -z 127.0.0.1 5900 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! nc -z 127.0.0.1 5900 >/dev/null 2>&1; then
  bashio::log.error "x11vnc failed to start"
  tail -n 120 /tmp/x11vnc.log 2>/dev/null || true
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
  kill "${CHROME_PID:-}" "${NOVNC_PID:-}" "${VNC_PID:-}" "${WM_PID:-}" "${XVFB_PID:-}" 2>/dev/null || true
}
trap cleanup SIGTERM SIGINT

while true; do
  bashio::log.info "Starting Chromium at ${START_URL}"
  DISPLAY=:0 XAUTHORITY="${XAUTH_FILE}" "${CHROMIUM_CMD}" "${CHROME_FLAGS[@]}" "${START_URL}" >/tmp/chromium.log 2>&1 &
  CHROME_PID=$!

  wait "${CHROME_PID}" || true
  bashio::log.warning "Chromium exited. Restart in 2s"
  tail -n 80 /tmp/chromium.log 2>/dev/null || true
  sleep 2

  if ! kill -0 "${XVFB_PID}" 2>/dev/null || ! kill -0 "${VNC_PID}" 2>/dev/null || ! kill -0 "${NOVNC_PID}" 2>/dev/null; then
    bashio::log.error "Core display/VNC services stopped"
    tail -n 120 /tmp/xvfb.log 2>/dev/null || true
    tail -n 120 /tmp/x11vnc.log 2>/dev/null || true
    tail -n 120 /tmp/novnc.log 2>/dev/null || true
    exit 1
  fi
done
