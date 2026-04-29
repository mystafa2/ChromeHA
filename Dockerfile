ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV LANG=C.UTF-8 \
    DISPLAY=:0 \
    CHROME_USER_DATA_DIR=/data/chromium

RUN apk add --no-cache \
    chromium \
    xvfb \
    x11vnc \
    fluxbox \
    novnc \
    ttf-freefont \
    dbus

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
