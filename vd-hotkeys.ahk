#Requires AutoHotkey v2.0
#SingleInstance Force

; vd-hotkeys — move the active window between Windows 11 virtual desktops with hotkeys,
; no Task View (Win+Tab) needed.
;
; Move the active window:
;   Win+Ctrl+Shift+Left / Right       neighbouring desktop (right of the last one creates a new desktop)
;   Win+Ctrl+Shift+1 … 9              desktop N (missing desktops are created)
; Go to a desktop (the window stays):
;   Win+Ctrl+Alt+Left / Right         neighbouring desktop (same as the built-in Win+Ctrl+Left / Right)
;   Win+Ctrl+Alt+1 … 9                desktop N
; Win+Ctrl is the base, as in the built-in desktop switching; Shift takes the window along, Alt just goes.
; Win+Ctrl+1 … 9 is left alone: Windows uses it to switch to the N-th taskbar app.
;
; Needs lib\VirtualDesktopAccessor.dll (github.com/Ciantic/VirtualDesktopAccessor) built for your Windows:
; 22H2/23H2 (22621/22631) — release 2024-01-25-windows11, 24H2+ (26100.2605+) — 2024-12-16-windows11.
; install.ps1 picks the right one.

FOLLOW  := true   ; true — switch to the target desktop together with the window, false — just send it there
LOGGING := false  ; true — write every hotkey press to vd-hotkeys.log next to the script

RU := (DllCall("GetUserDefaultUILanguage", "UShort") & 0x3FF) = 0x19

dllPath := A_ScriptDir "\lib\VirtualDesktopAccessor.dll"
hVDA := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
if !hVDA {
    MsgBox(T("Не загрузилась ", "Cannot load ") dllPath, "vd-hotkeys", "Iconx")
    ExitApp()
}
procCount   := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "GetDesktopCount", "Ptr")
procCurrent := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "GetCurrentDesktopNumber", "Ptr")
procGoTo    := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "GoToDesktopNumber", "Ptr")
procMove    := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "MoveWindowToDesktopNumber", "Ptr")
procCreate  := DllCall("GetProcAddress", "Ptr", hVDA, "AStr", "CreateDesktop", "Ptr")

A_IconTip := T("Окно на стол: Win+Ctrl+Shift + ← / → / 1…9`nПерейти: Win+Ctrl+Alt + ← / → / 1…9",
    "Move window: Win+Ctrl+Shift + ← / → / 1…9`nGo to desktop: Win+Ctrl+Alt + ← / → / 1…9")

; After an Explorer restart the DLL still holds the old shell objects — reload once the new taskbar is up.
OnMessage(DllCall("RegisterWindowMessage", "Str", "TaskbarCreated", "UInt"), OnTaskbarCreated)

#^+Left:: MoveActiveTo(DllCall(procCurrent, "Int") - 1)
#^+Right:: MoveActiveTo(DllCall(procCurrent, "Int") + 1)
#^!Left:: GoToDesktop(DllCall(procCurrent, "Int") - 1)
#^!Right:: GoToDesktop(DllCall(procCurrent, "Int") + 1, T("Правее столов нет", "No desktop to the right"))
Loop 9 {
    Hotkey("#^+" A_Index, MoveToNumber.Bind(A_Index - 1))
    Hotkey("#^!" A_Index, GoToNumber.Bind(A_Index - 1))
}
WriteLog("start admin=" A_IsAdmin " desktops=" DllCall(procCount, "Int") " current=" DllCall(procCurrent, "Int"))

/**
 * Win+Ctrl+Shift+digit handler.
 * @param target zero-based desktop number
 */
MoveToNumber(target, *) {
    MoveActiveTo(target)
}

/**
 * Win+Ctrl+Alt+digit handler.
 * @param target zero-based desktop number
 */
GoToNumber(target, *) {
    GoToDesktop(target)
}

/**
 * Switches to desktop `target` (zero-based) without moving windows; missing desktops are not created.
 * @param target    zero-based desktop number
 * @param noneRight message when there is no such desktop (default: "no desktop N")
 */
GoToDesktop(target, noneRight := "") {
    count := DllCall(procCount, "Int")
    WriteLog("hotkey=" A_ThisHotkey " goto=" target " count=" count)
    if target < 0 {
        Notify(T("Левее столов нет", "No desktop to the left"))
        return
    }
    if target >= count {
        Notify(noneRight != "" ? noneRight
            : T("Стола " (target + 1) " нет, всего " count, "No desktop " (target + 1) ", there are " count))
        return
    }
    DllCall(procGoTo, "Int", target, "Int")
    Notify(T("Стол ", "Desktop ") (target + 1))
}

/**
 * Moves the active window to desktop `target` (zero-based), creating missing desktops.
 * @param target zero-based desktop number
 */
MoveActiveTo(target) {
    hwnd := WinExist("A")
    WriteLog("hotkey=" A_ThisHotkey " target=" target " hwnd=" hwnd " " WinInfo(hwnd))
    if !hwnd
        return
    try cls := WinGetClass(hwnd)
    catch
        return
    if cls ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$"
        return
    if target < 0 {
        Notify(T("Левее столов нет", "No desktop to the left"))
        return
    }

    count := DllCall(procCount, "Int")
    while count <= target {
        DllCall(procCreate, "Int")
        count++
    }

    ret := DllCall(procMove, "Ptr", hwnd, "Int", target, "Int")
    WriteLog("  count=" count " move_ret=" ret)
    if ret < 0 {
        Notify(T("Это окно перенести не удалось", "Cannot move this window"))
        return
    }
    if FOLLOW {
        DllCall(procGoTo, "Int", target, "Int")
        try WinActivate(hwnd)
    }
    Notify(T("Окно → стол ", "Window → desktop ") (target + 1))
}

/**
 * Picks the message for the user's UI language.
 * @param ru Russian text
 * @param en English text
 */
T(ru, en) {
    return RU ? ru : en
}

/**
 * Appends a line to vd-hotkeys.log when LOGGING is on.
 * @param text line text
 */
WriteLog(text) {
    if !LOGGING
        return
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " text "`n", A_ScriptDir "\vd-hotkeys.log", "UTF-8")
}

/**
 * Window class, process and title for the log.
 * @param hwnd window handle
 */
WinInfo(hwnd) {
    try return "class=" WinGetClass(hwnd) " exe=" WinGetProcessName(hwnd) " title=" SubStr(WinGetTitle(hwnd), 1, 60)
    catch
        return "(no access to window)"
}

/**
 * Short tooltip near the cursor.
 * @param text tooltip text
 */
Notify(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -1200)
}

/**
 * Explorer restarted — reload the script after a pause while the shell comes up.
 */
OnTaskbarCreated(*) {
    SetTimer(() => Reload(), -3000)
}
