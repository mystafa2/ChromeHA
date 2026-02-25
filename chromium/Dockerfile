ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

ENV LANG=C.UTF-8 \
    DISPLAY=:0 \
    CHROME_USER_DATA_DIR=/data/chromium

RUN set -eux; \
    packages='chromium tigervnc openbox novnc websockify ttf-freefont dbus'; \
    attempt=1; \
    max_attempts=5; \
    while [ "${attempt}" -le "${max_attempts}" ]; do \
      echo "[build] apk install attempt ${attempt}/${max_attempts}"; \
      if apk add --no-cache ${packages}; then \
        break; \
      fi; \
      if [ "${attempt}" -eq "${max_attempts}" ]; then \
        echo "[build] apk install failed after ${max_attempts} attempts"; \
        exit 1; \
      fi; \
      echo "[build] apk install failed, retrying in $((attempt * 10))s"; \
      sleep $((attempt * 10)); \
      attempt=$((attempt + 1)); \
    done

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
