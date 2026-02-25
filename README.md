# ChromeHA

Репозиторій Home Assistant add-on для запуску **Chromium** через Ingress/noVNC.

## Що перероблено (на основі підходу з bigmoby/addon-embedded-browser)

Щоб прибрати «гальма» інтерфейсу, add-on перероблено на легший VNC-пайплайн:

- замість `Xvfb + fluxbox + x11vnc` тепер використовується **TigerVNC server**;
- web-клієнт працює через **websockify + noVNC**;
- браузер запускається в X-сесії TigerVNC з легким WM **openbox**;
- Ingress відкриває `vnc_lite.html` з параметрами стиснення/якості для кращої швидкодії;
- додано опцію `color_depth` (`16` або `24`), за замовчуванням `16` для вищої продуктивності.

## Структура

- `repository.yaml` — опис репозиторію.
- `chromium/config.json` — конфіг add-on.
- `chromium/Dockerfile` — збірка контейнера.
- `chromium/run.sh` — запуск TigerVNC + noVNC + Chromium.

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
color_depth: 16   # 16 швидше, 24 якісніше
kiosk: false
incognito: false
disable_gpu: true
vnc_password: "homeassistant"
```

## Нотатки продуктивності

- Найшвидший режим зазвичай: `color_depth: 16` + `disable_gpu: true`.
- Якщо на вашому host є стабільний GPU passthrough, можна спробувати `disable_gpu: false`.
- Якщо Chromium падає, add-on автоматично перезапускає браузер без повного стопу контейнера.


## Якщо збірка падає з `TLS handshake timeout`

Це мережева проблема доступу HA Supervisor до `ghcr.io`/alpine-дзеркал, а не помилка логіки add-on.

Що зроблено в цьому репозиторії:

- у Dockerfile додано retry-логіку для `apk add` (до 5 спроб) через нестабільні TLS/дзеркала на великих пакетах Chromium.
- у `Dockerfile` додано безпечний default для `ARG BUILD_FROM`, щоб прибрати попередження `InvalidDefaultArgInFrom`;
- у Home Assistant значення `BUILD_FROM` все одно підставляється Supervisor-ом під вашу архітектуру.

Що зробити у HA:
- повторити install/build через 1-2 хвилини;
- перевірити DNS/інтернет на хості HA;
- якщо є проксі/фаєрвол — дозволити доступ до `https://ghcr.io` і `https://github.com`.
