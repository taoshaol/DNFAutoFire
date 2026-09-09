#Requires AutoHotkey v2.0

global gMultiKeyGui := Gui("-MinimizeBox -MaximizeBox")
global gMultiKeyCtrls := Map()
global __MultiKeyKeys := []
global __MultiKeyProfiles := []
global __MultiKeyProfileIndex := 1
global __MultiKeyProfileLoading := false
global gMultiKeyProfileDragCurrent := ""
global gMultiKeyLayout := ExLayout.Window()

UiApplyWindow(gMultiKeyGui)
gMultiKeyGui.OnEvent("Escape", MultiKeyGuiEscape)
gMultiKeyGui.OnEvent("Close", MultiKeyGuiClose)

contentRight := 592
profileColX := ExLayout.MarginLeft()
profileColW := 196
colGap := 16
keyColX := profileColX + profileColW + colGap
keyColW := contentRight - keyColX

firstEditW := 80
firstLabelW := 56
firstEditX := contentRight - firstEditW
firstLabelX := firstEditX - firstLabelW - 6
keyTitleW := firstLabelX - keyColX - 8

UiExPageTitle(gMultiKeyGui, exText["MultiKeyTitleLine"], contentRight, gMultiKeyLayout, MultiKeyHelp)

UiLabel(gMultiKeyGui, UiLayoutRect(gMultiKeyLayout, profileColX, 52, profileColW, 22, "+0x200"), exText["MultiKeyProfileList"])
UiListBox(gMultiKeyCtrls, gMultiKeyGui, "MultiKeyProfilesListBox", UiLayoutRect(gMultiKeyLayout, profileColX, 74, profileColW, 210), MultiKeyProfileListChange)
UiListBoxDragSort_Attach(gMultiKeyCtrls["MultiKeyProfilesListBox"], MultiKeyProfileDragGetItems, MultiKeyProfileDragRender, MultiKeyProfileDragCommit, MultiKeyProfileDragClick)
profileBtnRects := UiExSplitButtonRects(gMultiKeyLayout, profileColX, 292, profileColW, 8)
gMultiKeyCtrls["MultiKeyAddProfileButton"] := UiPlainButton(gMultiKeyGui, profileBtnRects[1], exText["MultiKeyAddProfile"], MultiKeyAddProfile)
UiPlainButton(gMultiKeyGui, profileBtnRects[2], exText["MultiKeyRemoveProfile"], MultiKeyRemoveProfile)

UiLabel(gMultiKeyGui, UiLayoutRect(gMultiKeyLayout, keyColX, 52, keyTitleW, 22, "+0x200"), exText["MultiKeyKeyList"])
UiLabel(gMultiKeyGui, UiLayoutRect(gMultiKeyLayout, firstLabelX, 52, firstLabelW, 22, "+0x200"), exText["MultiKeyFirstKey"])
UiPressKeyEdit(gMultiKeyCtrls, gMultiKeyGui, "MultiKeyFirstKey", UiLayoutRect(gMultiKeyLayout, firstEditX, 50, firstEditW, 24), MultiKeyCanonFirstKeyCaptured)
UiListBox(gMultiKeyCtrls, gMultiKeyGui, "MultiKeyKeysListBox", UiLayoutRect(gMultiKeyLayout, keyColX, 74, keyColW, 210))
UiListBoxDragSort_Attach(gMultiKeyCtrls["MultiKeyKeysListBox"], MultiKeyKeyDragGetItems, UiListBoxDragSort_RenderStrings, MultiKeyKeyDragCommit)
keyActionRects := UiExSplitButtonRects(gMultiKeyLayout, keyColX, 292, keyColW, 8)
gMultiKeyCtrls["MultiKeyAddKeyButton"] := UiPlainButton(gMultiKeyGui, keyActionRects[1], exText["MultiKeyAddKey"], MultiKeyAddKey)
UiPlainButton(gMultiKeyGui, keyActionRects[2], exText["MultiKeyDeleteKey"], MultiKeyDeleteKey)

UiPlainButton(gMultiKeyGui, UiExSaveButtonRect(gMultiKeyLayout, 330, contentRight), exText["MultiKeySaveClose"], MultiKeySaveAndClose, "primary")

MultiKeyGetCtrl(name) {
    global gMultiKeyCtrls
    return gMultiKeyCtrls.Has(name) ? gMultiKeyCtrls[name] : ""
}

ShowGuiMultiKey(*) {
    global gMainGui, gMultiKeyGui, gMultiKeyLayout
    if IsObject(gMainGui) {
        gMultiKeyGui.Opt("+Owner" gMainGui.Hwnd)
    }
    gMultiKeyGui.Title := exText["MultiKeyTitle"]
    gMultiKeyGui.Show("w" gMultiKeyLayout.Width() " h" gMultiKeyLayout.Height())
    MultiKeyLoadConfig()
    DisableGuiMain()
}

HideGuiMultiKey() {
    global gMultiKeyGui
    gMultiKeyGui.Hide()
    EnableGuiMain()
}

MultiKeyGuiEscape(*) {
    if !MultiKeySaveConfig() {
        return
    }
    HideGuiMultiKey()
}

MultiKeyGuiClose(*) {
    MultiKeyGuiEscape()
}

MultiKeyHelp(*) {
    UiHelpMsgBox(exText["MultiKeyHelp"], exText["MultiKeyHelpTitle"])
}

MultiKeyCanonFirstKeyCaptured(key) {
    key := ComboCanonMainKey(key)
    MultiKeyEnsureFirstKeyInEditor(key)
    return key
}

MultiKeyEnsureFirstKeyInEditor(key) {
    global __MultiKeyKeys
    key := ComboCanonMainKey(key)
    if (key = "") {
        return
    }
    __MultiKeyKeys := MultiKeyEnsureFirstKeyInKeys(__MultiKeyKeys, key)
    MultiKeyRefreshKeyList()
}

MultiKeyFirstKeyValue() {
    return ComboCanonMainKey(UiPressKeyEdit_Value(MultiKeyGetCtrl("MultiKeyFirstKey")))
}

MultiKeySetFirstKeyText(key) {
    ctrl := MultiKeyGetCtrl("MultiKeyFirstKey")
    if IsObject(ctrl) {
        ctrl.Text := ComboCanonMainKey(key)
    }
}

MultiKeyCaptureKey() {
    raw := GetPressKey(false)
    if (raw = "Escape") {
        return ""
    }
    return ComboCanonMainKey(raw)
}

MultiKeyProfileSummary(p) {
    if !IsObject(p) {
        return ""
    }
    t := Trim(String(p.trigger))
    if (t = "") {
        t := exText["MultiKeyUnsetTrigger"]
    }
    keys := IsObject(p.keys) ? p.keys : []
    return t " : " keys.Length exText["MultiKeyKeyCountSuffix"]
}

MultiKeyRefreshKeyList() {
    global __MultiKeyKeys
    ctrl := MultiKeyGetCtrl("MultiKeyKeysListBox")
    ctrl.Delete()
    count := 0
    loop __MultiKeyKeys.Length {
        if !__MultiKeyKeys.Has(A_Index) {
            continue
        }
        key := ComboCanonMainKey(__MultiKeyKeys[A_Index])
        if (key = "") {
            continue
        }
        ctrl.Add([key])
        count++
    }
    if (count > 0) {
        ctrl.Choose(count)
    }
}

MultiKeyFlushEditorToProfileAt(idx) {
    global __MultiKeyProfiles, __MultiKeyKeys
    if (idx < 1 || idx > __MultiKeyProfiles.Length || !__MultiKeyProfiles.Has(idx)) {
        return
    }
    p := __MultiKeyProfiles[idx]
    p.firstKey := MultiKeyFirstKeyValue()
    __MultiKeyKeys := MultiKeyEnsureFirstKeyInKeys(__MultiKeyKeys, p.firstKey)
    p.keys := MultiKeyCloneKeys(__MultiKeyKeys)
}

MultiKeyLoadProfileToEditor(idx) {
    global __MultiKeyProfiles, __MultiKeyKeys
    if (idx < 1 || idx > __MultiKeyProfiles.Length || !__MultiKeyProfiles.Has(idx)) {
        __MultiKeyKeys := []
        MultiKeyRefreshKeyList()
        MultiKeySetFirstKeyText("")
        return
    }
    p := __MultiKeyProfiles[idx]
    __MultiKeyKeys := MultiKeyEnsureFirstKeyInKeys(p.keys, HasProp(p, "firstKey") ? p.firstKey : "")
    MultiKeyRefreshKeyList()
    MultiKeySetFirstKeyText(HasProp(p, "firstKey") ? p.firstKey : "")
}

MultiKeyRefreshProfileList() {
    global __MultiKeyProfiles, __MultiKeyProfileIndex, __MultiKeyProfileLoading
    __MultiKeyProfileLoading := true
    try {
        ctrl := MultiKeyGetCtrl("MultiKeyProfilesListBox")
        ctrl.Delete()
        loop __MultiKeyProfiles.Length {
            if !__MultiKeyProfiles.Has(A_Index) {
                continue
            }
            ctrl.Add([MultiKeyProfileSummary(__MultiKeyProfiles[A_Index])])
        }
        if (__MultiKeyProfileIndex >= 1 && __MultiKeyProfileIndex <= __MultiKeyProfiles.Length) {
            ctrl.Choose(__MultiKeyProfileIndex)
        } else if (__MultiKeyProfiles.Length > 0) {
            ctrl.Choose(1)
        }
    } finally {
        __MultiKeyProfileLoading := false
    }
}

MultiKeySetProfileListBoxFromItems(ctrl, items, selectedIndex) {
    ctrl.Delete()
    if IsObject(items) {
        loop items.Length {
            if !items.Has(A_Index) {
                continue
            }
            ctrl.Add([MultiKeyProfileSummary(items[A_Index])])
        }
    }
    if (selectedIndex > 0) {
        try ctrl.Choose(selectedIndex)
    }
}

MultiKeyProfileDragGetItems(*) {
    global __MultiKeyProfiles, __MultiKeyProfileIndex, gMultiKeyProfileDragCurrent
    MultiKeyFlushEditorToProfileAt(__MultiKeyProfileIndex)
    gMultiKeyProfileDragCurrent := ""
    if (__MultiKeyProfileIndex >= 1 && __MultiKeyProfileIndex <= __MultiKeyProfiles.Length) {
        gMultiKeyProfileDragCurrent := __MultiKeyProfiles[__MultiKeyProfileIndex]
    }
    return UiListBoxDragSort_CopyArray(__MultiKeyProfiles)
}

MultiKeyProfileDragRender(ctrl, items, selectedIndex) {
    global __MultiKeyProfileLoading
    __MultiKeyProfileLoading := true
    try {
        MultiKeySetProfileListBoxFromItems(ctrl, items, selectedIndex)
    } finally {
        __MultiKeyProfileLoading := false
    }
}

MultiKeyProfileDragCommit(items, selectedIndex) {
    global __MultiKeyProfiles, __MultiKeyProfileIndex, gMultiKeyProfileDragCurrent
    __MultiKeyProfiles := items
    newCurrentIndex := 0
    if IsObject(gMultiKeyProfileDragCurrent) {
        loop __MultiKeyProfiles.Length {
            if __MultiKeyProfiles.Has(A_Index) && (__MultiKeyProfiles[A_Index] == gMultiKeyProfileDragCurrent) {
                newCurrentIndex := A_Index
                break
            }
        }
    }
    __MultiKeyProfileIndex := newCurrentIndex > 0 ? newCurrentIndex : selectedIndex
    MultiKeyRefreshProfileList()
    MultiKeyLoadProfileToEditor(__MultiKeyProfileIndex)
    gMultiKeyProfileDragCurrent := ""
}

MultiKeyProfileDragClick(ctrl) {
    MultiKeyProfileChangeToIndex(ctrl.Value)
}

MultiKeyProfileListChange(ctrl, *) {
    global __MultiKeyProfiles, __MultiKeyProfileIndex, __MultiKeyProfileLoading
    if __MultiKeyProfileLoading || UiListBoxDragSort_IsActive(ctrl) {
        return
    }
    MultiKeyProfileChangeToIndex(ctrl.Value)
}

MultiKeyProfileChangeToIndex(newIdx) {
    global __MultiKeyProfiles, __MultiKeyProfileIndex
    if (newIdx < 1 || newIdx > __MultiKeyProfiles.Length) {
        return
    }
    oldIdx := __MultiKeyProfileIndex
    if (oldIdx >= 1 && oldIdx <= __MultiKeyProfiles.Length && oldIdx != newIdx) {
        MultiKeyFlushEditorToProfileAt(oldIdx)
    }
    __MultiKeyProfileIndex := newIdx
    MultiKeyLoadProfileToEditor(newIdx)
    MultiKeyRefreshProfileList()
}

MultiKeyTriggerPressKey(trigger) {
    trigger := ComboCanonMainKey(trigger)
    if (trigger = "") {
        return ""
    }
    pressKey := Key2PressKey(GetOriginKeyName(trigger))
    if (StrLen(pressKey) >= 4 && SubStr(pressKey, 1, 2) = "sc") {
        pressKey := Format("{:L}", pressKey)
    }
    return pressKey
}

MultiKeyHasTrigger(trigger, skipIdx := 0) {
    global __MultiKeyProfiles
    pressKey := MultiKeyTriggerPressKey(trigger)
    if (pressKey = "") {
        return false
    }
    loop __MultiKeyProfiles.Length {
        if (A_Index = skipIdx || !__MultiKeyProfiles.Has(A_Index)) {
            continue
        }
        other := MultiKeyTriggerPressKey(__MultiKeyProfiles[A_Index].trigger)
        if (other != "" && other = pressKey) {
            return true
        }
    }
    return false
}

MultiKeyAddProfile(*) {
    global __MultiKeyProfiles, __MultiKeyProfileIndex
    btn := MultiKeyGetCtrl("MultiKeyAddProfileButton")
    if IsObject(btn) {
        try btn.Text := exText["PressKeyPrompt"]
    }
    try {
        key := MultiKeyCaptureKey()
    } finally {
        if IsObject(btn) {
            try btn.Text := exText["MultiKeyAddProfile"]
        }
    }
    if (key = "") {
        return
    }
    MultiKeyFlushEditorToProfileAt(__MultiKeyProfileIndex)
    if MultiKeyHasTrigger(key) {
        MsgBox(exText["DuplicateKey"], exText["MultiKeyTitle"], "Icon!")
        return
    }
    __MultiKeyProfiles.Push({ trigger: key, firstKey: "", keys: [] })
    __MultiKeyProfileIndex := __MultiKeyProfiles.Length
    MultiKeyRefreshProfileList()
    MultiKeyLoadProfileToEditor(__MultiKeyProfileIndex)
}

MultiKeyRemoveProfile(*) {
    global __MultiKeyProfiles, __MultiKeyProfileIndex
    if (__MultiKeyProfileIndex < 1 || __MultiKeyProfileIndex > __MultiKeyProfiles.Length || !__MultiKeyProfiles.Has(__MultiKeyProfileIndex)) {
        return
    }
    MultiKeyFlushEditorToProfileAt(__MultiKeyProfileIndex)
    __MultiKeyProfiles.RemoveAt(__MultiKeyProfileIndex)
    if (__MultiKeyProfileIndex > __MultiKeyProfiles.Length) {
        __MultiKeyProfileIndex := __MultiKeyProfiles.Length
    }
    MultiKeyRefreshProfileList()
    MultiKeyLoadProfileToEditor(__MultiKeyProfileIndex)
}

MultiKeyAddKey(*) {
    global __MultiKeyProfiles, __MultiKeyKeys, __MultiKeyProfileIndex
    if (__MultiKeyProfiles.Length = 0) {
        MultiKeyAddProfile()
        if (__MultiKeyProfiles.Length = 0) {
            return
        }
    }
    btn := MultiKeyGetCtrl("MultiKeyAddKeyButton")
    if IsObject(btn) {
        try btn.Text := exText["PressKeyPrompt"]
    }
    try {
        key := MultiKeyCaptureKey()
    } finally {
        if IsObject(btn) {
            try btn.Text := exText["MultiKeyAddKey"]
        }
    }
    if (key = "") {
        return
    }
    for existing in __MultiKeyKeys {
        if (ComboCanonMainKey(existing) = key) {
            MsgBox(exText["DuplicateKey"], exText["MultiKeyTitle"], "Icon!")
            return
        }
    }
    __MultiKeyKeys.Push(key)
    MultiKeyRefreshKeyList()
}

MultiKeyDeleteKey(*) {
    global __MultiKeyKeys
    ctrl := MultiKeyGetCtrl("MultiKeyKeysListBox")
    if (ctrl.Text = "") {
        return
    }
    idx := ctrl.Value
    if (idx >= 1 && idx <= __MultiKeyKeys.Length) {
        __MultiKeyKeys.RemoveAt(idx)
        MultiKeyEnsureFirstKeyInEditor(MultiKeyFirstKeyValue())
        MultiKeyRefreshKeyList()
    }
}

MultiKeyKeyDragGetItems(*) {
    global __MultiKeyKeys
    return UiListBoxDragSort_CopyArray(__MultiKeyKeys)
}

MultiKeyKeyDragCommit(items, selectedIndex) {
    global __MultiKeyKeys
    __MultiKeyKeys := items
    MultiKeyRefreshKeyList()
    ctrl := MultiKeyGetCtrl("MultiKeyKeysListBox")
    if IsObject(ctrl) && selectedIndex > 0 {
        try ctrl.Choose(selectedIndex)
    }
}

MultiKeySaveAndClose(*) {
    if !MultiKeySaveConfig() {
        return
    }
    MultiKeyRefreshProfileList()
    HideGuiMultiKey()
}

MultiKeySaveConfig() {
    global __MultiKeyProfiles, __MultiKeyProfileIndex
    presetName := ResolvePresetName()
    MultiKeyFlushEditorToProfileAt(__MultiKeyProfileIndex)
    MultiKeySaveProfilesToPreset(presetName, __MultiKeyProfiles)
    return true
}

MultiKeyLoadConfig() {
    global __MultiKeyProfiles, __MultiKeyProfileIndex
    presetName := ResolvePresetName()
    __MultiKeyProfiles := MultiKeyLoadProfilesFromPreset(presetName)
    __MultiKeyProfileIndex := __MultiKeyProfiles.Length > 0 ? 1 : 0
    MultiKeyRefreshProfileList()
    MultiKeyLoadProfileToEditor(__MultiKeyProfileIndex)
}
