# ChromeHA

Репозиторій Home Assistant add-on для запуску Chromium через Ingress/noVNC.

## Що виправлено для стабільності

- Add-on винесений у правильну директорію `chromium/` (вимога HA для custom repository).
- Режим запуску змінено на **manual** (`boot: manual`), щоб Chromium не стартував автоматично при інсталяції/перезапуску HA.
- Додано більш сумісний запуск Chromium (`--no-sandbox`, авто-вибір `chromium-browser|chromium`).
- Підтримувані архітектури звужені до `amd64` та `aarch64` для зменшення ризику проблем під час встановлення.

## Структура

- `repository.yaml` — опис репозиторію.
- `chromium/config.json` — конфіг add-on.
- `chromium/Dockerfile` — збірка контейнера.
- `chromium/run.sh` — запуск Xvfb + VNC + noVNC + Chromium.

## Встановлення

1. **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Додайте URL цього репозиторію.
3. Відкрийте add-on **Chromium Browser**.
4. Натисніть **Install**.
5. Після встановлення відкрийте **Configuration** (за потреби), потім натисніть **Start** вручну.
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


## Діагностика падінь

- Якщо вкладка Ingress біла або add-on зупиняється, перегляньте логи add-on: тепер у лог виводяться останні рядки `xvfb`, `x11vnc`, `novnc` та `chromium` при помилках.
- Додано автоматичний перезапуск Chromium, тому короткі падіння браузера не повинні зупиняти весь add-on.
