# vd-hotkeys

[Русский](#русский) · [English](#english)

## Русский

Горячие клавиши для переноса активного окна между виртуальными рабочими столами Windows 11 — без
«Представления задач» (Win+Tab).

В Windows 11 нет горячей клавиши «перенести окно на другой стол»: это делается только через Win+Tab →
правый клик по окну → «Переместить в». Перейти сразу на стол с нужным номером тоже нельзя — только
листать соседние Win + Ctrl + ← / →. Этот скрипт добавляет и то и другое.

**Перенести активное окно**

| Клавиши | Действие |
|---|---|
| **Win + Ctrl + Shift + ←** / **→** | на соседний стол (правее последнего — создаётся новый) |
| **Win + Ctrl + Shift + 1 … 9** | на стол с этим номером (недостающие столы создаются) |

По умолчанию вы переходите на стол вместе с окном, внизу на секунду появляется «Окно → стол N».

**Перейти на стол** (окна остаются на месте)

| Клавиши | Действие |
|---|---|
| **Win + Ctrl + Alt + ←** / **→** | на соседний стол — то же, что встроенное Win + Ctrl + ← / → |
| **Win + Ctrl + Alt + 1 … 9** | на стол с этим номером (несуществующие не создаются) |

Основа у всех сочетаний — Win + Ctrl, как у встроенного переключения столов: **Shift** — взять окно с собой,
**Alt** — просто перейти. Win + Ctrl + 1 … 9 не занято специально: в Windows это переключение на N-ю
программу панели задач.

### Установка

PowerShell **от имени администратора**:

```powershell
irm https://raw.githubusercontent.com/Er2003/vd-hotkeys/main/install.ps1 | iex
```

или скачайте репозиторий и запустите `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

Установщик:
- скачивает переносной AutoHotkey v2 и VirtualDesktopAccessor.dll под вашу сборку Windows, сверяет SHA-256;
- кладёт всё в `%LOCALAPPDATA%\VDHotkeys`;
- регистрирует задачу планировщика `VDHotkeys` — запуск при входе с наивысшими правами, чтобы клавиши
  работали и в окнах, запущенных от администратора (без прав админа — ярлык в автозагрузке, но такие окна
  клавиши не увидят);
- запускает скрипт (значок «H» в трее).

Повторный запуск `install.ps1` обновляет установку и перезаписывает `vd-hotkeys.ahk`.

### Совместимость

| Windows | Сборка | VirtualDesktopAccessor |
|---|---|---|
| 11 22H2 / 23H2 | 22621.2215+ / 22631 | `2024-01-25-windows11` |
| 11 24H2 / 25H2 | 26100.2605+ / 26200 | `2024-12-16-windows11` |

Windows 10 и Windows 11 21H2 не поддерживаются. Обновили Windows с 23H2 до 24H2 — запустите `install.ps1`
ещё раз, он поставит нужную библиотеку.

### Настройка

В начале `%LOCALAPPDATA%\VDHotkeys\vd-hotkeys.ahk`:
- `FOLLOW := false` — только отправить окно, оставаясь на текущем столе;
- `LOGGING := true` — писать каждое нажатие в `vd-hotkeys.log` рядом со скриптом (для разбора проблем).

После правки: правый клик по значку «H» → Reload Script.

### Если не работает

- Включите `LOGGING := true`, нажмите комбинацию и посмотрите `vd-hotkeys.log`: нет строки — нажатие не дошло
  до скрипта (проверьте, что он запущен; окно от администратора при установке без прав админа), есть строка с
  `move_ret=-1` — Windows отказалась переносить это окно.
- Внутри окна удалённого рабочего стола (mstsc) клавиши с Win уходят на удалённую машину.
- После перезапуска проводника скрипт сам переподключается через ~3 секунды.

### Удаление

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

`-KeepFiles` — оставить папку `%LOCALAPPDATA%\VDHotkeys`.

## English

Hotkeys that move the active window between Windows 11 virtual desktops — no Task View (Win+Tab) needed.

Windows 11 has no shortcut for "move window to another desktop": the only way is Win+Tab → right-click a
window → "Move to". Nor can you jump straight to desktop N — only step through neighbours with
Win + Ctrl + ← / →. This script adds both.

**Move the active window**

| Keys | Action |
|---|---|
| **Win + Ctrl + Shift + ←** / **→** | to the neighbouring desktop (right of the last one creates a new desktop) |
| **Win + Ctrl + Shift + 1 … 9** | to desktop N (missing desktops are created) |

By default you switch to the target desktop together with the window and a "Window → desktop N" tooltip shows
for a second.

**Go to a desktop** (windows stay where they are)

| Keys | Action |
|---|---|
| **Win + Ctrl + Alt + ←** / **→** | to the neighbouring desktop — same as the built-in Win + Ctrl + ← / → |
| **Win + Ctrl + Alt + 1 … 9** | to desktop N (missing desktops are not created) |

Every chord is built on Win + Ctrl, like the built-in desktop switching: **Shift** takes the window along,
**Alt** just goes. Win + Ctrl + 1 … 9 is left alone on purpose: Windows uses it to switch to the N-th taskbar app.

### Install

From an **elevated** PowerShell:

```powershell
irm https://raw.githubusercontent.com/Er2003/vd-hotkeys/main/install.ps1 | iex
```

or clone the repo and run `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

The installer:
- downloads portable AutoHotkey v2 and the VirtualDesktopAccessor.dll build for your Windows, verifies SHA-256;
- puts everything into `%LOCALAPPDATA%\VDHotkeys`;
- registers the `VDHotkeys` scheduled task — at logon with highest privileges, so the hotkeys also work in
  windows running as administrator (without elevation it falls back to a Startup shortcut, and such windows
  won't see the hotkeys);
- starts the script ("H" icon in the tray).

Re-running `install.ps1` updates the install and overwrites `vd-hotkeys.ahk`.

### Compatibility

| Windows | Build | VirtualDesktopAccessor |
|---|---|---|
| 11 22H2 / 23H2 | 22621.2215+ / 22631 | `2024-01-25-windows11` |
| 11 24H2 / 25H2 | 26100.2605+ / 26200 | `2024-12-16-windows11` |

Windows 10 and Windows 11 21H2 are not supported. After upgrading 23H2 → 24H2 run `install.ps1` again to get
the matching DLL.

### Configuration

At the top of `%LOCALAPPDATA%\VDHotkeys\vd-hotkeys.ahk`:
- `FOLLOW := false` — just send the window away and stay on the current desktop;
- `LOGGING := true` — log every hotkey press to `vd-hotkeys.log` next to the script (for troubleshooting).

Then right-click the "H" tray icon → Reload Script.

### Troubleshooting

- Set `LOGGING := true`, press the chord and check `vd-hotkeys.log`: no line — the press never reached the script
  (is it running? an elevated window with a non-elevated install?), a line with `move_ret=-1` — Windows refused
  to move that window.
- Inside a Remote Desktop (mstsc) window, Win-chords go to the remote machine.
- After an Explorer restart the script reconnects by itself in ~3 seconds.

### Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

`-KeepFiles` keeps the `%LOCALAPPDATA%\VDHotkeys` folder.

## Credits / Благодарности

- [VirtualDesktopAccessor](https://github.com/Ciantic/VirtualDesktopAccessor) by Jari Pennanen — MIT License.
  The DLL that talks to the Windows virtual desktop API.
- [AutoHotkey](https://www.autohotkey.com/) — GNU GPL v2.

Neither is included in this repository: `install.ps1` downloads the pinned official releases and checks their
SHA-256.

## License

[MIT](LICENSE) — for the files in this repository.
