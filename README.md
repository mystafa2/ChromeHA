# ChromeHA

Репозиторій Home Assistant add-on для запуску Chromium через Ingress/noVNC.

## Чому раніше не встановлювалось

Home Assistant очікує структуру **репозиторію add-on'ів**: кожен add-on має бути в окремій директорії.
Тому add-on перенесено в папку `chromium/`.

## Структура

- `repository.yaml` — опис репозиторію.
- `chromium/config.json` — конфіг add-on.
- `chromium/Dockerfile` — збірка контейнера.
- `chromium/run.sh` — запуск Xvfb + VNC + noVNC + Chromium.

## Встановлення

1. **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Додайте URL цього репозиторію.
3. Відкрийте add-on **Chromium Browser**.
4. Натисніть **Install** → **Start**.
5. За потреби увімкніть **Show in sidebar**.

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
