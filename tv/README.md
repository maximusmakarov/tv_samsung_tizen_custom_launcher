# tv/ — сетевые помощники

| Скрипт | Что делает |
|---|---|
| `tv_remote.py` | websocket-пульт: `pair`, `key KEY_UP`, `hold KEY_POWER --seconds 5`, `token` |
| `snap.py` | один кадр с камеры компьютера (альтернатива TeleCam.app) |
| `pair_listen.py` | слушает канал пейринга, печатает сообщения и сохраняет токен |

Требуется Python 3 и `websocket-client` (для `tv_remote.py`); адрес ТВ задаётся переменной
`TV_IP` (не хардкодится). Токен пейринга сохраняется в `tv/token.json` — он в `.gitignore`
и в репозиторий не попадает.
