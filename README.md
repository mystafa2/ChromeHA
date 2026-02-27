# ChromeHA

Репозиторій Home Assistant add-on для запуску **Chromium** через Ingress/noVNC.

## Що змінено для стабільного запуску

Після проблем зі стартом `TigerVNC`/`x11vnc -auth guess` add-on переведено на стабільніший сценарій:

- `Xvfb` як X-сервер;
- явний `XAUTHORITY` файл через `xauth` + `mcookie`;
- `x11vnc` підключається через `-auth /tmp/Xauthority` (без guess);
- автоматичне очищення stale lock/socket (`/tmp/.X0-lock`, `/tmp/.X11-unix/X0`) перед стартом;
- `websockify + noVNC` для Ingress.

Це прибирає типові падіння:
- `usage: vncserver <display>`
- `XOpenDisplay(":0") failed`
- `Xvfb did not create display socket :0` (через старі lock-файли).

## Структура

- `repository.yaml` — опис репозиторію.
- `chromium/config.json` — конфіг add-on.
- `chromium/Dockerfile` — збірка контейнера.
- `chromium/run.sh` — запуск Xvfb + x11vnc + noVNC + Chromium.

## Встановлення

1. **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Додайте URL цього репозиторію.
3. Відкрийте add-on **Chromium Browser**.
4. Натисніть **Install**.
5. Відкрийте **Configuration** (за потреби), потім натисніть **Start**.
6. Увімкніть **Show in sidebar**.

## Опції add-on

```yaml
start_url: "https://www.home-assistant.io"
window_width: 1280
window_height: 720
kiosk: false
incognito: false
disable_gpu: true
vnc_password: "homeassistant"
```

## Збірка

У Dockerfile лишено retry-логіку `apk add` (до 5 спроб), щоб переживати тимчасові TLS/дзеркальні збої під час завантаження великих пакетів Chromium.
