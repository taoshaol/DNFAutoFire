#Requires AutoHotkey v2.0

; 龙战识别：监测能量条颜色，掉落到蓝色部分时按当前预设的主动技能（开关与区域为全局）

class LongZhan {
    static TickMs := 50
    static CooldownMs := 600
    static _sessionId := 0
    static _tickFn := false
    static _armed := false
    static _lastFireTick := 0
    static _presetName := ""
    static _registeredHotkey := false
    static _lastHotkey := ""
}

LongZhan_LoadEnabled() {
    return AutoPresets_CoerceIniBool(LoadConfig("LongZhanEnabled", false))
}

LongZhan_LoadSkillKey(presetName := "") {
    presetName := ResolvePresetName(presetName)
    sentinel := Chr(1)
    raw := LoadPreset(presetName, "LongZhanSkillKey", sentinel)
    if (raw = sentinel) {
        raw := LoadConfig("LongZhanSkillKey", " ")
    }
    key := Trim(raw)
    return (key = " ") ? "" : key
}

LongZhan_SaveSkillKey(presetName, key) {
    presetName := NormalizePresetName(presetName)
    if (presetName = "") {
        return
    }
    SavePreset(presetName, "LongZhanSkillKey", Trim(String(key)))
}

LongZhan_ParseRegion() {
    return ParseAutoPresetRegionByKey("LongZhanRegion")
}

LongZhan_SaveRegion(x, y, w, h) {
    SaveAutoPresetRegionByKey("LongZhanRegion", x, y, w, h)
}

LongZhan_HasRegion() {
    r := LongZhan_ParseRegion()
    return IsObject(r) && r.Has("mode") && r["mode"] = "clientRatio"
}

LongZhan_LoadHotkey() {
    hk := Trim(LoadConfig("LongZhanHotkey", " "))
    return (hk = " ") ? "" : hk
}

LongZhan_IsReady() {
    if !LongZhan_LoadEnabled() {
        return false
    }
    if !LongZhan_HasRegion() {
        return false
    }
    return true
}

LongZhan_DefaultRegion() {
    w := 360
    h := 32
    client := AutoPresets_GetGameClientRect()
    if IsObject(client) {
        return Map("x", client["x"] + (client["w"] - w) // 2, "y", client["y"] + (client["h"] - h) // 2, "w", w, "h", h)
    }
    return Map("x", (A_ScreenWidth - w) // 2, "y", (A_ScreenHeight - h) // 2, "w", w, "h", h)
}

LongZhan_ResolveRegion() {
    stored := LongZhan_ParseRegion()
    if !IsObject(stored) || !stored.Has("mode") || stored["mode"] != "clientRatio" {
        return LongZhan_DefaultRegion()
    }
    return AutoPresets_ResolveRegion(stored)
}

LongZhanAssetDir() => A_ScriptDir "\assets\longzhan-recognition"

LongZhanIconCurrentPath() {
    resKey := AutoPresetsResolutionKey()
    if (resKey = "") {
        throw Error("未找到 DNF 游戏窗口，无法按分辨率保存龙战识别图。")
    }
    return LongZhanAssetDir() "\" resKey ".png"
}

LongZhanIconPaths() {
    paths := []
    dir := LongZhanAssetDir()
    if !DirExist(dir) {
        return paths
    }
    Loop Files dir "\*.png" {
        if !RegExMatch(A_LoopFileName, "^\d+x\d+\.png$") {
            continue
        }
        paths.Push(A_LoopFileFullPath)
    }
    return paths
}

LongZhan_HasAnyPng() {
    return LongZhanIconPaths().Length > 0
}

LongZhanIcon_UpdateCurrent() {
    r := LongZhan_ResolveRegion()
    path := LongZhanIconCurrentPath()
    AutoPresetsCaptureRegionToPng(path, r["x"], r["y"], r["w"], r["h"])
    return path
}

LongZhan_SendToken() {
    return ExAction_SendToken(LongZhan_LoadSkillKey())
}

LongZhan_IsCyan(color) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF
    return r < 110 && g > 180 && b > 180 && (g + b) > 400
}

LongZhan_IsRed(color) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF
    return r > 150 && g < 130 && b < 110 && r > g + 40 && r > b + 40
}

; 只扫能量条中线，避开外圈橙光。
; above=仍有红段（约 50% 以上）；below=只剩蓝段；gone=整条消失
LongZhan_ReadBarState(region) {
    if !IsObject(region) || !region.Has("w") || region["w"] < 8 || region["h"] < 2 {
        return "gone"
    }
    x := region["x"]
    y := region["y"]
    w := region["w"]
    h := region["h"]
    x1 := x + Max(3, Round(w * 0.22))
    x2 := x + w - Max(3, Round(w * 0.08))
    if (x2 <= x1) {
        x1 := x + 2
        x2 := x + w - 2
    }
    yMid := y + h // 2
    step := Max(2, Round(w / 56))
    sawRed := false
    sawBlue := false
    prevPixel := CoordMode("Pixel", "Screen")
    try {
        px := x1
        while (px <= x2) {
            try {
                color := PixelGetColor(px, yMid, "RGB")
            } catch {
                px += step
                continue
            }
            if LongZhan_IsRed(color) {
                sawRed := true
            } else if LongZhan_IsCyan(color) {
                sawBlue := true
            }
            if (sawRed && sawBlue) {
                break
            }
            px += step
        }
    } finally {
        CoordMode("Pixel", prevPixel)
    }
    if sawRed {
        return "above"
    }
    if sawBlue {
        return "below"
    }
    return "gone"
}

LongZhan_OnSessionStarted() {
    LongZhan._sessionId += 1
    LongZhan._armed := false
    LongZhan._lastFireTick := 0
    LongZhan._presetName := ""
    LongZhan_StopTimer()
    LongZhan_RegisterToggleHotkey()
    LongZhan_StartTimerIfEnabled()
}

LongZhan_OnSessionStopped() {
    LongZhan._sessionId += 1
    LongZhan._armed := false
    LongZhan._lastFireTick := 0
    LongZhan._presetName := ""
    LongZhan_DisableToggleHotkey()
    LongZhan_StopTimer()
}

LongZhan_StartTimerIfEnabled() {
    LongZhan_StopTimer()
    if !LongZhan_LoadEnabled() || !LongZhan_HasRegion() {
        return
    }
    sessionId := LongZhan._sessionId
    fn := LongZhan_Tick.Bind(sessionId)
    LongZhan._tickFn := fn
    SetTimer(fn, LongZhan.TickMs)
}

LongZhan_HotIfShouldFire(*) {
    if !AutoPresets_IsSessionRunning() {
        return false
    }
    title := FindDNFGameWindowTitle()
    if ShowTipIsGameShown(title) {
        return WinActive("ahk_group DNF") != 0
    }
    return true
}

LongZhan_DisableToggleHotkey() {
    HotIf(LongZhan_HotIfShouldFire)
    if LongZhan._registeredHotkey && LongZhan._lastHotkey != "" {
        try Hotkey("~$" LongZhan._lastHotkey, "Off")
        LongZhan._registeredHotkey := false
        LongZhan._lastHotkey := ""
    }
    HotIf()
}

LongZhan_RegisterToggleHotkey() {
    LongZhan_DisableToggleHotkey()
    if !AutoPresets_IsSessionRunning() {
        return
    }
    hk := LongZhan_LoadHotkey()
    if (hk = "") {
        return
    }
    HotIf(LongZhan_HotIfShouldFire)
    try {
        Hotkey("~$" hk, LongZhan_ToggleFromHotkey, "On")
        LongZhan._lastHotkey := hk
        LongZhan._registeredHotkey := true
    }
    HotIf()
}

LongZhan_ToggleFromHotkey(*) {
    v := !LongZhan_LoadEnabled()
    SaveConfig("LongZhanEnabled", v)
    try LongZhanRefreshEnableCheckbox()
    LongZhan._armed := false
    LongZhan._lastFireTick := 0
    LongZhan._presetName := ""
    if AutoPresets_IsSessionRunning() {
        if v {
            LongZhan_StartTimerIfEnabled()
        } else {
            LongZhan_StopTimer()
        }
    }
    tip := v ? "龙战识别已开启" : "龙战识别已关闭"
    if IsSet(LongZhanText) && IsObject(LongZhanText) {
        tip := v ? LongZhanText["TipOn"] : LongZhanText["TipOff"]
    }
    ShowTip(tip)
}

LongZhan_StopTimer() {
    if LongZhan._tickFn {
        try SetTimer(LongZhan._tickFn, 0)
        LongZhan._tickFn := false
    }
}

LongZhan_Tick(sessionId, *) {
    if (sessionId != LongZhan._sessionId) {
        return
    }
    if !LongZhan_LoadEnabled() || !LongZhan_HasRegion() {
        return
    }
    if !WinActive("ahk_group DNF") {
        return
    }
    if GlobalPause_IsPaused() {
        return
    }
    presetName := ResolvePresetName()
    if (presetName != LongZhan._presetName) {
        LongZhan._presetName := presetName
        LongZhan._armed := false
    }
    if (LongZhan_LoadSkillKey(presetName) = "") {
        return
    }
    state := LongZhan_ReadBarState(LongZhan_ResolveRegion())
    if (state = "gone") {
        LongZhan._armed := false
        return
    }
    if (state = "above") {
        LongZhan._armed := true
        return
    }
    if (state != "below" || !LongZhan._armed) {
        return
    }
    now := A_TickCount
    if (LongZhan._lastFireTick && (now - LongZhan._lastFireTick < LongZhan.CooldownMs)) {
        return
    }
    token := LongZhan_SendToken()
    if (token = "") {
        return
    }
    LongZhan._lastFireTick := now
    SendIP(token)
}
