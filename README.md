# ChromeHA

Home Assistant add-on, який запускає браузер Chromium у віртуальному X11-дисплеї та відкриває його через noVNC в Ingress.

## Що це дає

- Запуск Chromium прямо в Home Assistant Add-on.
- Доступ до браузера через **Sidebar / Ingress**.
- Налаштування стартової URL, розміру вікна, kiosk/incognito режимів.

## Структура репозиторію

- `repository.yaml` — метаінформація репозиторію add-on'ів.
- `config.json` — конфіг add-on для Home Assistant.
- `Dockerfile` — збірка контейнера.
- `run.sh` — старт Xvfb, VNC, noVNC та Chromium.

## Встановлення в Home Assistant

1. В Home Assistant: **Settings → Add-ons → Add-on Store → ⋮ → Repositories**.
2. Додайте URL цього репозиторію.
3. Відкрийте add-on **Chromium Browser**.
4. Натисніть **Install**, потім **Start**.
5. Увімкніть **Show in sidebar**, щоб відкривати Chromium з меню HA.

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

## Примітки

- Chromium працює всередині контейнера, тому вебкамери/USB-пристрої можуть потребувати додаткових прав та мапінгів.
- Для важких сайтів збільште ресурси host-системи та вимкніть `disable_gpu`, якщо є апаратне прискорення.
