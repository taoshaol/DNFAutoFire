#Requires AutoHotkey v2.0

; 自动识别配置：搜图匹配技能栏参考图后切换预设

class AutoPresets {
    static StartDelayMs := 200
    static FastIntervalMs := 500
    static ChatIntervalMs := 200
    static RelaxedVariation := 160
    static RelaxedScaledExtra := 70
    static RelaxedNearPx := 8
    static RelaxedJitterPx := 3
    static RelaxedExpandRatio := 0.08
    static RelaxedExpandMinX := 8
    static RelaxedExpandMinY := 6
    static StrictVariation := 120
    static StrictScaledExtra := 40
    static StrictNearPx := 4
    static StrictJitterPx := 0
    static StrictExpandRatio := 0.05
    static StrictExpandMinX := 6
    static StrictExpandMinY := 4
    static ScaleInterpBicubic := 7
    static ScaleInterpNearest := 5
    static RegionCornerRadius := 12
    static RegionMaskRgb := "White"
    static ChatImageVariation := 50
    static ChatOpenConfirmTicks := 3
    static ChatCloseConfirmTicks := 3
    static _skillTimer := false
    static _fastUntilTick := 0
    static _chatTimer := false
    static _chatHitStreak := 0
    static _chatMissStreak := 0
    static _registeredEsc := false
    static _registeredCustom := false
    static _lastCustomHotkey := ""
    static _sessionId := 0
    static _scaledNeedleCache := Map()
    static _scaledNeedleSeq := 0
}

; 是否开启「自动识别」（全局，config.ini [设置]）
AutoPresets_LoadEnabledGlobal() {
    return AutoPresets_CoerceIniBool(LoadConfig("AutoPresetsEnabled", false))
}

AutoPresets_CoerceIniBool(raw) {
    if (IsNumber(raw)) {
        return (raw + 0) != 0
    }
    s := StrLower(Trim(String(raw)))
    return (s = "1" || s = "true" || s = "yes" || s = "on")
}

AutoPresets_MatchStrictDefault() => 100

AutoPresets_ClampMatchStrict(raw) {
    n := 0
    try n := Integer(Trim(String(raw)))
    catch {
        n := AutoPresets_MatchStrictDefault()
    }
    if (n < 0) {
        return 0
    }
    if (n > 100) {
        return 100
    }
    return n
}

AutoPresets_LoadMatchStrict() {
    return AutoPresets_ClampMatchStrict(LoadConfig("AutoPresetMatchStrict", AutoPresets_MatchStrictDefault()))
}

AutoPresets_RecognizeSecondsDefault() => 60

AutoPresets_ClampRecognizeSeconds(raw) {
    n := 0
    try n := Integer(Trim(String(raw)))
    catch {
        n := AutoPresets_RecognizeSecondsDefault()
    }
    if (n < 1) {
        return 1
    }
    if (n > 600) {
        return 600
    }
    return n
}

AutoPresets_LoadRecognizeSeconds() {
    return AutoPresets_ClampRecognizeSeconds(LoadConfig("AutoPresetRecognizeSeconds", AutoPresets_RecognizeSecondsDefault()))
}

AutoPresets_LoadRecognizeDurationMs() {
    return AutoPresets_LoadRecognizeSeconds() * 1000
}

AutoPresets_LerpInt(relaxed, strict, t) {
    return Round(relaxed + (strict - relaxed) * t / 100)
}

AutoPresets_LerpNum(relaxed, strict, t) {
    return relaxed + (strict - relaxed) * t / 100
}

AutoPresets_MatchParams() {
    t := AutoPresets_LoadMatchStrict()
    return Map(
        "variation", AutoPresets_LerpInt(AutoPresets.RelaxedVariation, AutoPresets.StrictVariation, t),
        "scaledExtra", AutoPresets_LerpInt(AutoPresets.RelaxedScaledExtra, AutoPresets.StrictScaledExtra, t),
        "nearPx", AutoPresets_LerpInt(AutoPresets.RelaxedNearPx, AutoPresets.StrictNearPx, t),
        "jitterPx", AutoPresets_LerpInt(AutoPresets.RelaxedJitterPx, AutoPresets.StrictJitterPx, t),
        "expandRatio", AutoPresets_LerpNum(AutoPresets.RelaxedExpandRatio, AutoPresets.StrictExpandRatio, t),
        "expandMinX", AutoPresets_LerpInt(AutoPresets.RelaxedExpandMinX, AutoPresets.StrictExpandMinX, t),
        "expandMinY", AutoPresets_LerpInt(AutoPresets.RelaxedExpandMinY, AutoPresets.StrictExpandMinY, t),
        "useNearest", t < 100,
        "nearExclusive", t >= 100
    )
}

AutoPresetsAssetDir() => A_ScriptDir "\assets\preset-recognition"

AutoPresetsSkillIconDir() => AutoPresetsAssetDir() "\skills"

AutoPresetsSkillIcon_SafeName(presetName) {
    return RegExReplace(StrReplace(presetName, "|", "_"), '[\\/:\*\?"<>\|]', "_")
}

AutoPresets_GetGameClientRect() {
    title := FindDNFGameWindowTitle()
    if (title = "") {
        return ""
    }
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, title)
    } catch {
        return ""
    }
    if (cw < 1 || ch < 1) {
        return ""
    }
    return Map("x", cx, "y", cy, "w", cw, "h", ch, "title", title)
}

AutoPresetsResolutionKey(client := "") {
    if !IsObject(client) {
        client := AutoPresets_GetGameClientRect()
    }
    if !IsObject(client) {
        return ""
    }
    return client["w"] "x" client["h"]
}

AutoPresets_ParseResolutionKey(key, &w, &h) {
    if !RegExMatch(Trim(key), "^(\d+)x(\d+)$", &m) {
        return false
    }
    w := Integer(m[1])
    h := Integer(m[2])
    return w > 0 && h > 0
}

AutoPresets_ResolutionDistance(keyA, keyB) {
    if !AutoPresets_ParseResolutionKey(keyA, &aw, &ah) || !AutoPresets_ParseResolutionKey(keyB, &bw, &bh) {
        return 999999
    }
    return Abs(aw - bw) + Abs(ah - bh)
}

AutoPresets_SortResolutionKeys(keys, currentKey) {
    if (keys.Length < 2) {
        return keys
    }
    sorted := keys.Clone()
    loop sorted.Length - 1 {
        loop sorted.Length - A_Index {
            i := A_Index
            if (AutoPresets_ResolutionDistance(sorted[i], currentKey) > AutoPresets_ResolutionDistance(sorted[i + 1], currentKey)) {
                tmp := sorted[i]
                sorted[i] := sorted[i + 1]
                sorted[i + 1] := tmp
            }
        }
    }
    return sorted
}

AutoPresets_SplitNearFarResolutionKeys(keys, currentKey) {
    nearKeys := []
    farKeys := []
    for key in AutoPresets_SortResolutionKeys(keys, currentKey) {
        if (AutoPresets_ResolutionDistance(key, currentKey) <= AutoPresets_MatchParams()["nearPx"]) {
            nearKeys.Push(key)
        } else {
            farKeys.Push(key)
        }
    }
    return Map("near", nearKeys, "far", farKeys)
}

AutoPresets_ListSkillResolutionKeys() {
    keys := []
    root := AutoPresetsSkillIconDir()
    if !DirExist(root) {
        return keys
    }
    Loop Files root "\*", "D" {
        key := AutoPresetsSkillResolutionKey(A_LoopFileName)
        if (key = "") {
            continue
        }
        hasPng := false
        Loop Files A_LoopFileFullPath "\*.png", "R" {
            hasPng := true
            break
        }
        if hasPng {
            keys.Push(key)
        }
    }
    return keys
}

AutoPresets_DiscoverLegacyResolutionKeys() {
    keys := []
    seen := Map()
    for key in AutoPresets_ListSkillResolutionKeys() {
        if (key = "" || seen.Has(key)) {
            continue
        }
        seen[key] := true
        keys.Push(key)
    }
    for path in AutoPresetsChatIconPaths() {
        key := AutoPresets_PngResolutionKey(path)
        if (key = "" || seen.Has(key)) {
            continue
        }
        seen[key] := true
        keys.Push(key)
    }
    return keys
}

AutoPresets_ParseResolutionKeys(raw) {
    keys := []
    seen := Map()
    raw := Trim(raw)
    if (raw = "" || raw = "-") {
        return keys
    }
    for part in StrSplit(raw, "|") {
        key := AutoPresetsSkillResolutionKey(Trim(part))
        if (key = "" || seen.Has(key)) {
            continue
        }
        seen[key] := true
        keys.Push(key)
    }
    return keys
}

AutoPresets_SaveResolutionKeys(keys) {
    parts := []
    seen := Map()
    for key in keys {
        k := AutoPresetsSkillResolutionKey(key)
        if (k = "" || seen.Has(k)) {
            continue
        }
        seen[k] := true
        parts.Push(k)
    }
    if (parts.Length = 0) {
        SaveConfig("AutoPresetResolutions", "-")
        return
    }
    text := parts[1]
    loop parts.Length - 1 {
        text .= "|" parts[A_Index + 1]
    }
    SaveConfig("AutoPresetResolutions", text)
}

AutoPresets_LoadResolutionKeys() {
    raw := LoadConfig("AutoPresetResolutions", "")
    if (Trim(raw) = "") {
        keys := AutoPresets_DiscoverLegacyResolutionKeys()
        AutoPresets_SaveResolutionKeys(keys)
        return keys
    }
    return AutoPresets_ParseResolutionKeys(raw)
}

AutoPresets_ListKnownResolutionKeys() {
    return AutoPresets_LoadResolutionKeys()
}

AutoPresets_AddResolutionKey(key) {
    key := AutoPresetsSkillResolutionKey(key)
    if (key = "") {
        throw Error("未找到 DNF 游戏窗口，无法截取分辨率。")
    }
    keys := AutoPresets_LoadResolutionKeys()
    for existing in keys {
        if (existing = key) {
            return key
        }
    }
    keys.Push(key)
    AutoPresets_SaveResolutionKeys(keys)
    return key
}

AutoPresets_RemoveResolutionKey(key) {
    key := AutoPresetsSkillResolutionKey(key)
    if (key = "") {
        return
    }
    kept := []
    for existing in AutoPresets_LoadResolutionKeys() {
        if (existing != key) {
            kept.Push(existing)
        }
    }
    AutoPresets_SaveResolutionKeys(kept)
}

AutoPresets_PngResolutionKey(path) {
    SplitPath(path, &fileName)
    return AutoPresetsSkillResolutionKey(RegExReplace(fileName, "i)\.png$", ""))
}

AutoPresetsSkillResolutionKey(resolutionKey := false) {
    if (Type(resolutionKey) = "Integer" && resolutionKey = false) {
        key := AutoPresetsResolutionKey()
    } else {
        key := Trim(resolutionKey)
    }
    return RegExMatch(key, "^\d+x\d+$") ? key : ""
}

AutoPresetsSkillResolutionDir(resolutionKey := false) {
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    return key = "" ? "" : AutoPresetsSkillIconDir() "\" key
}

AutoPresetsSkillPresetDir(presetName, resolutionKey := false) {
    resolutionDir := AutoPresetsSkillResolutionDir(resolutionKey)
    return resolutionDir = "" ? "" : resolutionDir "\" AutoPresetsSkillIcon_SafeName(presetName)
}

AutoPresetsSkillIconPathForId(presetName, skillId, resolutionKey := false) {
    dir := AutoPresetsSkillPresetDir(presetName, resolutionKey)
    return dir = "" ? "" : dir "\" skillId ".png"
}

AutoPresetsSkillIconsConfigKey(resolutionKey := false) {
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    return key = "" ? "" : "AutoPresetSkillIcons_" key
}

AutoPresetsSkillIcons_ParseStored(raw) {
    out := Map()
    raw := Trim(raw)
    if (raw = "") {
        return out
    }
    for part in StrSplit(raw, "|") {
        part := Trim(part)
        if (part = "") {
            continue
        }
        eq := InStr(part, "=")
        if !eq {
            continue
        }
        id := Trim(SubStr(part, 1, eq - 1))
        name := Trim(SubStr(part, eq + 1))
        if (id != "" && name != "") {
            out[id] := name
        }
    }
    return out
}

AutoPresetsSkillIcons_FormatStored(items) {
    parts := []
    for item in items {
        parts.Push(item["id"] "=" item["name"])
    }
    if (parts.Length = 0) {
        return ""
    }
    out := parts[1]
    loop parts.Length - 1 {
        out .= "|" parts[A_Index + 1]
    }
    return out
}

AutoPresetsSkillIcons_SortItems(items) {
    if (items.Length < 2) {
        return items
    }
    order := []
    byId := Map()
    for item in items {
        order.Push(item["id"])
        byId[item["id"]] := item
    }
    loop order.Length - 1 {
        loop order.Length - A_Index {
            i := A_Index
            ai := 0
            bi := 0
            try ai := Integer(order[i])
            catch {
                ai := 0
            }
            try bi := Integer(order[i + 1])
            catch {
                bi := 0
            }
            if (ai > bi) {
                tmp := order[i]
                order[i] := order[i + 1]
                order[i + 1] := tmp
            }
        }
    }
    sorted := []
    for id in order {
        sorted.Push(byId[id])
    }
    return sorted
}

AutoPresetsSkillIcons_Load(presetName, resolutionKey := false) {
    name := Trim(presetName)
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    if (name = "" || key = "") {
        return []
    }
    nameMap := AutoPresetsSkillIcons_ParseStored(LoadPreset(name, AutoPresetsSkillIconsConfigKey(key), ""))
    items := []
    dir := AutoPresetsSkillPresetDir(name, key)
    if !DirExist(dir) {
        return items
    }
    Loop Files dir "\*.png" {
        id := RegExReplace(A_LoopFileName, "\.png$", "", , 1)
        if (id = "") {
            continue
        }
        path := A_LoopFileFullPath
        displayName := nameMap.Has(id) ? nameMap[id] : ("角色" id)
        items.Push(Map("id", id, "name", displayName, "path", path))
    }
    return AutoPresetsSkillIcons_SortItems(items)
}

AutoPresetsSkillIcons_Save(presetName, items, resolutionKey := false) {
    name := Trim(presetName)
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    if (name = "" || key = "") {
        return
    }
    SavePreset(name, AutoPresetsSkillIconsConfigKey(key), AutoPresetsSkillIcons_FormatStored(items))
}

AutoPresetsSkillIcons_NextId(presetName, resolutionKey := false) {
    maxId := 0
    for item in AutoPresetsSkillIcons_Load(presetName, resolutionKey) {
        try n := Integer(item["id"])
        catch {
            n := 0
        }
        if (n > maxId) {
            maxId := n
        }
    }
    return String(maxId + 1)
}

AutoPresetsSkillIcons_NextDefaultName(presetName, resolutionKey := false) {
    maxN := 0
    for item in AutoPresetsSkillIcons_Load(presetName, resolutionKey) {
        try n := Integer(item["id"])
        catch {
            n := 0
        }
        if (n > maxN) {
            maxN := n
        }
        if RegExMatch(item["name"], "^角色(\d+)$", &m) {
            nn := m[1] + 0
            if (nn > maxN) {
                maxN := nn
            }
        }
    }
    return "角色" (maxN + 1)
}

AutoPresetsSkillIcon_Add(presetName, resolutionKey := false) {
    name := Trim(presetName)
    if (name = "") {
        throw Error("当前没有选中的配置。")
    }
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    if (key = "") {
        throw Error("当前没有选中的分辨率。")
    }
    dir := AutoPresetsSkillPresetDir(name, key)
    if !DirExist(dir) {
        DirCreate(dir)
    }
    skillId := AutoPresetsSkillIcons_NextId(name, key)
    displayName := AutoPresetsSkillIcons_NextDefaultName(name, key)
    path := AutoPresetsSkillIconPathForId(name, skillId, key)
    r := AutoPresets_ResolveRegion(ParseAutoPresetRegion())
    AutoPresetsCaptureRegionToPng(path, r["x"], r["y"], r["w"], r["h"])
    AutoPresetsSkillIcons_Save(name, AutoPresetsSkillIcons_Load(name, key), key)
    return Map("id", skillId, "name", displayName, "path", path)
}

AutoPresetsSkillIcon_Delete(presetName, skillId, resolutionKey := false) {
    name := Trim(presetName)
    skillId := Trim(skillId)
    if (name = "" || skillId = "") {
        return
    }
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    if (key = "") {
        return
    }
    path := AutoPresetsSkillIconPathForId(name, skillId, key)
    if FileExist(path) {
        try FileDelete(path)
    }
    kept := []
    for item in AutoPresetsSkillIcons_Load(name, key) {
        if (item["id"] != skillId) {
            kept.Push(item)
        }
    }
    AutoPresetsSkillIcons_Save(name, kept, key)
}

AutoPresetsSkillIcon_Rename(presetName, skillId, newName, resolutionKey := false) {
    name := Trim(presetName)
    skillId := Trim(skillId)
    newName := Trim(newName)
    if (name = "" || skillId = "" || newName = "") {
        return false
    }
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    if (key = "") {
        return false
    }
    items := AutoPresetsSkillIcons_Load(name, key)
    found := false
    for item in items {
        if (item["id"] = skillId) {
            item["name"] := newName
            found := true
            break
        }
    }
    if !found {
        return false
    }
    AutoPresetsSkillIcons_Save(name, items, key)
    return true
}

AutoPresetsSkillIcons_CopyDirs(srcPreset, destPreset) {
    root := AutoPresetsSkillIconDir()
    if !DirExist(root) {
        return
    }
    Loop Files root "\*", "D" {
        resolutionKey := A_LoopFileName
        if (AutoPresetsSkillResolutionKey(resolutionKey) != resolutionKey) {
            continue
        }
        srcDir := AutoPresetsSkillPresetDir(srcPreset, resolutionKey)
        destDir := AutoPresetsSkillPresetDir(destPreset, resolutionKey)
        if DirExist(destDir) {
            try DirDelete(destDir, true)
        }
        if DirExist(srcDir) {
            try DirCopy(srcDir, destDir, true)
        }
    }
}

AutoPresets_OnPresetCloned(oldName, newName) {
    AutoPresetsSkillIcons_CopyDirs(oldName, newName)
}

AutoPresets_OnPresetRenamed(oldName, newName) {
    AutoPresets_OnPresetCloned(oldName, newName)
    AutoPresets_OnPresetDeleted(oldName)
}

AutoPresets_OnPresetDeleted(presetName) {
    root := AutoPresetsSkillIconDir()
    if !DirExist(root) {
        return
    }
    Loop Files root "\*", "D" {
        resolutionKey := A_LoopFileName
        if (AutoPresetsSkillResolutionKey(resolutionKey) != resolutionKey) {
            continue
        }
        dir := AutoPresetsSkillPresetDir(presetName, resolutionKey)
        if DirExist(dir) {
            try DirDelete(dir, true)
        }
    }
}

AutoPresetsChatIconDir() => AutoPresetsAssetDir() "\chat"

AutoPresetsChatIconPathForResolution(resolutionKey) {
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    return key = "" ? "" : AutoPresetsChatIconDir() "\" key ".png"
}

AutoPresetsChatIconPaths() {
    paths := []
    dir := AutoPresetsChatIconDir()
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

AutoPresets_HasAnyChatPng() {
    return AutoPresetsChatIconPaths().Length > 0
}

AutoPresets_DefaultChatRegion() {
    w := 280
    h := 48
    client := AutoPresets_GetGameClientRect()
    if IsObject(client) {
        return Map("x", client["x"] + 16, "y", client["y"] + client["h"] - h - 72, "w", w, "h", h)
    }
    return Map("x", 16, "y", A_ScreenHeight - h - 72, "w", w, "h", h)
}

AutoPresets_DefaultRegion() {
    w := 200
    h := 90
    client := AutoPresets_GetGameClientRect()
    if IsObject(client) {
        return Map("x", client["x"] + (client["w"] - w) // 2, "y", client["y"] + (client["h"] - h) // 2, "w", w, "h", h)
    }
    return Map("x", (A_ScreenWidth - w) // 2, "y", (A_ScreenHeight - h) // 2, "w", w, "h", h)
}

AutoPresets_ResolveRegion(region, expandForSearch := false) {
    if !IsObject(region) || !region.Has("mode") || region["mode"] != "clientRatio" {
        return AutoPresets_DefaultRegion()
    }
    client := AutoPresets_GetGameClientRect()
    if !IsObject(client) {
        return AutoPresets_DefaultRegion()
    }
    x := client["x"] + Round(region["rx"] * client["w"])
    y := client["y"] + Round(region["ry"] * client["h"])
    w := Max(1, Round(region["rw"] * client["w"]))
    h := Max(1, Round(region["rh"] * client["h"]))
    out := Map("x", x, "y", y, "w", w, "h", h, "client", client)
    return expandForSearch ? AutoPresets_ExpandSearchRegion(out, client) : out
}

AutoPresets_ExpandSearchRegion(region, client := "") {
    if !IsObject(region) || !region.Has("w") {
        return region
    }
    params := AutoPresets_MatchParams()
    mx := Max(params["expandMinX"], Round(region["w"] * params["expandRatio"]))
    my := Max(params["expandMinY"], Round(region["h"] * params["expandRatio"]))
    x := region["x"] - mx
    y := region["y"] - my
    w := region["w"] + mx * 2
    h := region["h"] + my * 2
    if IsObject(client) {
        left := client["x"]
        top := client["y"]
        right := client["x"] + client["w"]
        bottom := client["y"] + client["h"]
        x2 := Min(right, x + w)
        y2 := Min(bottom, y + h)
        x := Max(left, x)
        y := Max(top, y)
        w := Max(1, x2 - x)
        h := Max(1, y2 - y)
    } else {
        x2 := Min(A_ScreenWidth, x + w)
        y2 := Min(A_ScreenHeight, y + h)
        x := Max(0, x)
        y := Max(0, y)
        w := Max(1, x2 - x)
        h := Max(1, y2 - y)
    }
    out := Map("x", x, "y", y, "w", w, "h", h)
    if IsObject(client) {
        out["client"] := client
    }
    return out
}

ParseAutoPresetRegionByKey(configKey) {
    raw := Trim(LoadConfig(configKey, " "))
    out := Map()
    if (raw = "" || raw = " ") {
        return out
    }
    parts := StrSplit(raw, "|")
    if (parts.Length < 7 || parts[1] != "clientRatio") {
        return out
    }
    try {
        baseW := Integer(parts[2])
        baseH := Integer(parts[3])
        rx := parts[4] + 0
        ry := parts[5] + 0
        rw := parts[6] + 0
        rh := parts[7] + 0
    } catch {
        return out
    }
    if (baseW < 1 || baseH < 1 || rw <= 0 || rh <= 0) {
        return out
    }
    out["mode"] := "clientRatio"
    out["baseW"] := baseW
    out["baseH"] := baseH
    out["rx"] := rx
    out["ry"] := ry
    out["rw"] := rw
    out["rh"] := rh
    out["w"] := Max(1, Round(rw * baseW))
    out["h"] := Max(1, Round(rh * baseH))
    return out
}

SaveAutoPresetRegionByKey(configKey, x, y, w, h) {
    client := AutoPresets_GetGameClientRect()
    if !IsObject(client) {
        throw Error("未找到 DNF 游戏窗口，无法保存客户区相对识别区域。")
    }
    rx := (x - client["x"]) / client["w"]
    ry := (y - client["y"]) / client["h"]
    rw := w / client["w"]
    rh := h / client["h"]
    SaveConfig(configKey, "clientRatio|" client["w"] "|" client["h"] "|"
        Round(rx, 6) "|" Round(ry, 6) "|" Round(rw, 6) "|" Round(rh, 6))
}

ParseAutoPresetChatRegion() {
    return ParseAutoPresetRegionByKey("AutoPresetChatRegion")
}

SaveAutoPresetChatRegion(x, y, w, h) {
    SaveAutoPresetRegionByKey("AutoPresetChatRegion", x, y, w, h)
}

AutoPresets_GameActive() {
    return WinActive("ahk_group DNF") != 0
}

AutoPresets_IsSessionRunning() {
    global _AutoFireThreads
    try n := _AutoFireThreads.Length
    catch {
        n := 0
    }
    return n > 0
}

ParseAutoPresetRegion() {
    return ParseAutoPresetRegionByKey("AutoPresetRegion")
}

SaveAutoPresetRegion(x, y, w, h) {
    SaveAutoPresetRegionByKey("AutoPresetRegion", x, y, w, h)
}

AutoPresets_RegionCornerRadius(w, h) {
    return Max(0, Min(AutoPresets.RegionCornerRadius, w // 2, h // 2))
}

AutoPresets_ImageSearchPrefix(variation) {
    return "*" variation " *Trans" AutoPresets.RegionMaskRgb " "
}

AutoPresets_GetImageSize(path, &w, &h) {
    w := 0
    h := 0
    if !FileExist(path) {
        return false
    }
    _AutoPresetsGdipStartup()
    pBitmap := 0
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", path, "ptr*", &pBitmap := 0) != 0 || !pBitmap {
        return false
    }
    try {
        DllCall("gdiplus\GdipGetImageWidth", "ptr", pBitmap, "uint*", &w := 0)
        DllCall("gdiplus\GdipGetImageHeight", "ptr", pBitmap, "uint*", &h := 0)
        return w > 0 && h > 0
    } finally {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    }
}

AutoPresets_FitSearchToNeedle(x1, y1, x2, y2, needleW, needleH, client := "") {
    needW := Max(1, needleW)
    needH := Max(1, needleH)
    curW := x2 - x1 + 1
    curH := y2 - y1 + 1
    if (curW < needW) {
        extra := needW - curW
        x1 -= extra // 2
        x2 := x1 + needW - 1
    }
    if (curH < needH) {
        extra := needH - curH
        y1 -= extra // 2
        y2 := y1 + needH - 1
    }
    if IsObject(client) {
        left := client["x"]
        top := client["y"]
        right := client["x"] + client["w"] - 1
        bottom := client["y"] + client["h"] - 1
        if (x2 - x1 + 1 > client["w"]) {
            x1 := left
            x2 := right
        } else {
            if (x1 < left) {
                x2 += left - x1
                x1 := left
            }
            if (x2 > right) {
                x1 -= x2 - right
                x2 := right
                if (x1 < left) {
                    x1 := left
                }
            }
        }
        if (y2 - y1 + 1 > client["h"]) {
            y1 := top
            y2 := bottom
        } else {
            if (y1 < top) {
                y2 += top - y1
                y1 := top
            }
            if (y2 > bottom) {
                y1 -= y2 - bottom
                y2 := bottom
                if (y1 < top) {
                    y1 := top
                }
            }
        }
    }
    return Map("x1", x1, "y1", y1, "x2", x2, "y2", y2)
}

AutoPresets_ImageSearchInRegion(path, region, variation) {
    if !FileExist(path) || !IsObject(region) {
        return false
    }
    x1 := region["x"]
    y1 := region["y"]
    x2 := x1 + region["w"] - 1
    y2 := y1 + region["h"] - 1
    needle := AutoPresets_ImageSearchPrefix(variation) . path
    try {
        if ImageSearch(&_icx, &_icy, x1, y1, x2, y2, needle) {
            return true
        }
        return false
    } catch TargetError {
        if !AutoPresets_GetImageSize(path, &iw, &ih) {
            return false
        }
        client := region.Has("client") ? region["client"] : ""
        fitted := AutoPresets_FitSearchToNeedle(x1, y1, x2, y2, iw, ih, client)
        try {
            return ImageSearch(&_icx, &_icy, fitted["x1"], fitted["y1"], fitted["x2"], fitted["y2"], needle)
        } catch TargetError {
            return false
        }
    }
}

AutoPresets_ScaledNeedleDir() {
    return A_Temp "\DAF_ap_needles"
}

AutoPresets_ClearScaledNeedleCache() {
    AutoPresets._scaledNeedleCache := Map()
    AutoPresets._scaledNeedleSeq := 0
    dir := AutoPresets_ScaledNeedleDir()
    if DirExist(dir) {
        try DirDelete(dir, true)
    }
}

AutoPresets_ScaleImageToFile(srcPath, destPath, newW, newH, interpMode := 7) {
    if !FileExist(srcPath) || newW < 1 || newH < 1 {
        return false
    }
    parentDir := RegExReplace(destPath, "\\[^\\]+$", "")
    if (parentDir != "" && parentDir != destPath && !DirExist(parentDir)) {
        DirCreate(parentDir)
    }
    _AutoPresetsGdipStartup()
    pSrc := 0
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", srcPath, "ptr*", &pSrc := 0) != 0 || !pSrc {
        return false
    }
    pDst := 0
    if DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", newW, "int", newH, "int", newW * 4, "int", GdipUiHelpers.PixelFormat32bppARGB, "ptr", 0, "ptr*", &pDst := 0) != 0 || !pDst {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pSrc)
        return false
    }
    gr := 0
    ok := false
    try {
        if DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pDst, "ptr*", &gr := 0) != 0 || !gr {
            return false
        }
        DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", 0xFFFFFFFF)
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", interpMode)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gr, "int", 4)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gr, "int", 4)
        if DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", pSrc, "int", 0, "int", 0, "int", newW, "int", newH) != 0 {
            return false
        }
        _AutoPresetsGdipSaveGpBitmapToPng(pDst, destPath)
        ok := FileExist(destPath)
    } finally {
        if gr {
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
        }
        DllCall("gdiplus\GdipDisposeImage", "ptr", pDst)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pSrc)
    }
    return ok
}

AutoPresets_AddNeedleSize(list, seen, w, h) {
    w := Max(1, Round(w))
    h := Max(1, Round(h))
    k := w "x" h
    if seen.Has(k) {
        return
    }
    seen[k] := true
    list.Push(Map("w", w, "h", h))
}

AutoPresets_NeedleSizeCandidates(iw, ih, sw, sh, cw, ch) {
    tw := Max(1, Round(iw * cw / sw))
    th := Max(1, Round(ih * ch / sh))
    out := []
    seen := Map()
    AutoPresets_AddNeedleSize(out, seen, tw, th)
    jitter := AutoPresets_MatchParams()["jitterPx"]
    loop jitter {
        d := A_Index
        AutoPresets_AddNeedleSize(out, seen, tw - d, th - d)
        AutoPresets_AddNeedleSize(out, seen, tw + d, th + d)
    }
    return out
}

AutoPresets_CachedScaledNeedle(srcPath, tw, th, interpMode) {
    cacheKey := srcPath "`t" tw "x" th "`t" interpMode
    if AutoPresets._scaledNeedleCache.Has(cacheKey) {
        cached := AutoPresets._scaledNeedleCache[cacheKey]
        if FileExist(cached) {
            return cached
        }
    }
    AutoPresets._scaledNeedleSeq += 1
    dest := AutoPresets_ScaledNeedleDir() "\n" AutoPresets._scaledNeedleSeq "_" tw "x" th "_i" interpMode ".png"
    try {
        if !AutoPresets_ScaleImageToFile(srcPath, dest, tw, th, interpMode) {
            return ""
        }
    } catch {
        return ""
    }
    AutoPresets._scaledNeedleCache[cacheKey] := dest
    return dest
}

AutoPresets_PrepareNeedles(srcPath, srcResKey, curResKey) {
    needles := []
    if !FileExist(srcPath) {
        return needles
    }
    if (srcResKey = curResKey) {
        needles.Push(srcPath)
        return needles
    }
    params := AutoPresets_MatchParams()
    if (params["nearExclusive"] && AutoPresets_ResolutionDistance(srcResKey, curResKey) <= params["nearPx"]) {
        needles.Push(srcPath)
        return needles
    }
    if !AutoPresets_ParseResolutionKey(srcResKey, &sw, &sh) || !AutoPresets_ParseResolutionKey(curResKey, &cw, &ch) {
        needles.Push(srcPath)
        return needles
    }
    if !AutoPresets_GetImageSize(srcPath, &iw, &ih) {
        return needles
    }
    sizes := AutoPresets_NeedleSizeCandidates(iw, ih, sw, sh, cw, ch)
    if (sizes.Length = 0) {
        return needles
    }
    primaryW := sizes[1]["w"]
    primaryH := sizes[1]["h"]
    for sz in sizes {
        tw := sz["w"]
        th := sz["h"]
        if (tw = iw && th = ih) {
            needles.Push(srcPath)
            continue
        }
        dest := AutoPresets_CachedScaledNeedle(srcPath, tw, th, AutoPresets.ScaleInterpBicubic)
        if (dest != "") {
            needles.Push(dest)
        }
        if (params["useNearest"] && tw = primaryW && th = primaryH) {
            nn := AutoPresets_CachedScaledNeedle(srcPath, tw, th, AutoPresets.ScaleInterpNearest)
            if (nn != "" && nn != dest) {
                needles.Push(nn)
            }
        }
    }
    return needles
}

AutoPresets_SearchPresetsWithKeys(resKeys, curKey, region, variation, scaleNeedles) {
    for presetName in LoadAllPreset() {
        for resKey in resKeys {
            for item in AutoPresetsSkillIcons_Load(presetName, resKey) {
                path := item["path"]
                if !FileExist(path) {
                    continue
                }
                if scaleNeedles {
                    needles := AutoPresets_PrepareNeedles(path, resKey, curKey)
                    for needlePath in needles {
                        if AutoPresets_ImageSearchInRegion(needlePath, region, variation) {
                            return presetName
                        }
                    }
                } else if AutoPresets_ImageSearchInRegion(path, region, variation) {
                    return presetName
                }
            }
        }
    }
    return ""
}

AutoPresetsCaptureRegionToPng(path, x, y, w, h) {
    parentDir := RegExReplace(path, "\\[^\\]+$", "")
    if (parentDir != "" && parentDir != path && !DirExist(parentDir)) {
        DirCreate(parentDir)
    }
    hdc := DllCall("user32\GetDC", "ptr", 0, "ptr")
    if !hdc {
        throw Error("GetDC failed")
    }
    hdcMem := 0
    hbm := 0
    obm := 0
    selected := false
    try {
        hdcMem := DllCall("gdi32\CreateCompatibleDC", "ptr", hdc, "ptr")
        if !hdcMem {
            throw Error("CreateCompatibleDC failed")
        }
        hbm := DllCall("gdi32\CreateCompatibleBitmap", "ptr", hdc, "int", w, "int", h, "ptr")
        if !hbm {
            throw Error("CreateCompatibleBitmap failed")
        }
        obm := DllCall("gdi32\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
        if !obm {
            throw Error("SelectObject failed")
        }
        selected := true
        try {
            if !DllCall("gdi32\BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h,
                "ptr", hdc, "int", x, "int", y, "uint", 0x00CC0020) {
                throw Error("BitBlt failed")
            }
            _AutoPresetsGdipSaveHbitmapPng(hbm, path, AutoPresets_RegionCornerRadius(w, h))
        } finally {
            if selected {
                try DllCall("gdi32\SelectObject", "ptr", hdcMem, "ptr", obm, "ptr")
                selected := false
            }
        }
    } finally {
        if hbm {
            DllCall("gdi32\DeleteObject", "ptr", hbm)
        }
        if hdcMem {
            DllCall("gdi32\DeleteDC", "ptr", hdcMem)
        }
        DllCall("user32\ReleaseDC", "ptr", 0, "ptr", hdc)
    }
}

_AutoPresetsGdipStartup() {
    return GdiPlusSession.EnsureStarted()
}

_AutoPresetsGdipSaveHbitmapPng(hbm, path, radius := 0) {
    _AutoPresetsGdipStartup()
    pBitmap := 0
    if DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "int", 0, "ptr*", &pBitmap := 0) != 0 || !pBitmap {
        throw Error("GdipCreateBitmapFromHBITMAP failed")
    }
    try {
        if (radius > 0) {
            rounded := _AutoPresetsGdipCreateRoundedBitmap(pBitmap, radius)
            try _AutoPresetsGdipSaveGpBitmapToPng(rounded, path)
            finally DllCall("gdiplus\GdipDisposeImage", "ptr", rounded)
        } else {
            _AutoPresetsGdipSaveGpBitmapToPng(pBitmap, path)
        }
    } finally {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    }
}

_AutoPresetsGdipCreateRoundedBitmap(pSrc, radius) {
    sw := 0
    sh := 0
    DllCall("gdiplus\GdipGetImageWidth", "ptr", pSrc, "uint*", &sw := 0)
    DllCall("gdiplus\GdipGetImageHeight", "ptr", pSrc, "uint*", &sh := 0)
    if (sw < 1 || sh < 1) {
        throw Error("GdipGetImageSize failed")
    }
    stride := sw * 4
    pDst := 0
    if DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", sw, "int", sh, "int", stride, "int", GdipUiHelpers.PixelFormat32bppARGB, "ptr", 0, "ptr*", &pDst := 0) != 0 || !pDst {
        throw Error("GdipCreateBitmapFromScan0 failed")
    }
    gr := 0
    pPath := 0
    try {
        if DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pDst, "ptr*", &gr := 0) != 0 || !gr {
            throw Error("GdipGetImageGraphicsContext failed")
        }
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gr, "int", 3)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gr, "int", 3)
        DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", 0xFFFFFFFF)
        if DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath := 0) != 0 || !pPath {
            throw Error("GdipCreatePath failed")
        }
        GdipUiHelpers.AddPathRoundedRect(pPath, 0, 0, sw, sh, radius)
        if DllCall("gdiplus\GdipSetClipPath", "ptr", gr, "ptr", pPath, "int", 0) != 0 {
            throw Error("GdipSetClipPath failed")
        }
        if DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", pSrc, "int", 0, "int", 0, "int", sw, "int", sh) != 0 {
            throw Error("GdipDrawImageRectI failed")
        }
        return pDst
    } catch Error as e {
        if pDst {
            DllCall("gdiplus\GdipDisposeImage", "ptr", pDst)
        }
        throw e
    } finally {
        if pPath {
            DllCall("gdiplus\GdipDeletePath", "ptr", pPath)
        }
        if gr {
            DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
        }
    }
}

_AutoPresetsGdipSaveGpBitmapToPng(pBitmap, path) {
    _AutoPresetsGdipStartup()
    clsid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid) != 0 {
        throw Error("CLSIDFromString failed")
    }
    wpath := Buffer(2 * StrLen(path) + 2, 0)
    StrPut(path, wpath, "UTF-16")
    if DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "ptr", wpath.Ptr, "ptr", clsid, "ptr", 0) != 0 {
        throw Error("GdipSaveImageToFile failed")
    }
}

AutoPresetsSkillIcon_FitPreviewTempPath() {
    return A_Temp "\DAF_skill_fit_preview.png"
}

AutoPresetsSkillIcon_RenderFitPreviewToFile(srcPath, boxW, boxH, destPath) {
    if !FileExist(srcPath) || boxW < 1 || boxH < 1 {
        return false
    }
    _AutoPresetsGdipStartup()
    pSrc := 0
    if DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", srcPath, "ptr*", &pSrc := 0) != 0 || !pSrc {
        return false
    }
    sw := 0
    sh := 0
    DllCall("gdiplus\GdipGetImageWidth", "ptr", pSrc, "uint*", &sw := 0)
    DllCall("gdiplus\GdipGetImageHeight", "ptr", pSrc, "uint*", &sh := 0)
    if (sw < 1 || sh < 1) {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pSrc)
        return false
    }
    fmtArgb := 0x26200A
    stride := boxW * 4
    buf := Buffer(stride * boxH, 0)
    pDst := 0
    if DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", boxW, "int", boxH, "int", stride, "uint", fmtArgb, "ptr", buf.Ptr, "ptr*", &pDst := 0) != 0 || !pDst {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pSrc)
        return false
    }
    gr := 0
    if DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pDst, "ptr*", &gr := 0) != 0 || !gr {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pDst)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pSrc)
        return false
    }
    drawOk := false
    try {
        stClear := DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", 0xFFFFFFFF)
        stMode := DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gr, "int", 7)
        if (stClear = 0 && stMode = 0) {
            scale := Min(boxW / sw, boxH / sh)
            newW := Max(1, Round(sw * scale))
            newH := Max(1, Round(sh * scale))
            dstX := (boxW - newW) // 2
            dstY := (boxH - newH) // 2
            drawOk := (DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", pSrc, "int", dstX, "int", dstY, "int", newW, "int", newH) = 0)
        }
    } finally {
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
    }
    if !drawOk {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pDst)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pSrc)
        return false
    }
    try {
        _AutoPresetsGdipSaveGpBitmapToPng(pDst, destPath)
    } finally {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pDst)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pSrc)
    }
    return true
}

AutoPresetsChatIcon_UpdateForResolution(resolutionKey) {
    key := AutoPresetsSkillResolutionKey(resolutionKey)
    if (key = "") {
        throw Error("当前没有选中的分辨率。")
    }
    stored := ParseAutoPresetChatRegion()
    if (IsObject(stored) && stored.Has("mode") && stored["mode"] = "clientRatio") {
        r := AutoPresets_ResolveRegion(stored)
    } else {
        r := AutoPresets_DefaultChatRegion()
        SaveAutoPresetChatRegion(r["x"], r["y"], r["w"], r["h"])
    }
    path := AutoPresetsChatIconPathForResolution(key)
    AutoPresetsCaptureRegionToPng(path, r["x"], r["y"], r["w"], r["h"])
    return path
}

AutoPresets_PngPathsMatchRegion(paths, region, variation) {
    client := AutoPresets_GetGameClientRect()
    if !IsObject(client) {
        return false
    }
    curKey := AutoPresetsResolutionKey(client)
    r := AutoPresets_ResolveRegion(region, true)
    if (paths.Length = 0) {
        return false
    }
    keys := []
    pathByKey := Map()
    for path in paths {
        key := AutoPresets_PngResolutionKey(path)
        if (key = "" || pathByKey.Has(key)) {
            continue
        }
        keys.Push(key)
        pathByKey[key] := path
    }
    split := AutoPresets_SplitNearFarResolutionKeys(keys, curKey)
    prevPixel := CoordMode("Pixel", "Screen")
    try {
        for key in split["near"] {
            if AutoPresets_ImageSearchInRegion(pathByKey[key], r, variation) {
                return true
            }
        }
        scaledVar := variation + AutoPresets_MatchParams()["scaledExtra"]
        for key in AutoPresets_SortResolutionKeys(keys, curKey) {
            needles := AutoPresets_PrepareNeedles(pathByKey[key], key, curKey)
            for needle in needles {
                if (needle != "" && AutoPresets_ImageSearchInRegion(needle, r, scaledVar)) {
                    return true
                }
            }
        }
        return false
    } finally {
        CoordMode("Pixel", prevPixel)
    }
}

AutoPresetsChatIconMatches() {
    stored := ParseAutoPresetChatRegion()
    if !IsObject(stored) || !stored.Has("mode") || stored["mode"] != "clientRatio" {
        return false
    }
    return AutoPresets_PngPathsMatchRegion(AutoPresetsChatIconPaths(), stored, AutoPresets.ChatImageVariation)
}

AutoPresetsSkillIcon_UpdateForPreset(presetName, skillId := "", resolutionKey := false) {
    name := Trim(presetName)
    if (name = "") {
        throw Error("当前没有选中的配置。")
    }
    skillId := Trim(skillId)
    if (skillId = "") {
        return AutoPresetsSkillIcon_Add(name, resolutionKey)
    }
    path := AutoPresetsSkillIconPathForId(name, skillId, resolutionKey)
    if (path = "") {
        throw Error("当前没有选中的分辨率。")
    }
    r := AutoPresets_ResolveRegion(ParseAutoPresetRegion())
    AutoPresetsCaptureRegionToPng(path, r["x"], r["y"], r["w"], r["h"])
    return path
}

AutoPresetsFindPresetBySkillIcon() {
    client := AutoPresets_GetGameClientRect()
    if !IsObject(client) {
        return ""
    }
    curKey := AutoPresetsResolutionKey(client)
    r := AutoPresets_ResolveRegion(ParseAutoPresetRegion(), true)
    keys := AutoPresets_SortResolutionKeys(AutoPresets_ListSkillResolutionKeys(), curKey)
    if (keys.Length = 0) {
        return ""
    }
    params := AutoPresets_MatchParams()
    prevPixel := CoordMode("Pixel", "Screen")
    try {
        split := AutoPresets_SplitNearFarResolutionKeys(keys, curKey)
        if params["nearExclusive"] {
            if (split["near"].Length > 0) {
                return AutoPresets_SearchPresetsWithKeys(split["near"], curKey, r, params["variation"], false)
            }
            if (split["far"].Length > 0) {
                return AutoPresets_SearchPresetsWithKeys(split["far"], curKey, r, params["variation"] + params["scaledExtra"], true)
            }
            return ""
        }
        found := AutoPresets_SearchPresetsWithKeys(keys, curKey, r, params["variation"], false)
        if (found != "") {
            return found
        }
        return AutoPresets_SearchPresetsWithKeys(keys, curKey, r, params["variation"] + params["scaledExtra"], true)
    } finally {
        CoordMode("Pixel", prevPixel)
    }
}

AutoPresets_ClearSkillTimer() {
    if AutoPresets._skillTimer {
        try SetTimer(AutoPresets._skillTimer, 0)
        AutoPresets._skillTimer := false
    }
}

AutoPresets_StopSkillWatch() {
    AutoPresets_ClearSkillTimer()
    AutoPresets._fastUntilTick := 0
}

AutoPresets_ArmSkillTimer(delayMs) {
    AutoPresets_ClearSkillTimer()
    fn := AutoPresets_SkillTick
    AutoPresets._skillTimer := fn
    SetTimer(fn, -delayMs)
}

AutoPresets_RefreshSessionRuntime() {
    if !AutoPresets_IsSessionRunning() {
        return
    }
    AutoPresets_RegisterSessionHotkeys()
    if !AutoPresets_LoadEnabledGlobal() {
        AutoPresets_StopSkillWatch()
    }
}

AutoPresets_ClearChatTimer() {
    if AutoPresets._chatTimer {
        try SetTimer(AutoPresets._chatTimer, 0)
        AutoPresets._chatTimer := false
    }
}

AutoPresets_ResetChatWatch() {
    AutoPresets._chatHitStreak := 0
    AutoPresets._chatMissStreak := 0
    ChatOpen_SetOpen(false)
}

AutoPresets_StartChatWatch() {
    AutoPresets_ClearChatTimer()
    AutoPresets_ResetChatWatch()
    if !AutoPresets_IsSessionRunning() {
        return
    }
    if !AutoPresets_HasAnyChatPng() {
        return
    }
    fn := AutoPresets_ChatTick
    AutoPresets._chatTimer := fn
    SetTimer(fn, AutoPresets.ChatIntervalMs)
}

AutoPresets_ChatTick(*) {
    if !AutoPresets_IsSessionRunning() {
        AutoPresets_ClearChatTimer()
        ChatOpen_SetOpen(false)
        return
    }
    if !AutoPresets_GameActive() {
        return
    }
    try {
        matched := AutoPresetsChatIconMatches()
    } catch {
        return
    }
    if matched {
        AutoPresets._chatHitStreak += 1
        AutoPresets._chatMissStreak := 0
        if (AutoPresets._chatHitStreak >= AutoPresets.ChatOpenConfirmTicks) {
            ChatOpen_SetOpen(true)
        }
        return
    }
    AutoPresets._chatHitStreak := 0
    AutoPresets._chatMissStreak += 1
    if (AutoPresets._chatMissStreak >= AutoPresets.ChatCloseConfirmTicks) {
        ChatOpen_SetOpen(false)
    }
}

AutoPresets_CurrentSessionId() {
    return AutoPresets._sessionId
}

AutoPresets_Trigger(*) {
    AutoPresets_Request(true)
}

AutoPresets_Request(requireActive := false) {
    if !AutoPresets_LoadEnabledGlobal() {
        return
    }
    if !AutoPresets_IsSessionRunning() {
        return
    }
    if (requireActive && !AutoPresets_GameActive()) {
        return
    }
    AutoPresets._fastUntilTick := A_TickCount + AutoPresets_LoadRecognizeDurationMs()
    ShowTip(AutoPresetsText["Recognizing"])
    AutoPresets_ArmSkillTimer(AutoPresets.StartDelayMs)
}

AutoPresets_HotIfShouldFire(*) {
    if !AutoPresets_LoadEnabledGlobal() {
        return false
    }
    if !AutoPresets_IsSessionRunning() {
        return false
    }
    return WinActive("ahk_group DNF") != 0
}

AutoPresets_SkillTick(*) {
    sessionId := AutoPresets_CurrentSessionId()
    if !AutoPresets_LoadEnabledGlobal() || !AutoPresets_IsSessionRunning() {
        AutoPresets_StopSkillWatch()
        return
    }
    if (AutoPresets._fastUntilTick <= 0 || A_TickCount >= AutoPresets._fastUntilTick) {
        AutoPresets_StopSkillWatch()
        return
    }
    if AutoPresets_GameActive() {
        try {
            found := AutoPresetsFindPresetBySkillIcon()
            current := GetNowSelectPreset()
            if (found != "" && found != current) {
                AutoPresets_ApplySwitchOnMain(found)
                if (sessionId != AutoPresets_CurrentSessionId()) {
                    return
                }
            }
        } catch {
        }
    }
    if (sessionId != AutoPresets_CurrentSessionId()) {
        return
    }
    if !AutoPresets_LoadEnabledGlobal() || !AutoPresets_IsSessionRunning() {
        AutoPresets_StopSkillWatch()
        return
    }
    if (AutoPresets._fastUntilTick <= 0 || A_TickCount >= AutoPresets._fastUntilTick) {
        AutoPresets_StopSkillWatch()
        return
    }
    AutoPresets_ArmSkillTimer(AutoPresets.FastIntervalMs)
}

AutoPresets_ApplySwitchOnMain(presetName) {
    presetName := NormalizePresetName(presetName)
    if (presetName = "" || !PresetExists(presetName)) {
        return
    }
    cur := GetNowSelectPreset()
    if (cur = presetName) {
        return
    }
    StopAutoFire()
    EnterRunningMode(presetName)
    ShowTip("已切换到配置: " presetName)
}

AutoPresets_IsEscHotkeyStr(hk) {
    t := StrLower(Trim(hk))
    return (t = "esc" || t = "escape")
}

AutoPresets_DisableSessionHotkeys() {
    HotIf(AutoPresets_HotIfShouldFire)
    if AutoPresets._registeredEsc {
        try Hotkey("~Esc", "Off")
        AutoPresets._registeredEsc := false
    }
    if AutoPresets._registeredCustom && AutoPresets._lastCustomHotkey != "" {
        try Hotkey("~$" AutoPresets._lastCustomHotkey, "Off")
        AutoPresets._registeredCustom := false
        AutoPresets._lastCustomHotkey := ""
    }
    HotIf()
}

AutoPresets_RegisterSessionHotkeys() {
    AutoPresets_DisableSessionHotkeys()
    if !AutoPresets_LoadEnabledGlobal() {
        return
    }
    if !AutoPresets_IsSessionRunning() {
        return
    }
    hk := Trim(LoadConfig("AutoPresetHotkey", " "))
    if (hk = " ") {
        hk := ""
    }
    HotIf(AutoPresets_HotIfShouldFire)
    try {
        Hotkey("~Esc", AutoPresets_Trigger, "On")
        AutoPresets._registeredEsc := true
    }
    if (hk != "" && !AutoPresets_IsEscHotkeyStr(hk)) {
        try {
            Hotkey("~$" hk, AutoPresets_Trigger, "On")
            AutoPresets._lastCustomHotkey := hk
            AutoPresets._registeredCustom := true
        }
    }
    HotIf()
}

AutoPresets_OnSessionStarted() {
    AutoPresets._sessionId += 1
    AutoPresets_StopSkillWatch()
    AutoPresets_ClearScaledNeedleCache()
    AutoPresets_RegisterSessionHotkeys()
    AutoPresets_StartChatWatch()
}

AutoPresets_OnSessionStopped() {
    AutoPresets._sessionId += 1
    AutoPresets_DisableSessionHotkeys()
    AutoPresets_StopSkillWatch()
    AutoPresets_ClearChatTimer()
    AutoPresets_ResetChatWatch()
    AutoPresets_ClearScaledNeedleCache()
}
