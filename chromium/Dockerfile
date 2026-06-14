ARG BUILD_FROM=ghcr.io/home-assistant/base:3.23
ARG CHROMIUM_VERSION=149.0.7827.53-r0
FROM ${BUILD_FROM}
ARG CHROMIUM_VERSION

ENV LANG=C.UTF-8 \
    DISPLAY=:0 \
    CHROME_USER_DATA_DIR=/data/chromium

RUN set -eux; \
    chromium_pkg="chromium"; \
    if [ -n "${CHROMIUM_VERSION:-}" ]; then \
      chromium_pkg="chromium=${CHROMIUM_VERSION}"; \
    fi; \
    common_packages="xvfb x11vnc fluxbox novnc websockify ttf-freefont dbus xauth xrandr"; \
    attempt=1; \
    max_attempts=5; \
    while [ "${attempt}" -le "${max_attempts}" ]; do \
      echo "[build] apk install attempt ${attempt}/${max_attempts}"; \
      if apk add --no-cache ${chromium_pkg} ${common_packages}; then \
        break; \
      fi; \
      if [ "${attempt}" -eq 1 ]; then \
        echo "[build] pinned Chromium ${CHROMIUM_VERSION:-latest} unavailable for this arch/repo, fallback to latest available"; \
        chromium_pkg="chromium"; \
      fi; \
      if [ "${attempt}" -eq "${max_attempts}" ]; then \
        echo "[build] apk install failed after ${max_attempts} attempts"; \
        exit 1; \
      fi; \
      sleep $((attempt * 10)); \
      attempt=$((attempt + 1)); \
    done

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
