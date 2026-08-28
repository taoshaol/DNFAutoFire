#Requires AutoHotkey v2.0

global gLongZhanGui := Gui("-MinimizeBox -MaximizeBox")
global gLongZhanCtrls := Map()
global gLongZhanSelectedPath := ""
global gLongZhanItems := []
global gLongZhanSelectedPreset := ""
global _IsLongZhanPresetUiSyncing := false
global gLongZhanLayout := LongZhanLayout.Window()

UiApplyWindow(gLongZhanGui)
gLongZhanGui.OnEvent("Escape", LongZhanGuiEscape)
gLongZhanGui.OnEvent("Close", LongZhanGuiClose)

marginX := LongZhanLayout.MarginX()
contentR := LongZhanLayout.ContentRight()
listW := LongZhanLayout.ListWidth()
listH := LongZhanLayout.ListHeight()
listY := LongZhanLayout.ListY()
pvX := LongZhanLayout.PreviewX()
pvW := LongZhanLayout.PreviewWidth()
pvH := LongZhanLayout.PreviewHeight()
pvY := LongZhanLayout.PreviewY()
enableY := LongZhanLayout.EnableY()
hotkeyY := LongZhanLayout.HotkeyY()
presetLabelY := LongZhanLayout.PresetLabelY()
presetListY := LongZhanLayout.PresetListY()
presetListH := LongZhanLayout.PresetListHeight()
skillY := LongZhanLayout.SkillKeyY()
pickBtnY := LongZhanLayout.PickBtnY()
middleY := LongZhanLayout.MiddleY()
captureBtnY := LongZhanLayout.CaptureBtnY()
saveY := LongZhanLayout.SaveY()

UiSectionWithHelp(gLongZhanGui, gLongZhanLayout, marginX, 12, LongZhanText["SectionTitle"], LongZhanHelp, contentR)
gLongZhanCtrls["LongZhanEnableVisible"] := gLongZhanGui.Add("CheckBox", UiLayoutRect(gLongZhanLayout, marginX, enableY, contentR - marginX, 20, "vLongZhanEnableVisible"), LongZhanText["Enable"])
gLongZhanCtrls["LongZhanEnableVisible"].OnEvent("Click", LongZhanSyncEnableFromUi)
UiLabel(gLongZhanGui, UiLayoutRect(gLongZhanLayout, marginX, hotkeyY, 110, 20), LongZhanText["ToggleHotkey"])
UiHotkey(gLongZhanCtrls, gLongZhanGui, "LongZhanHotkey", UiLayoutRect(gLongZhanLayout, 128, hotkeyY, contentR - 128, ExLayout.ControlHeight(), "-E0x200 Border"))
UiLabel(gLongZhanGui, UiLayoutRect(gLongZhanLayout, marginX, presetLabelY, listW, 20), LongZhanText["PresetList"])
UiListBox(gLongZhanCtrls, gLongZhanGui, "LongZhanPresetList", UiLayoutRect(gLongZhanLayout, marginX, presetListY, listW, presetListH), LongZhanOnPresetListChange)
UiLabel(gLongZhanGui, UiLayoutRect(gLongZhanLayout, pvX, presetLabelY, pvW, 20), LongZhanText["SkillKey"])
UiPressKeyEdit(gLongZhanCtrls, gLongZhanGui, "LongZhanSkillKey", UiLayoutRect(gLongZhanLayout, pvX, skillY, pvW, ExLayout.ControlHeight()))
UiPlainButton(gLongZhanGui, UiLayoutRect(gLongZhanLayout, marginX, pickBtnY, contentR - marginX, ExLayout.ControlHeight()), LongZhanText["PickRegion"], LongZhanPickRegion, "secondary")
UiLabel(gLongZhanGui, UiLayoutRect(gLongZhanLayout, marginX, middleY, listW, 20), LongZhanText["ResolutionList"])
UiListBox(gLongZhanCtrls, gLongZhanGui, "LongZhanResolutionList", UiLayoutRect(gLongZhanLayout, marginX, listY, listW, listH), LongZhanOnResolutionChange)
gLongZhanCtrls["LongZhanPreview"] := gLongZhanGui.Add("Picture", UiLayoutRect(gLongZhanLayout, pvX, pvY, pvW, pvH), "")
UiPlainButton(gLongZhanGui, UiLayoutRect(gLongZhanLayout, pvX, captureBtnY, (pvW - 8) // 2, ExLayout.ControlHeight()), LongZhanText["Capture"], LongZhanCaptureIcon, "secondary")
UiPlainButton(gLongZhanGui, UiLayoutRect(gLongZhanLayout, pvX + (pvW + 8) // 2, captureBtnY, (pvW - 8) // 2, ExLayout.ControlHeight()), LongZhanText["Delete"], LongZhanDeleteIcon, "secondary")
UiPlainButton(gLongZhanGui, UiExSaveButtonRect(gLongZhanLayout, saveY, contentR), LongZhanText["Save"], LongZhanGuiSave, "primary")

LongZhanGetCtrl(name) {
    global gLongZhanCtrls
    return gLongZhanCtrls.Has(name) ? gLongZhanCtrls[name] : ""
}

LongZhanPathToResolution(path) {
    SplitPath(path, &fileName)
    return RegExReplace(fileName, "\.png$")
}

LongZhanPickRegion(*) {
    global gLongZhanItems
    if (gLongZhanItems.Length > 0 && !LongZhanConfirmResetRegion()) {
        return
    }
    PresetRegionPickOpen("longzhan")
}

LongZhanConfirmResetRegion() {
    global gLongZhanGui, UiTheme
    result := {confirmed: false}
    options := "+AlwaysOnTop -MinimizeBox -MaximizeBox"
    if IsObject(gLongZhanGui) {
        options .= " +Owner" gLongZhanGui.Hwnd
    }
    dlg := Gui(options, LongZhanText["ResetRegionConfirmTitle"])
    UiApplyWindow(dlg)
    UiSetDefaultFont(dlg, "s10 " UiTheme["TextColor"])
    dlg.Add("Text", "x16 y16 w368", LongZhanText["ResetRegionConfirm"])
    UiPlainButton(dlg, "x16 y+16 w176 h28 Default", LongZhanText["ResetRegionConfirmAction"], LongZhanConfirmResetRegionAccept.Bind(dlg, result), "primary")
    UiPlainButton(dlg, "x+16 yp w176 h28", LongZhanText["Cancel"], (*) => dlg.Destroy(), "secondary")
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    dlg.Show("AutoSize Center")
    WinWaitClose("ahk_id " dlg.Hwnd)
    return result.confirmed
}

LongZhanConfirmResetRegionAccept(dlg, result, *) {
    result.confirmed := true
    dlg.Destroy()
}

LongZhanLockPreview(pic) {
    if IsObject(pic) {
        pic.Move(LongZhanLayout.PreviewX(), LongZhanLayout.PreviewY(), LongZhanLayout.PreviewWidth(), LongZhanLayout.PreviewHeight())
    }
}

LongZhanSyncResolutionList(selectPath := "") {
    global gLongZhanItems, gLongZhanSelectedPath
    gLongZhanItems := LongZhanIconPaths()
    names := []
    for path in gLongZhanItems {
        names.Push(LongZhanPathToResolution(path))
    }
    listCtrl := LongZhanGetCtrl("LongZhanResolutionList")
    if !IsObject(listCtrl) {
        return
    }
    MainSetListBoxFromArray(listCtrl, names)
    pickPath := selectPath
    if (pickPath = "") {
        try {
            curPath := LongZhanIconCurrentPath()
            for path in gLongZhanItems {
                if (path = curPath) {
                    pickPath := path
                    break
                }
            }
        } catch {
        }
    }
    if (pickPath = "" && gLongZhanItems.Length > 0) {
        pickPath := gLongZhanItems[1]
    }
    gLongZhanSelectedPath := pickPath
    idx := 0
    loop gLongZhanItems.Length {
        if (gLongZhanItems[A_Index] = pickPath) {
            idx := A_Index
            break
        }
    }
    if (idx > 0) {
        listCtrl.Value := idx
    }
    LongZhanRefreshPreview()
}

LongZhanOnResolutionChange(*) {
    global gLongZhanItems, gLongZhanSelectedPath
    listCtrl := LongZhanGetCtrl("LongZhanResolutionList")
    if !IsObject(listCtrl) {
        gLongZhanSelectedPath := ""
        LongZhanRefreshPreview()
        return
    }
    idx := listCtrl.Value
    if (idx >= 1 && idx <= gLongZhanItems.Length) {
        gLongZhanSelectedPath := gLongZhanItems[idx]
    } else {
        gLongZhanSelectedPath := ""
    }
    LongZhanRefreshPreview()
}

LongZhanRefreshPreview() {
    global gLongZhanSelectedPath
    pic := LongZhanGetCtrl("LongZhanPreview")
    if !IsObject(pic) {
        return
    }
    pic.Value := ""
    LongZhanLockPreview(pic)
    p := gLongZhanSelectedPath
    if (p = "") {
        for path in LongZhanIconPaths() {
            p := path
            break
        }
    }
    if (p != "" && FileExist(p)) {
        tmp := A_Temp "\DAF_longzhan_fit_preview.png"
        if AutoPresetsSkillIcon_RenderFitPreviewToFile(p, LongZhanLayout.PreviewWidth(), LongZhanLayout.PreviewHeight(), tmp) && FileExist(tmp) {
            pic.Value := tmp
        } else {
            pic.Value := p
        }
        LongZhanLockPreview(pic)
    }
}

LongZhanAfterRegionPick(*) {
    global gLongZhanGui
    if !IsObject(gLongZhanGui) || !WinExist("ahk_id " gLongZhanGui.Hwnd) {
        return
    }
    try {
        path := LongZhanIcon_UpdateCurrent()
        LongZhanSyncResolutionList(path)
    } catch {
        LongZhanSyncResolutionList()
    }
}

LongZhanResolveSelectedPreset() {
    global gLongZhanSelectedPreset
    presetList := LoadAllPreset()
    for n in presetList {
        if (n = gLongZhanSelectedPreset) {
            return gLongZhanSelectedPreset
        }
    }
    cur := GetNowSelectPreset()
    for n in presetList {
        if (n = cur) {
            return cur
        }
    }
    return presetList.Length >= 1 ? presetList[1] : ""
}

LongZhanSyncPresetList() {
    global gLongZhanSelectedPreset, _IsLongZhanPresetUiSyncing
    listCtrl := LongZhanGetCtrl("LongZhanPresetList")
    if !IsObject(listCtrl) {
        return
    }
    _IsLongZhanPresetUiSyncing := true
    try {
        pipe := LoadAllPresetString()
        MainSetListBox(listCtrl, pipe)
        gLongZhanSelectedPreset := LongZhanResolveSelectedPreset()
        if (gLongZhanSelectedPreset != "") {
            idx := 0
            for i, txt in StrSplit(pipe, "|") {
                if (txt = gLongZhanSelectedPreset) {
                    idx := i
                    break
                }
            }
            if (idx > 0) {
                MainPresetListSafeChoose(listCtrl, idx, pipe)
            }
        }
    } finally {
        _IsLongZhanPresetUiSyncing := false
    }
    LongZhanLoadSkillKeyToUi()
}

LongZhanLoadSkillKeyToUi() {
    ctrl := LongZhanGetCtrl("LongZhanSkillKey")
    if !IsObject(ctrl) {
        return
    }
    ctrl.Text := LongZhan_LoadSkillKey(LongZhanResolveSelectedPreset())
}

LongZhanSaveSelectedSkillKey() {
    name := LongZhanResolveSelectedPreset()
    if (name = "") {
        return
    }
    LongZhan_SaveSkillKey(name, UiPressKeyEdit_Value(LongZhanGetCtrl("LongZhanSkillKey")))
}

LongZhanOnPresetListChange(*) {
    global gLongZhanSelectedPreset, _IsLongZhanPresetUiSyncing
    if _IsLongZhanPresetUiSyncing {
        return
    }
    listCtrl := LongZhanGetCtrl("LongZhanPresetList")
    if !IsObject(listCtrl) {
        return
    }
    presetName := Trim(listCtrl.Text)
    if (presetName = "" || presetName = gLongZhanSelectedPreset) {
        return
    }
    LongZhanSaveSelectedSkillKey()
    gLongZhanSelectedPreset := presetName
    LongZhanLoadSkillKeyToUi()
}

LongZhanRefreshEnableCheckbox() {
    v := LongZhan_LoadEnabled() ? 1 : 0
    c := LongZhanGetCtrl("LongZhanEnableVisible")
    if IsObject(c) {
        c.Value := v
    }
}

LongZhanLoadHotkeyToUi() {
    hk := LongZhan_LoadHotkey()
    ctrl := LongZhanGetCtrl("LongZhanHotkey")
    if !IsObject(ctrl) {
        return
    }
    try ctrl.Value := hk
    catch {
        ctrl.Value := ""
    }
}

LongZhanLoadToGui() {
    global gLongZhanSelectedPreset
    gLongZhanSelectedPreset := GetNowSelectPreset()
    LongZhanRefreshEnableCheckbox()
    LongZhanLoadHotkeyToUi()
    LongZhanSyncPresetList()
    LongZhanSyncResolutionList()
}

LongZhanSyncEnableFromUi(*) {
    v := LongZhanGetCtrl("LongZhanEnableVisible").Value ? 1 : 0
    SaveConfig("LongZhanEnabled", v)
}

ShowGuiLongZhan(*) {
    global gMainGui, gLongZhanGui, gLongZhanLayout
    if IsObject(gMainGui) {
        gLongZhanGui.Opt("+Owner" gMainGui.Hwnd)
    }
    gLongZhanGui.Title := LongZhanText["SectionTitle"]
    LongZhanLoadToGui()
    gLongZhanGui.Show("w" gLongZhanLayout.Width(LongZhanLayout.WindowWidth()) " h" gLongZhanLayout.Height())
    DisableGuiMain()
}

HideGuiLongZhan() {
    global gLongZhanGui
    PresetRegionPickCommitIfOpen()
    gLongZhanGui.Hide()
    EnableGuiMain()
}

LongZhanGuiEscape(*) {
    LongZhanGuiSave()
}

LongZhanGuiClose(*) {
    LongZhanGuiSave()
}

LongZhanGuiSave(*) {
    PresetRegionPickCommitIfOpen()
    LongZhanSaveSelectedSkillKey()
    hk := Trim(LongZhanGetCtrl("LongZhanHotkey").Value)
    SaveConfig("LongZhanHotkey", hk)
    v := LongZhanGetCtrl("LongZhanEnableVisible").Value ? 1 : 0
    SaveConfig("LongZhanEnabled", v)
    HideGuiLongZhan()
    if AutoPresets_IsSessionRunning() {
        LongZhan_RegisterToggleHotkey()
    }
}

LongZhanHelp(*) {
    UiHelpMsgBox(LongZhanText["Help"], LongZhanText["HelpTitle"])
}

LongZhanCaptureIcon(*) {
    PresetRegionPickCommitIfOpen()
    try {
        path := LongZhanIcon_UpdateCurrent()
        LongZhanSyncResolutionList(path)
    } catch Error as e {
        MsgBox(e.Message,, "Icon!")
    }
}

LongZhanDeleteIcon(*) {
    global gLongZhanSelectedPath
    path := gLongZhanSelectedPath
    if (path = "" || !FileExist(path)) {
        return
    }
    try FileDelete(path)
    gLongZhanSelectedPath := ""
    LongZhanSyncResolutionList()
}
