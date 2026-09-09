; 全局主键连发间隔（毫秒），保存在 config.ini [设置]；供主界面与子进程复用
LoadAutoFireGlobalIntervalMs() {
    return ClampMsMin1(Round(LoadConfig("AutoFireIntervalMs", 20) + 0))
}

SaveAutoFireGlobalIntervalMs(intervalMs) {
    SaveConfig("AutoFireIntervalMs", ClampMsMin1(intervalMs))
}

ClampMsMin1(ms) {
    ms := Round(ms + 0)
    if (ms < 1) {
        ms := 1
    }
    return ms
}

; 普通连发与多键并发的默认按下保持（毫秒）
AutoFire_DefaultKeyHoldMs() => 8

ResolveKeyMs(guiKeyName, defaultMs, perMap, minMs := 0) {
    ms := defaultMs
    if (IsObject(perMap) && perMap.Has(guiKeyName)) {
        ms := perMap[guiKeyName]
    }
    ms := Round(ms + 0)
    if (ms < minMs) {
        ms := minMs
    }
    return ms
}

AutoFire_LoadRuntimeKeys(presetName) {
    keys := LoadPresetKeys(presetName)
    avoidPressKeys := AutoFire_LoadAvoidPressKeys(presetName)
    if (avoidPressKeys.Count = 0) {
        return keys
    }
    filteredKeys := []
    for key in keys {
        pressKey := AutoFire_KeyToPressKey(key)
        if (pressKey = "" || !avoidPressKeys.Has(pressKey)) {
            filteredKeys.Push(key)
        }
    }
    return filteredKeys
}

AutoFire_LoadAvoidPressKeys(presetName) {
    avoidPressKeys := Map()
    if LoadPreset(presetName, "XiuLuoState", false) {
        AutoFire_AddAvoidPressKey(avoidPressKeys, LoadPreset(presetName, "XiuLuoTriggerKey", ""))
    }
    if LoadPreset(presetName, "MultiKeyState", false) {
        for profile in MultiKeyLoadProfilesFromPreset(presetName) {
            if IsObject(profile) {
                AutoFire_AddAvoidPressKey(avoidPressKeys, profile.trigger)
            }
        }
    }
    ; 一键连招启用「屏蔽原键」的触发键也要避让主连发：原键已被连招屏蔽接管，
    ; 主连发若仍按物理按住补发该键，会在连招之外周期性插进触发键本身，看起来像屏蔽失效
    if LoadPreset(presetName, "ComboState", false) {
        for profile in ComboLoadProfilesFromPreset(presetName) {
            if (IsObject(profile) && HasProp(profile, "blockOriginal") && profile.blockOriginal) {
                AutoFire_AddAvoidPressKey(avoidPressKeys, profile.trigger)
            }
        }
    }
    return avoidPressKeys
}

AutoFire_AddAvoidPressKey(avoidPressKeys, key) {
    pressKey := AutoFire_KeyToPressKey(key)
    if (pressKey != "") {
        avoidPressKeys[pressKey] := true
    }
}

AutoFire_KeyToPressKey(key) {
    key := Trim(String(key))
    if (key = "") {
        return ""
    }
    pressKey := Key2PressKey(GetOriginKeyName(key))
    if (StrLen(pressKey) >= 4 && SubStr(pressKey, 1, 2) = "sc") {
        pressKey := Format("{:L}", pressKey)
    }
    return pressKey
}

AutoFire_IsLockPressKey(key, pressKey := "") {
    raw := StrLower(Trim(String(key)))
    pk := StrLower(Trim(String(pressKey)))
    if (raw = "capslock" || raw = "caps" || raw = "numlock" || raw = "numlk" || raw = "scrolllock" || raw = "scrlk") {
        return true
    }
    return pk = "capslock" || pk = "numlock" || pk = "scrolllock" || pk = "sc3a" || pk = "sc45" || pk = "sc46"
}

AutoFire_AddKeyJob(jobs, guiKeyName, defaultMs, perMap, delayMap, forceGlobal := false) {
    pressKey := AutoFire_KeyToPressKey(guiKeyName)
    if (pressKey = "") {
        return
    }
    if jobs.Has(pressKey) {
        if forceGlobal {
            jobs[pressKey].intervalMs := ClampMsMin1(defaultMs)
            jobs[pressKey].keyDelayMs := AutoFire_DefaultKeyHoldMs()
        }
        return
    }
    key := GetOriginKeyName(guiKeyName)
    keyCode := Key2NoVkSC(key)
    if (keyCode = "") {
        return
    }
    jobs[pressKey] := {
        guiKeyName: guiKeyName,
        pressKey: pressKey,
        keyCode: keyCode,
        intervalMs: forceGlobal ? ClampMsMin1(defaultMs) : ResolveKeyMs(guiKeyName, defaultMs, perMap, 1),
        keyDelayMs: forceGlobal ? AutoFire_DefaultKeyHoldMs() : ResolveKeyMs(guiKeyName, AutoFire_DefaultKeyHoldMs(), delayMap),
        virtualTriggers: []
    }
}

AutoFire_AttachVirtualTrigger(jobs, pressKey, triggerPressKey) {
    if (pressKey = "" || triggerPressKey = "" || !jobs.Has(pressKey)) {
        return
    }
    for existing in jobs[pressKey].virtualTriggers {
        if (existing = triggerPressKey) {
            return
        }
    }
    jobs[pressKey].virtualTriggers.Push(triggerPressKey)
}

AutoFire_BuildKeyJobs(presetName) {
    jobs := Map()
    defaultMs := LoadAutoFireGlobalIntervalMs()
    perMap := StrToMsMap(LoadPreset(presetName, "AutoFireKeyIntervals", ""))
    delayMap := StrToMsMap(LoadPreset(presetName, "AutoFireKeyDelays", ""))
    for guiKeyName in AutoFire_LoadRuntimeKeys(presetName) {
        AutoFire_AddKeyJob(jobs, guiKeyName, defaultMs, perMap, delayMap)
    }
    if LoadPreset(presetName, "MultiKeyState", false) {
        for profile in MultiKeyLoadProfilesFromPreset(presetName) {
            if !IsObject(profile) || !IsObject(profile.keys) {
                continue
            }
            triggerPress := AutoFire_KeyToPressKey(profile.trigger)
            originName := GetOriginKeyName(profile.trigger)
            if (triggerPress = "") {
                continue
            }
            for shotKey in profile.keys {
                AutoFire_AddKeyJob(jobs, shotKey, defaultMs, perMap, delayMap, true)
                shotPress := AutoFire_KeyToPressKey(shotKey)
                AutoFire_AttachVirtualTrigger(jobs, shotPress, triggerPress)
                if (originName != "" && originName != triggerPress) {
                    AutoFire_AttachVirtualTrigger(jobs, shotPress, originName)
                }
            }
        }
    }
    return jobs
}

AutoFire_HasKeyJobs(presetName) {
    return AutoFire_BuildKeyJobs(presetName).Count > 0
}

AutoFire_ArmKeyTimer(fn, intervalMs, offsetMs) {
    if (offsetMs <= 0) {
        SetTimer(fn, intervalMs)
        return fn
    }
    starter := AutoFire_ArmKeyTimerStart.Bind(fn, intervalMs)
    SetTimer(starter, -offsetMs)
    return starter
}

AutoFire_ArmKeyTimerStart(fn, intervalMs, *) {
    SetTimer(fn, intervalMs)
    fn()
}

AutoFire_MultiKeyBlockActive(*) {
    return WinActive("ahk_group DNF") && !GlobalPause_IsPaused() && !ChatOpen_IsOpen()
}

AutoFire_LoadMultiKeyTriggers(presetName) {
    global AutoFire_MK_Triggers
    AutoFire_MK_Triggers := Map()
    if !LoadPreset(presetName, "MultiKeyState", false) {
        return
    }
    for profile in MultiKeyLoadProfilesFromPreset(presetName) {
        if !IsObject(profile) {
            continue
        }
        triggerPress := AutoFire_KeyToPressKey(profile.trigger)
        scID := Key2SC(GetOriginKeyName(profile.trigger))
        if (triggerPress = "" || scID = "") {
            continue
        }
        firstKey := HasProp(profile, "firstKey") ? profile.firstKey : ""
        originName := GetOriginKeyName(profile.trigger)
        AutoFire_MK_Triggers[triggerPress] := {
            scID: scID,
            pressKey: triggerPress,
            originName: originName,
            lockHold: AutoFire_IsLockPressKey(profile.trigger, triggerPress),
            firstKey: ComboCanonMainKey(firstKey),
            hookHeld: false,
            leadDone: false,
            readyTick: 0
        }
    }
}

AutoFire_EnableMultiKeyBlocks() {
    global AutoFire_MK_Triggers, AutoFire_MK_HotkeyIds
    AutoFire_MK_HotkeyIds := []
    if !IsObject(AutoFire_MK_Triggers) {
        return
    }
    for triggerPress, info in AutoFire_MK_Triggers {
        scID := info.scID
        AutoFire_MK_HotkeyIds.Push(scID)
        HotIf(AutoFire_MultiKeyBlockActive)
        Hotkey("$" scID, AutoFire_MultiKeyDown.Bind(triggerPress), "On")
        HotIf()
        Hotkey("~$" scID " up", AutoFire_MultiKeyUp.Bind(triggerPress), "On")
    }
}

AutoFire_DisableMultiKeyBlocks() {
    global AutoFire_MK_HotkeyIds
    if !IsObject(AutoFire_MK_HotkeyIds) {
        return
    }
    for scID in AutoFire_MK_HotkeyIds {
        try {
            HotIf(AutoFire_MultiKeyBlockActive)
            try Hotkey("$" scID, "Off")
            HotIf()
            try Hotkey("~$" scID " up", "Off")
        } catch {
            try HotIf()
        }
    }
    AutoFire_MK_HotkeyIds := []
}

AutoFire_MultiKeyDown(triggerPress, *) {
    global AutoFire_MK_Triggers
    if !IsObject(AutoFire_MK_Triggers) || !AutoFire_MK_Triggers.Has(triggerPress) {
        return
    }
    info := AutoFire_MK_Triggers[triggerPress]
    info.hookHeld := true
    ; 按下主键瞬间立刻发出首按键；定时器在大全局间隔下第一拍可能晚到近一个间隔，不能等
    AutoFire_MultiKeyBeginLead(info)
}

AutoFire_MultiKeyUp(triggerPress, *) {
    global AutoFire_MK_Triggers
    if !IsObject(AutoFire_MK_Triggers) || !AutoFire_MK_Triggers.Has(triggerPress) {
        return
    }
    info := AutoFire_MK_Triggers[triggerPress]
    if (!info.lockHold && GetKeyState(info.pressKey, "P")) {
        return
    }
    info.hookHeld := false
    AutoFire_MultiKeyResetLead(info)
}

; 首按键按下瞬间由主键热键直接发出，定时器路径仅在热键不可靠时（锁定键）兜底，二者用 leadDone 去重
; 首发后过全局连发间隔整组并发键再开始，保证游戏先收到首按键
AutoFire_MultiKeyBeginLead(info) {
    if (info.firstKey = "" || info.leadDone) {
        return
    }
    info.leadDone := true
    info.readyTick := A_TickCount + MultiKeyFirstKeyLeadMs()
    token := Key2NoVkSC(GetOriginKeyName(info.firstKey))
    if (token != "") {
        SendIP(token, MultiKeyFirstKeyHoldMs())
    }
}

AutoFire_MultiKeyResetLead(info) {
    info.leadDone := false
    info.readyTick := 0
}

AutoFire_MultiKeyGate(triggerPress) {
    global AutoFire_MK_Triggers
    if !IsObject(AutoFire_MK_Triggers) {
        return true
    }
    info := ""
    if AutoFire_MK_Triggers.Has(triggerPress) {
        info := AutoFire_MK_Triggers[triggerPress]
    } else {
        for _, t in AutoFire_MK_Triggers {
            if (HasProp(t, "originName") && t.originName = triggerPress) {
                info := t
                break
            }
        }
    }
    if !IsObject(info) {
        return true
    }
    if (info.firstKey = "") {
        return true
    }
    if !info.leadDone {
        AutoFire_MultiKeyBeginLead(info)
        return false
    }
    return A_TickCount >= info.readyTick
}

AutoFire_KeyPhysicallyDown(pressKey) {
    pressKey := Trim(String(pressKey))
    if (pressKey = "") {
        return false
    }
    if GetKeyState(pressKey, "P") {
        return true
    }
    global AutoFire_MK_Triggers
    if IsObject(AutoFire_MK_Triggers) && AutoFire_MK_Triggers.Has(pressKey) {
        info := AutoFire_MK_Triggers[pressKey]
        if (info.lockHold && info.hookHeld) {
            return true
        }
        originName := HasProp(info, "originName") ? info.originName : ""
        if (originName != "" && GetKeyState(originName, "P")) {
            return true
        }
        if info.hookHeld {
            return true
        }
    }
    return false
}

AutoFire_MultiKeyShouldFire(pressKey, virtualTriggers) {
    if !IsObject(virtualTriggers) || virtualTriggers.Length = 0 {
        return false
    }
    if GlobalPause_IsPaused() {
        return false
    }
    global AutoFire_MK_Triggers
    for triggerPress in virtualTriggers {
        if AutoFire_KeyPhysicallyDown(triggerPress) {
            return AutoFire_MultiKeyGate(triggerPress)
        }
    }
    if IsObject(AutoFire_MK_Triggers) {
        for triggerPress in virtualTriggers {
            if AutoFire_MK_Triggers.Has(triggerPress) {
                AutoFire_MultiKeyResetLead(AutoFire_MK_Triggers[triggerPress])
            }
        }
    }
    return false
}

; 单个专用子进程承载全部主键连发，并在同一进程里做多键并发：
; 屏蔽主键原键，绑定键按主连发同一套逐键定时补发。设了首按键时按下主键瞬间先发出首按键，过全局连发间隔后整组并发键再开始。
MainAutoFire(presetName := "") {
    ProcessSetPriority("High")
    RegisterGameWindowGroup()
    try InstallKeybdHook()
    try UnlockSystemTimeLimit()
    OnExit(MainAutoFire_OnExit)

    presetName := ResolvePresetName(presetName = "" ? LoadLastPreset() : presetName)
    AutoFire_LoadMultiKeyTriggers(presetName)
    AutoFire_EnableMultiKeyBlocks()
    ; 子进程引导阶段是挂起状态（Suspend(true)），注册完屏蔽热键后必须解除，否则热键全部不触发、主键原键直接漏进游戏；定时器不受挂起影响，所以连发/并发不受影响
    Suspend(false)
    jobs := AutoFire_BuildKeyJobs(presetName)
    timers := []
    jobList := []
    for pressKey, job in jobs {
        jobList.Push(job)
    }
    jobCount := jobList.Length
    loop jobCount {
        job := jobList[A_Index]
        fn := AutoFireSingleKeyTick.Bind(job.pressKey, job.keyCode, job.keyDelayMs, job.virtualTriggers)
        offsetMs := (jobCount > 1) ? Round((A_Index - 1) * job.intervalMs / jobCount) : 0
        timers.Push(fn)
        timers.Push(AutoFire_ArmKeyTimer(fn, job.intervalMs, offsetMs))
    }

    loop {
        Sleep(1000)
    }
}

MainAutoFire_OnExit(*) {
    AutoFire_DisableMultiKeyBlocks()
    try RestoreSystemTimeLimit()
}

AutoFireSingleKeyTick(pressKey, keyCode, keyDelayMs, virtualTriggers := "") {
    if !WinActive("ahk_group DNF") {
        return
    }
    static keyBusy := Map()
    if (keyBusy.Has(pressKey) && keyBusy[pressKey]) {
        return
    }
    keyBusy[pressKey] := true
    ; 物理按住的键若同时是多键并发主键（如触发键 D 也在本组 Keys 里），必须走并发门控决定本拍是否发送；
    ; 否则物理态短路会绕过首按键门控，出现并发键抢在首按键之前发出的反序现象
    global AutoFire_MK_Triggers
    isMkTrigger := IsObject(AutoFire_MK_Triggers) && AutoFire_MK_Triggers.Has(pressKey)
    canFire := (GetKeyState(pressKey, "P") && !isMkTrigger) || AutoFire_MultiKeyShouldFire(pressKey, virtualTriggers)
    try if canFire {
        SendIP(keyCode, keyDelayMs)
    }
    finally keyBusy[pressKey] := false
}
