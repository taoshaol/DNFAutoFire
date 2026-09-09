#Requires AutoHotkey v2.0

; 多键并发：每个主键一个独立 INI 节，节名形如 `预设:职业名.MultiKey.编号`，从 1 起按顺序紧凑编号。
; 方案内字段：Trigger / FirstKey / Keys；Keys 用 `|` 分隔并发按键。主节另存 `MultiKeyCount`。
; 列举子节时同时扫 INI 文本、节名列表和 Count，避免 Windows INI 节列表截断后读空再保存把配置清掉。
; 主进程与子进程共用，勿依赖仅主进程才有的 GUI。
; 设了首按键时按下主键瞬间先发出该键，过全局连发间隔后其余并发键再开始（锁定键热键不可靠时由第一个并发拍兜底首发）。
; 首发按下保持跟随全局默认、收尾 2ms，确保游戏先收到首发；并发键的间隔与按下保持跟随主界面全局连发设置，忽略单键独立参数。
MultiKeyFirstKeyHoldMs() => AutoFire_DefaultKeyHoldMs()
MultiKeyFirstKeyLeadMs() => LoadAutoFireGlobalIntervalMs()

MultiKeyProfileChildPrefix(presetName) {
    return "预设:" NormalizePresetName(presetName) ".MultiKey."
}

MultiKeyProfileChildSection(presetName, idx) {
    return MultiKeyProfileChildPrefix(presetName) idx
}

MultiKeyRegExEscape(s) {
    out := ""
    loop parse String(s) {
        ch := A_LoopField
        out .= InStr("\.*?+[](){}^$|", ch) ? "\" ch : ch
    }
    return out
}

MultiKeyAddUniqueIndex(seen, indices, idx) {
    idx := Round(idx + 0)
    if (idx < 1 || seen.Has(idx)) {
        return
    }
    seen[idx] := true
    indices.Push(idx)
}

MultiKeySortIndices(indices) {
    loop indices.Length - 1 {
        i := A_Index + 1
        key := indices[i]
        j := i - 1
        while (j >= 1 && indices[j] > key) {
            indices[j + 1] := indices[j]
            j -= 1
        }
        indices[j + 1] := key
    }
    return indices
}

MultiKeyListProfileIndices(presetName) {
    indices := []
    seen := Map()
    presetName := NormalizePresetName(presetName)
    if (presetName = "") {
        return indices
    }
    path := ConfigIniPath()
    prefix := MultiKeyProfileChildPrefix(presetName)
    if FileExist(path) {
        text := ""
        try text := FileRead(path)
        catch {
            text := ""
        }
        if (text != "") {
            pos := 1
            needle := "\[" MultiKeyRegExEscape(prefix) "([1-9][0-9]*)\]"
            while pos := RegExMatch(text, needle, &m, pos) {
                MultiKeyAddUniqueIndex(seen, indices, m[1])
                pos += StrLen(m[0])
            }
        }
        sections := ""
        try sections := IniRead(path)
        catch {
            sections := ""
        }
        prefixLen := StrLen(prefix)
        for sec in StrSplit(sections, "`n", "`r") {
            sec := Trim(sec)
            if (SubStr(sec, 1, prefixLen) != prefix) {
                continue
            }
            tail := SubStr(sec, prefixLen + 1)
            if RegExMatch(tail, "^[1-9][0-9]*$") {
                MultiKeyAddUniqueIndex(seen, indices, tail)
            }
        }
    }
    rawCount := Trim(String(LoadPreset(presetName, "MultiKeyCount", "")))
    if (rawCount != "") {
        count := Round(rawCount + 0)
        loop count {
            MultiKeyAddUniqueIndex(seen, indices, A_Index)
        }
    }
    return MultiKeySortIndices(indices)
}

MultiKeyEnsureFirstKeyInKeys(keys, firstKey) {
    firstKey := ComboCanonMainKey(firstKey)
    out := MultiKeyCloneKeys(keys)
    if (firstKey = "") {
        return out
    }
    for existing in out {
        if (existing = firstKey) {
            return out
        }
    }
    out.Push(firstKey)
    return out
}

MultiKeyParseKeys(raw) {
    keys := []
    seen := Map()
    for part in StrSplit(String(raw), "|") {
        key := ComboCanonMainKey(part)
        if (key = "" || seen.Has(key)) {
            continue
        }
        seen[key] := true
        keys.Push(key)
    }
    return keys
}

MultiKeySerializeKeys(keys) {
    if !IsObject(keys) || keys.Length = 0 {
        return ""
    }
    out := ""
    loop keys.Length {
        if !keys.Has(A_Index) {
            continue
        }
        key := ComboCanonMainKey(keys[A_Index])
        if (key = "") {
            continue
        }
        out := (out = "") ? key : out "|" key
    }
    return out
}

MultiKeyReadProfileSection(path, section) {
    p := { trigger: "", firstKey: "", keys: [] }
    if !FileExist(path) {
        return p
    }
    trigger := ""
    firstKey := ""
    keysRaw := ""
    try trigger := IniRead(path, section, "Trigger", "")
    try firstKey := IniRead(path, section, "FirstKey", "")
    try keysRaw := IniRead(path, section, "Keys", "")
    p.trigger := ComboCanonMainKey(trigger)
    p.firstKey := ComboCanonMainKey(firstKey)
    p.keys := MultiKeyEnsureFirstKeyInKeys(MultiKeyParseKeys(keysRaw), p.firstKey)
    return p
}

MultiKeyLoadProfilesFromPreset(presetName) {
    profiles := []
    presetName := NormalizePresetName(presetName)
    if (presetName = "") {
        return profiles
    }
    path := ConfigIniPath()
    for idx in MultiKeyListProfileIndices(presetName) {
        profiles.Push(MultiKeyReadProfileSection(path, MultiKeyProfileChildSection(presetName, idx)))
    }
    return profiles
}

MultiKeySaveProfilesToPreset(presetName, profiles) {
    presetName := NormalizePresetName(presetName)
    if (presetName = "") {
        return
    }
    path := ConfigIniPath()
    for idx in MultiKeyListProfileIndices(presetName) {
        try IniDelete(path, MultiKeyProfileChildSection(presetName, idx))
    }
    written := 0
    if IsObject(profiles) {
        loop profiles.Length {
            if !profiles.Has(A_Index) {
                continue
            }
            p := profiles[A_Index]
            if !IsObject(p) {
                continue
            }
            written += 1
            section := MultiKeyProfileChildSection(presetName, written)
            trig := HasProp(p, "trigger") ? ComboCanonMainKey(p.trigger) : ""
            firstKey := HasProp(p, "firstKey") ? ComboCanonMainKey(p.firstKey) : ""
            keys := MultiKeyEnsureFirstKeyInKeys((HasProp(p, "keys") && IsObject(p.keys)) ? p.keys : [], firstKey)
            IniWrite(trig, path, section, "Trigger")
            IniWrite(firstKey, path, section, "FirstKey")
            IniWrite(MultiKeySerializeKeys(keys), path, section, "Keys")
        }
    }
    SavePreset(presetName, "MultiKeyCount", written)
}

MultiKeyCloneKeys(keys) {
    out := []
    if !IsObject(keys) {
        return out
    }
    loop keys.Length {
        if !keys.Has(A_Index) {
            continue
        }
        key := ComboCanonMainKey(keys[A_Index])
        if (key != "") {
            out.Push(key)
        }
    }
    return out
}
