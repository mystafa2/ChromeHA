# ChromeHA

Репозиторій Home Assistant add-on для запуску **Chromium** через Ingress/noVNC.

> Для сумісності з різними версіями noVNC використовується `vnc.html` (а не `vnc_lite.html`).

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
auto_window_size: true
kiosk: false
incognito: false
disable_gpu: true
vnc_password: "homeassistant"
reset_profile_on_start: false
force_tab_bar: true
vnc_ncache: 10
```

## Збірка

У Dockerfile лишено retry-логіку `apk add` (до 5 спроб), щоб переживати тимчасові TLS/дзеркальні збої під час завантаження великих пакетів Chromium.

## Сумісність

- `mcookie` може бути відсутній у деяких base image; у такому випадку cookie для Xauthority генерується fallback-методом через `/dev/urandom`.

- Chromium запускається з `--no-sandbox --disable-setuid-sandbox`, оскільки add-on працює від root у контейнері HA; інакше браузер циклічно падає з помилкою `Running as root without --no-sandbox`.


## Видимість вкладки в HA

- У `config.json` встановлено `panel_admin: false`, тому вкладка add-on видима не лише адміну.
- Якщо браузер відкривається без звичних вкладок (збережений app/session режим), увімкніть `reset_profile_on_start: true` і перезапустіть add-on.

- Якщо не видно верхню панель вкладок Chromium, залишайте `force_tab_bar: true` (за замовчуванням): add-on відкриває додаткову `chrome://newtab/` вкладку, щоб tab bar відображався завжди.

- Якщо `kiosk: true`, вкладки за визначенням приховані. Коли `force_tab_bar: true`, add-on автоматично ігнорує kiosk-режим, щоб вкладки були видимі.
- Для гарантованого відображення tab-strip add-on стартує Chromium з двома вкладками: `chrome://newtab/` і `start_url`.

- Для автопідбору розміру при відкритті add-on використовується `auto_window_size: true` (default): Chromium стартує з `--start-maximized`, а VNC увімкнено з `-xrandr` для remote-resize.


## Автомасштаб як в embedded-browser

Реалізація наближена до підходу embedded-browser:
- noVNC працює в режимі `resize=remote`;
- `x11vnc` запускається з `-xrandr` коли `auto_window_size: true`;
- Xvfb стартує з великим canvas (`3840x2160`) у auto-режимі, далі початковий розмір виставляється через `xrandr --fb`, а noVNC (`resize=remote`) + `x11vnc -xrandr` виконують подальше підлаштування.

`window_width/window_height` в auto-режимі — це стартовий розмір. Далі при відкритті/зміні вікна Ingress розмір підлаштовується автоматично.
