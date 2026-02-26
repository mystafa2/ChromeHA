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

NOVNC_PID=""
VNC_PID=""
XVFB_PID=""
WM_PID=""
BACKEND=""

start_novnc() {
  bashio::log.info "Starting websockify/noVNC"
  websockify --web /usr/share/novnc 6080 127.0.0.1:5900 >/tmp/novnc.log 2>&1 &
  NOVNC_PID=$!
}

start_tigervnc() {
  if ! command -v tigervncserver >/dev/null 2>&1 && ! command -v vncserver >/dev/null 2>&1; then
    return 1
  fi

  local vnc_cmd
  vnc_cmd="$(command -v tigervncserver || command -v vncserver)"

  cat > /tmp/xstartup <<'XSTART'
#!/usr/bin/env sh
openbox-session &
XSTART
  chmod +x /tmp/xstartup

  local auth_args=( -SecurityTypes VncAuth )
  if [ -n "${VNC_PASSWORD}" ] && command -v vncpasswd >/dev/null 2>&1; then
    printf '%s' "${VNC_PASSWORD}" | vncpasswd -f > /tmp/vnc.pass 2>/dev/null || true
    chmod 600 /tmp/vnc.pass 2>/dev/null || true
  fi

  if [ -s /tmp/vnc.pass ]; then
    auth_args=( -PasswordFile /tmp/vnc.pass )
  else
    bashio::log.warning "TigerVNC password file unavailable; using no-auth VNC"
    auth_args=( -SecurityTypes None --I-KNOW-THIS-IS-INSECURE )
  fi

  bashio::log.info "Starting TigerVNC ${WIDTH}x${HEIGHT} depth=${COLOR_DEPTH}"
  "${vnc_cmd}" \
    -geometry "${WIDTH}x${HEIGHT}" \
    -depth "${COLOR_DEPTH}" \
    -localhost no \
    -xstartup /tmp/xstartup \
    "${auth_args[@]}" \
    "${DISPLAY}" >/tmp/tigervnc.log 2>&1 &
  VNC_PID=$!

  for _ in $(seq 1 20); do
    if nc -z 127.0.0.1 5900 >/dev/null 2>&1; then
      BACKEND="tigervnc"
      return 0
    fi
    sleep 1
  done

  bashio::log.error "TigerVNC failed to start, falling back to Xvfb+x11vnc"
  tail -n 120 /tmp/tigervnc.log 2>/dev/null || true
  kill "${VNC_PID}" 2>/dev/null || true
  VNC_PID=""
  "${vnc_cmd}" -kill "${DISPLAY}" >/dev/null 2>&1 || true
  return 1
}

start_xvfb_fallback() {
  bashio::log.info "Starting fallback backend: Xvfb + x11vnc"
  Xvfb :0 -screen 0 "${WIDTH}x${HEIGHT}x24" -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
  XVFB_PID=$!
  sleep 1

  if command -v openbox-session >/dev/null 2>&1; then
    openbox-session >/tmp/wm.log 2>&1 &
    WM_PID=$!
  elif command -v fluxbox >/dev/null 2>&1; then
    fluxbox >/tmp/wm.log 2>&1 &
    WM_PID=$!
  fi

  x11vnc -display :0 -rfbport 5900 -forever -shared -passwd "${VNC_PASSWORD}" >/tmp/x11vnc.log 2>&1 &
  VNC_PID=$!

  for _ in $(seq 1 20); do
    if nc -z 127.0.0.1 5900 >/dev/null 2>&1; then
      BACKEND="xvfb"
      return 0
    fi
    sleep 1
  done

  bashio::log.error "Fallback backend also failed"
  tail -n 120 /tmp/xvfb.log 2>/dev/null || true
  tail -n 120 /tmp/x11vnc.log 2>/dev/null || true
  return 1
}

if ! start_tigervnc; then
  start_xvfb_fallback
fi

start_novnc

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
  if [ "${BACKEND}" = "tigervnc" ]; then
    (command -v tigervncserver >/dev/null 2>&1 && tigervncserver -kill "${DISPLAY}" >/dev/null 2>&1) || true
    (command -v vncserver >/dev/null 2>&1 && vncserver -kill "${DISPLAY}" >/dev/null 2>&1) || true
  fi
}
trap cleanup SIGTERM SIGINT

while true; do
  bashio::log.info "Starting Chromium at ${START_URL} (backend: ${BACKEND})"
  DISPLAY="${DISPLAY}" "${CHROMIUM_CMD}" "${CHROME_FLAGS[@]}" "${START_URL}" >/tmp/chromium.log 2>&1 &
  CHROME_PID=$!

  wait "${CHROME_PID}" || true
  bashio::log.warning "Chromium exited. Restart in 2s"
  tail -n 80 /tmp/chromium.log 2>/dev/null || true
  sleep 2

  if ! kill -0 "${NOVNC_PID}" 2>/dev/null || ! kill -0 "${VNC_PID}" 2>/dev/null; then
    bashio::log.error "Core VNC services stopped"
    tail -n 120 /tmp/novnc.log 2>/dev/null || true
    tail -n 120 /tmp/tigervnc.log 2>/dev/null || true
    tail -n 120 /tmp/x11vnc.log 2>/dev/null || true
    exit 1
  fi
done
