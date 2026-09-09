#Requires AutoHotkey v2.0

global gAutoPresetsGui := Gui("-MinimizeBox -MaximizeBox")
global gAutoPresetsCtrls := Map()
global gAutoPresetsSelectedPreset := ""
global gAutoPresetsSelectedSkillId := ""
global gAutoPresetsSelectedResolution := ""
global gAutoPresetsSelectedChatPath := ""
global gAutoPresetsSkillItems := []
global gAutoPresetsResolutionKeys := []
global gAutoPresetsLayout := AutoPresetsLayout.Window()

UiApplyWindow(gAutoPresetsGui)
gAutoPresetsGui.OnEvent("Escape", AutoPresetsGuiEscape)
gAutoPresetsGui.OnEvent("Close", AutoPresetsGuiClose)

marginX := AutoPresetsLayout.MarginX()
windowW := AutoPresetsLayout.WindowWidth()
contentR := AutoPresetsLayout.ContentRight()
listW := AutoPresetsLayout.ListWidth()
skillListX := AutoPresetsLayout.SkillIconListX()
skillListW := AutoPresetsLayout.SkillIconListWidth()
rightX := AutoPresetsLayout.RightX()
rightW := AutoPresetsLayout.RightWidth()
pvW := AutoPresetsLayout.PreviewWidth()
pvH := AutoPresetsLayout.PreviewHeight()
pvY := AutoPresetsLayout.PreviewY()
previewColX := AutoPresetsLayout.PreviewColX()
resListX := AutoPresetsLayout.ResolutionListX()
resListW := AutoPresetsLayout.ResolutionListWidth()
resListH := AutoPresetsLayout.ResolutionListHeight()
resListY := AutoPresetsLayout.ResolutionListY()
resCapBtnY := AutoPresetsLayout.ResolutionCaptureBtnY()
resBtnY := AutoPresetsLayout.ResolutionBtnY()
chatPvW := AutoPresetsLayout.ChatPreviewWidth()
rowActionY := AutoPresetsLayout.RowActionY()
apEnableY := AutoPresetsLayout.EnableY()
apHotkeyY := AutoPresetsLayout.HotkeyY()
pickBtnY := AutoPresetsLayout.PickBtnY()
chatY := AutoPresetsLayout.ChatY()
chatBtnY := AutoPresetsLayout.ChatBtnY()
chatPvH := AutoPresetsLayout.ChatPreviewHeight()
lowerY := AutoPresetsLayout.LowerY()
listY := AutoPresetsLayout.ListY()
listH := AutoPresetsLayout.ListHeight()
saveY := AutoPresetsLayout.SaveY()

UiSectionWithHelp(gAutoPresetsGui, gAutoPresetsLayout, marginX, 12, AutoPresetsText["SectionTitle"], AutoPresetsHelp, contentR)
gAutoPresetsCtrls["AutoPresetsEnableVisible"] := gAutoPresetsGui.Add("CheckBox", UiLayoutRect(gAutoPresetsLayout, marginX, apEnableY, 128, 20, "vAutoPresetsEnableVisible"), AutoPresetsText["Enable"])
gAutoPresetsCtrls["AutoPresetsEnableVisible"].OnEvent("Click", AutoPresetsSyncEnableFromUi)
durSuffixW := 18
durEditW := 40
durLabelW := 56
durSuffixX := contentR - durSuffixW
durEditX := durSuffixX - 4 - durEditW
durLabelX := durEditX - 4 - durLabelW
UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, durLabelX, apEnableY, durLabelW, 20), AutoPresetsText["RecognizeDurationPrefix"])
UiEdit(gAutoPresetsCtrls, gAutoPresetsGui, "AutoPresetRecognizeSeconds", UiLayoutRect(gAutoPresetsLayout, durEditX, apEnableY - 1, durEditW, ExLayout.ControlHeight(), "+Number +Limit3 -E0x200 Border"))
UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, durSuffixX, apEnableY, durSuffixW, 20), AutoPresetsText["RecognizeDurationSuffix"])
UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, marginX, apHotkeyY, 140, 20), AutoPresetsText["ExtraHotkey"])
UiPressKeyEdit(gAutoPresetsCtrls, gAutoPresetsGui, "AutoPresetHotkey", UiLayoutRect(gAutoPresetsLayout, 144, apHotkeyY, contentR - 144, ExLayout.ControlHeight()))

apStrictY := AutoPresetsLayout.StrictY()
apStrictLabelW := 72
apStrictPctW := 40
apStrictSliderX := marginX + apStrictLabelW + 8
apStrictSliderW := contentR - apStrictSliderX - apStrictPctW - 4
UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, marginX, apStrictY, apStrictLabelW, 22), AutoPresetsText["MatchStrict"])
UiAdd(gAutoPresetsCtrls, gAutoPresetsGui, "Slider", UiLayoutRect(gAutoPresetsLayout, apStrictSliderX, apStrictY, apStrictSliderW, 22, "vMatchStrict Range0-100 TickInterval25 ToolTip"), AutoPresets_MatchStrictDefault())
gAutoPresetsCtrls["MatchStrict"].OnEvent("Change", AutoPresetsMatchStrictOnChange)
gAutoPresetsCtrls["MatchStrictValue"] := UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, contentR - apStrictPctW, apStrictY, apStrictPctW, 22, "+0x2"), AutoPresets_MatchStrictDefault() "%")

UiPlainButton(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, marginX, pickBtnY, (contentR - marginX - 8) // 2, ExLayout.ControlHeight()), AutoPresetsText["PickSkillRegion"], AutoPresetsPickRegion.Bind("skill"), "secondary")
UiPlainButton(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, marginX + (contentR - marginX + 8) // 2, pickBtnY, (contentR - marginX - 8) // 2, ExLayout.ControlHeight()), AutoPresetsText["PickChatRegion"], AutoPresetsPickRegion.Bind("chat"), "secondary")
UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, resListX, resListY - 24, resListW, 20), AutoPresetsText["ResolutionList"])
UiListBox(gAutoPresetsCtrls, gAutoPresetsGui, "ResolutionList", UiLayoutRect(gAutoPresetsLayout, resListX, resListY, resListW, resListH), AutoPresetsOnResolutionChange)
UiPlainButton(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, resListX, resCapBtnY, resListW, ExLayout.ControlHeight()), AutoPresetsText["CaptureResolution"], AutoPresetsCaptureResolution, "secondary")
UiPlainButton(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, resListX, resBtnY, resListW, ExLayout.ControlHeight()), AutoPresetsText["DeleteResolution"], AutoPresetsDeleteResolution, "secondary")
UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, previewColX, chatY - 20, chatPvW, 20), AutoPresetsText["ChatReference"])
gAutoPresetsCtrls["ChatPreview"] := gAutoPresetsGui.Add("Picture", UiLayoutRect(gAutoPresetsLayout, previewColX, chatY, chatPvW, chatPvH), "")
UiPlainButton(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, previewColX, chatBtnY, (chatPvW - 8) // 2, ExLayout.ControlHeight()), AutoPresetsText["CaptureChat"], AutoPresetsCaptureChatIcon, "secondary")
UiPlainButton(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, previewColX + (chatPvW + 8) // 2, chatBtnY, (chatPvW - 8) // 2, ExLayout.ControlHeight()), AutoPresetsText["DeleteChat"], AutoPresetsDeleteChatIcon, "secondary")

UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, marginX, lowerY, listW, 20), AutoPresetsText["PresetList"])
UiListBox(gAutoPresetsCtrls, gAutoPresetsGui, "AutoPresetPresetList", UiLayoutRect(gAutoPresetsLayout, marginX, listY, listW, listH), AutoPresetsOnPresetListChange)
UiLabel(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, skillListX, lowerY, contentR - skillListX, 20), AutoPresetsText["SkillIconList"])
UiListBox(gAutoPresetsCtrls, gAutoPresetsGui, "AutoPresetSkillIconList", UiLayoutRect(gAutoPresetsLayout, skillListX, listY, skillListW, listH), AutoPresetsOnSkillIconListChange)
gAutoPresetsCtrls["AutoPresetSkillIconList"].OnEvent("DoubleClick", AutoPresetsRenameSkillIcon)
OnMessage(0x0202, AutoPresetsSkillIconListOnLButtonUp)
UiEdit(gAutoPresetsCtrls, gAutoPresetsGui, "AutoPresetSelectedName", UiLayoutRect(gAutoPresetsLayout, rightX, lowerY + 1, 1, 1, "+ReadOnly Hidden -E0x200"))
gAutoPresetsCtrls["SkillPreview"] := gAutoPresetsGui.Add("Picture", UiLayoutRect(gAutoPresetsLayout, rightX, pvY, pvW, pvH), "")
UiPlainButton(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, rightX, rowActionY, (pvW - 8) // 2, ExLayout.ControlHeight()), AutoPresetsText["CaptureReference"], AutoPresetsUpdateSkillIcon, "secondary")
UiPlainButton(gAutoPresetsGui, UiLayoutRect(gAutoPresetsLayout, rightX + (pvW + 8) // 2, rowActionY, (pvW - 8) // 2, ExLayout.ControlHeight()), AutoPresetsText["DeleteReference"], AutoPresetsDeleteSkillIcon, "secondary")
UiPlainButton(gAutoPresetsGui, UiExSaveButtonRect(gAutoPresetsLayout, saveY, contentR), AutoPresetsText["Save"], AutoPresetsGuiSave, "primary")

AutoPresetsGetCtrl(name) {
    global gAutoPresetsCtrls
    return gAutoPresetsCtrls.Has(name) ? gAutoPresetsCtrls[name] : ""
}

AutoPresetsPickRegion(kind, *) {
    if (kind = "chat") {
        if (AutoPresetsChatIconPaths().Length > 0 && !AutoPresetsConfirmResetRegion()) {
            return
        }
    } else if (AutoPresets_ListSkillResolutionKeys().Length > 0 && !AutoPresetsConfirmResetRegion()) {
        return
    }
    PresetRegionPickOpen(kind)
}

AutoPresetsConfirmResetRegion() {
    global gAutoPresetsGui, UiTheme
    result := {confirmed: false}
    options := "+AlwaysOnTop -MinimizeBox -MaximizeBox"
    if IsObject(gAutoPresetsGui) {
        options .= " +Owner" gAutoPresetsGui.Hwnd
    }
    dlg := Gui(options, AutoPresetsText["ResetRegionConfirmTitle"])
    UiApplyWindow(dlg)
    UiSetDefaultFont(dlg, "s10 " UiTheme["TextColor"])
    dlg.Add("Text", "x16 y16 w368", AutoPresetsText["ResetRegionConfirm"])
    UiPlainButton(dlg, "x16 y+16 w176 h28 Default", AutoPresetsText["ResetRegionConfirmAction"], AutoPresetsConfirmResetRegionAccept.Bind(dlg, result), "primary")
    UiPlainButton(dlg, "x+16 yp w176 h28", AutoPresetsText["Cancel"], (*) => dlg.Destroy(), "secondary")
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    dlg.Show("AutoSize Center")
    WinWaitClose("ahk_id " dlg.Hwnd)
    return result.confirmed
}

AutoPresetsConfirmResetRegionAccept(dlg, result, *) {
    result.confirmed := true
    dlg.Destroy()
}

AutoPresetsLockSkillPreview(pic) {
    if IsObject(pic) {
        pic.Move(AutoPresetsLayout.RightX(), AutoPresetsLayout.PreviewY(), AutoPresetsLayout.PreviewWidth(), AutoPresetsLayout.PreviewHeight())
    }
}

AutoPresetsLockChatPreview(pic) {
    if IsObject(pic) {
        pic.Move(AutoPresetsLayout.PreviewColX(), AutoPresetsLayout.ChatY(), AutoPresetsLayout.ChatPreviewWidth(), AutoPresetsLayout.ChatPreviewHeight())
    }
}

AutoPresetsResolveSelectedSkillItem() {
    global gAutoPresetsSkillItems, gAutoPresetsSelectedSkillId
    listCtrl := AutoPresetsGetCtrl("AutoPresetSkillIconList")
    if IsObject(listCtrl) {
        idx := listCtrl.Value
        if (idx >= 1 && idx <= gAutoPresetsSkillItems.Length) {
            return gAutoPresetsSkillItems[idx]
        }
    }
    if (gAutoPresetsSelectedSkillId != "") {
        for item in gAutoPresetsSkillItems {
            if (item["id"] = gAutoPresetsSelectedSkillId) {
                return item
            }
        }
    }
    return ""
}

AutoPresetsSelectSkillIconById(skillId) {
    global gAutoPresetsSkillItems, gAutoPresetsSelectedSkillId
    listCtrl := AutoPresetsGetCtrl("AutoPresetSkillIconList")
    if !IsObject(listCtrl) {
        return
    }
    gAutoPresetsSelectedSkillId := skillId
    idx := 0
    loop gAutoPresetsSkillItems.Length {
        if (gAutoPresetsSkillItems[A_Index]["id"] = skillId) {
            idx := A_Index
            break
        }
    }
    if (idx > 0) {
        listCtrl.Value := idx
    }
    AutoPresetsRefreshSkillPreview()
}

AutoPresetsResolveSelectedResolution() {
    global gAutoPresetsSelectedResolution
    return gAutoPresetsSelectedResolution
}

AutoPresetsSyncResolutionList(selectKey := "") {
    global gAutoPresetsResolutionKeys, gAutoPresetsSelectedResolution
    gAutoPresetsResolutionKeys := AutoPresets_SortResolutionKeys(AutoPresets_ListKnownResolutionKeys(), AutoPresetsResolutionKey())
    listCtrl := AutoPresetsGetCtrl("ResolutionList")
    if !IsObject(listCtrl) {
        return
    }
    MainSetListBoxFromArray(listCtrl, gAutoPresetsResolutionKeys)
    pickKey := ""
    if (selectKey != "") {
        for key in gAutoPresetsResolutionKeys {
            if (key = selectKey) {
                pickKey := key
                break
            }
        }
    }
    if (pickKey = "") {
        curKey := AutoPresetsResolutionKey()
        for key in gAutoPresetsResolutionKeys {
            if (key = curKey) {
                pickKey := key
                break
            }
        }
    }
    if (pickKey = "" && gAutoPresetsSelectedResolution != "") {
        for key in gAutoPresetsResolutionKeys {
            if (key = gAutoPresetsSelectedResolution) {
                pickKey := key
                break
            }
        }
    }
    if (pickKey = "" && gAutoPresetsResolutionKeys.Length > 0) {
        pickKey := gAutoPresetsResolutionKeys[1]
    }
    gAutoPresetsSelectedResolution := pickKey
    idx := 0
    loop gAutoPresetsResolutionKeys.Length {
        if (gAutoPresetsResolutionKeys[A_Index] = pickKey) {
            idx := A_Index
            break
        }
    }
    if (idx > 0) {
        listCtrl.Value := idx
    }
    AutoPresetsSyncSkillIconList()
    AutoPresetsRefreshChatPreview()
}

AutoPresetsOnResolutionChange(*) {
    global gAutoPresetsResolutionKeys, gAutoPresetsSelectedResolution
    listCtrl := AutoPresetsGetCtrl("ResolutionList")
    if !IsObject(listCtrl) {
        gAutoPresetsSelectedResolution := ""
        AutoPresetsSyncSkillIconList()
        AutoPresetsRefreshChatPreview()
        return
    }
    idx := listCtrl.Value
    if (idx >= 1 && idx <= gAutoPresetsResolutionKeys.Length) {
        gAutoPresetsSelectedResolution := gAutoPresetsResolutionKeys[idx]
    } else {
        gAutoPresetsSelectedResolution := ""
    }
    AutoPresetsSyncSkillIconList()
    AutoPresetsRefreshChatPreview()
}

AutoPresetsSyncSkillIconList(selectSkillId := "") {
    global gAutoPresetsSkillItems, gAutoPresetsSelectedSkillId
    presetName := AutoPresetsResolveSelectedPreset()
    resolutionKey := AutoPresetsResolveSelectedResolution()
    gAutoPresetsSkillItems := AutoPresetsSkillIcons_Load(presetName, resolutionKey)
    names := []
    for item in gAutoPresetsSkillItems {
        names.Push(item["name"])
    }
    listCtrl := AutoPresetsGetCtrl("AutoPresetSkillIconList")
    if !IsObject(listCtrl) {
        return
    }
    MainSetListBoxFromArray(listCtrl, names)
    pickId := selectSkillId
    if (pickId = "" && gAutoPresetsSkillItems.Length > 0) {
        pickId := gAutoPresetsSkillItems[gAutoPresetsSkillItems.Length]["id"]
    }
    if (pickId != "") {
        AutoPresetsSelectSkillIconById(pickId)
    } else {
        gAutoPresetsSelectedSkillId := ""
        AutoPresetsRefreshSkillPreview()
    }
}

AutoPresetsOnSkillIconListChange(*) {
    global gAutoPresetsSkillItems, gAutoPresetsSelectedSkillId
    listCtrl := AutoPresetsGetCtrl("AutoPresetSkillIconList")
    if !IsObject(listCtrl) {
        gAutoPresetsSelectedSkillId := ""
        AutoPresetsRefreshSkillPreview()
        return
    }
    idx := listCtrl.Value
    if (idx >= 1 && idx <= gAutoPresetsSkillItems.Length) {
        gAutoPresetsSelectedSkillId := gAutoPresetsSkillItems[idx]["id"]
    } else {
        gAutoPresetsSelectedSkillId := ""
    }
    AutoPresetsRefreshSkillPreview()
}

AutoPresetsSkillIconListOnLButtonUp(wParam, lParam, msg, hwnd) {
    listCtrl := AutoPresetsGetCtrl("AutoPresetSkillIconList")
    if !IsObject(listCtrl) || hwnd != listCtrl.Hwnd {
        return
    }
    idx := UiListBoxDragSort_IndexFromClientPoint(listCtrl, lParam & 0xFFFF, (lParam >> 16) & 0xFFFF)
    if (idx <= 0) {
        return
    }
    global gAutoPresetsSkillItems, gAutoPresetsSelectedSkillId
    if (idx > gAutoPresetsSkillItems.Length) {
        return
    }
    skillId := gAutoPresetsSkillItems[idx]["id"]
    if (skillId != gAutoPresetsSelectedSkillId) {
        return
    }
    AutoPresetsRefreshSkillPreview()
}

AutoPresetsResolveSelectedPreset() {
    global gAutoPresetsSelectedPreset
    presetList := LoadAllPreset()
    for n in presetList {
        if (n = gAutoPresetsSelectedPreset) {
            return gAutoPresetsSelectedPreset
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

AutoPresetsSyncPresetList() {
    global gAutoPresetsSelectedPreset
    listCtrl := AutoPresetsGetCtrl("AutoPresetPresetList")
    nameCtrl := AutoPresetsGetCtrl("AutoPresetSelectedName")
    if !IsObject(listCtrl) {
        return
    }
    pipe := LoadAllPresetString()
    MainSetListBox(listCtrl, pipe)
    gAutoPresetsSelectedPreset := AutoPresetsResolveSelectedPreset()
    if (gAutoPresetsSelectedPreset != "") {
        idx := 0
        for i, txt in StrSplit(pipe, "|") {
            if (txt = gAutoPresetsSelectedPreset) {
                idx := i
                break
            }
        }
        if (idx > 0) {
            MainPresetListSafeChoose(listCtrl, idx, pipe)
        }
    }
    if IsObject(nameCtrl) {
        nameCtrl.Text := gAutoPresetsSelectedPreset
    }
}

AutoPresetsOnPresetListChange(*) {
    global gAutoPresetsSelectedPreset
    listCtrl := AutoPresetsGetCtrl("AutoPresetPresetList")
    nameCtrl := AutoPresetsGetCtrl("AutoPresetSelectedName")
    if !IsObject(listCtrl) {
        return
    }
    presetName := Trim(listCtrl.Text)
    if (presetName = "") {
        return
    }
    gAutoPresetsSelectedPreset := presetName
    if IsObject(nameCtrl) {
        nameCtrl.Text := presetName
    }
    AutoPresetsRefreshEnableCheckbox()
    AutoPresetsSyncSkillIconList()
}

AutoPresetsRefreshEnableCheckbox() {
    v := AutoPresets_LoadEnabledGlobal() ? 1 : 0
    c := AutoPresetsGetCtrl("AutoPresetsEnableVisible")
    if IsObject(c) {
        c.Value := v
    }
}

AutoPresetsRefreshSkillPreview() {
    pic := AutoPresetsGetCtrl("SkillPreview")
    if !IsObject(pic) {
        return
    }
    item := AutoPresetsResolveSelectedSkillItem()
    path := IsObject(item) ? item["path"] : ""
    pic.Value := ""
    AutoPresetsLockSkillPreview(pic)
    if (path != "" && FileExist(path)) {
        tmp := AutoPresetsSkillIcon_FitPreviewTempPath()
        if AutoPresetsSkillIcon_RenderFitPreviewToFile(path, AutoPresetsLayout.PreviewWidth(), AutoPresetsLayout.PreviewHeight(), tmp) && FileExist(tmp) {
            pic.Value := tmp
        } else {
            pic.Value := path
        }
        AutoPresetsLockSkillPreview(pic)
    }
}

AutoPresetsRefreshChatPreview() {
    global gAutoPresetsSelectedChatPath
    picT := AutoPresetsGetCtrl("ChatPreview")
    if !IsObject(picT) {
        return
    }
    picT.Value := ""
    AutoPresetsLockChatPreview(picT)
    p := ""
    key := AutoPresetsResolveSelectedResolution()
    if (key != "") {
        cand := AutoPresetsChatIconPathForResolution(key)
        if (cand != "" && FileExist(cand)) {
            p := cand
        }
    }
    gAutoPresetsSelectedChatPath := p
    if (p != "") {
        tmp := A_Temp "\DAF_chat_fit_preview.png"
        if AutoPresetsSkillIcon_RenderFitPreviewToFile(p, AutoPresetsLayout.ChatPreviewWidth(), AutoPresetsLayout.ChatPreviewHeight(), tmp) && FileExist(tmp) {
            picT.Value := tmp
        } else {
            picT.Value := p
        }
        AutoPresetsLockChatPreview(picT)
    }
}

AutoPresetsAfterRegionPick(kind) {
    global gAutoPresetsGui, gAutoPresetsSelectedSkillId
    if IsObject(gAutoPresetsGui) && WinExist("ahk_id " gAutoPresetsGui.Hwnd) {
        AutoPresetsRefreshChatPreview()
        if (kind = "skill") {
            item := AutoPresetsResolveSelectedSkillItem()
            if IsObject(item) {
                AutoPresetsSkillIcon_UpdateForPreset(AutoPresetsResolveSelectedPreset(), item["id"], AutoPresetsResolveSelectedResolution())
            }
            AutoPresetsSyncSkillIconList(gAutoPresetsSelectedSkillId)
        } else if (kind = "chat") {
            try AutoPresetsApplyCapturedChat(AutoPresetsChatIcon_UpdateForResolution(AutoPresetsResolveSelectedResolution()))
            catch Error as e {
                MsgBox(e.Message,, "Icon!")
            }
        }
    }
}

AutoPresetsLoadToGui() {
    global gAutoPresetsSelectedPreset
    gAutoPresetsSelectedPreset := GetNowSelectPreset()
    AutoPresetsSyncPresetList()
    hk := Trim(LoadConfig("AutoPresetHotkey", " "))
    if (hk = " ") {
        hk := ""
    }
    AutoPresetsGetCtrl("AutoPresetHotkey").Text := hk
    AutoPresetsRefreshEnableCheckbox()
    AutoPresetsApplyMatchStrictUi(AutoPresets_LoadMatchStrict())
    AutoPresetsGetCtrl("AutoPresetRecognizeSeconds").Text := AutoPresets_LoadRecognizeSeconds()
    AutoPresetsSyncResolutionList()
    AutoPresetsRefreshChatPreview()
}

AutoPresetsApplyMatchStrictUi(v) {
    v := AutoPresets_ClampMatchStrict(v)
    slider := AutoPresetsGetCtrl("MatchStrict")
    if IsObject(slider) {
        slider.Value := v
    }
    lbl := AutoPresetsGetCtrl("MatchStrictValue")
    if IsObject(lbl) {
        lbl.Text := v "%"
    }
}

AutoPresetsSaveMatchStrictFromUi() {
    slider := AutoPresetsGetCtrl("MatchStrict")
    v := AutoPresets_MatchStrictDefault()
    if IsObject(slider) {
        v := AutoPresets_ClampMatchStrict(slider.Value)
    }
    AutoPresetsApplyMatchStrictUi(v)
    SaveConfig("AutoPresetMatchStrict", v)
    return v
}

AutoPresetsMatchStrictOnChange(*) {
    AutoPresetsSaveMatchStrictFromUi()
}

AutoPresetsSaveRecognizeSecondsFromUi() {
    ctrl := AutoPresetsGetCtrl("AutoPresetRecognizeSeconds")
    v := AutoPresets_RecognizeSecondsDefault()
    if IsObject(ctrl) {
        v := AutoPresets_ClampRecognizeSeconds(ctrl.Text)
        ctrl.Text := v
    }
    SaveConfig("AutoPresetRecognizeSeconds", v)
    return v
}

AutoPresetsSyncEnableFromUi(*) {
    v := AutoPresetsGetCtrl("AutoPresetsEnableVisible").Value ? 1 : 0
    SaveConfig("AutoPresetsEnabled", v)
    m := MainGetCtrl("AutoPresets")
    if IsObject(m) {
        m.Value := v
    }
    AutoPresets_RefreshSessionRuntime()
}

ShowGuiAutoPresets(*) {
    global gMainGui, gAutoPresetsGui, gAutoPresetsLayout
    if IsObject(gMainGui) {
        gAutoPresetsGui.Opt("+Owner" gMainGui.Hwnd)
    }
    gAutoPresetsGui.Title := AutoPresetsText["SectionTitle"]
    AutoPresetsLoadToGui()
    gAutoPresetsGui.Show("w" gAutoPresetsLayout.Width(windowW) " h" gAutoPresetsLayout.Height())
    DisableGuiMain()
}

HideGuiAutoPresets() {
    global gAutoPresetsGui
    PresetRegionPickCommitIfOpen()
    gAutoPresetsGui.Hide()
    EnableGuiMain()
}

AutoPresetsGuiEscape(*) {
    AutoPresetsGuiSave()
}

AutoPresetsGuiClose(*) {
    AutoPresetsGuiSave()
}

AutoPresetsGuiSave(*) {
    PresetRegionPickCommitIfOpen()
    hk := Trim(UiPressKeyEdit_Value(AutoPresetsGetCtrl("AutoPresetHotkey")))
    SaveConfig("AutoPresetHotkey", hk)
    v := AutoPresetsGetCtrl("AutoPresetsEnableVisible").Value ? 1 : 0
    SaveConfig("AutoPresetsEnabled", v)
    m := MainGetCtrl("AutoPresets")
    if IsObject(m) {
        m.Value := v
    }
    AutoPresetsSaveMatchStrictFromUi()
    AutoPresetsSaveRecognizeSecondsFromUi()
    HideGuiAutoPresets()
    AutoPresets_RefreshSessionRuntime()
}

AutoPresetsHelp(*) {
    UiHelpMsgBox(AutoPresetsText["Help"], AutoPresetsText["HelpTitle"])
}

AutoPresetsUpdateSkillIcon(*) {
    PresetRegionPickCommitIfOpen()
    try {
        resKey := AutoPresetsResolveSelectedResolution()
        added := AutoPresetsSkillIcon_Add(AutoPresetsResolveSelectedPreset(), resKey)
        AutoPresetsSyncSkillIconList(added["id"])
    } catch Error as e {
        MsgBox(e.Message,, "Icon!")
    }
}

AutoPresetsDeleteSkillIcon(*) {
    name := AutoPresetsResolveSelectedPreset()
    item := AutoPresetsResolveSelectedSkillItem()
    if (name = "" || !IsObject(item)) {
        return
    }
    resKey := AutoPresetsResolveSelectedResolution()
    AutoPresetsSkillIcon_Delete(name, item["id"], resKey)
    AutoPresetsSyncSkillIconList()
}

AutoPresetsRenameSkillIcon(*) {
    name := AutoPresetsResolveSelectedPreset()
    item := AutoPresetsResolveSelectedSkillItem()
    if (name = "" || !IsObject(item)) {
        return
    }
    ret := InputBox(AutoPresetsText["RenameSkillIconPrompt"], AutoPresetsText["RenameSkillIconTitle"], "w280 h130", item["name"])
    if (ret.Result != "OK") {
        return
    }
    newName := Trim(ret.Value)
    if (newName = "") {
        return
    }
    if !AutoPresetsSkillIcon_Rename(name, item["id"], newName, AutoPresetsResolveSelectedResolution()) {
        return
    }
    AutoPresetsSyncSkillIconList(item["id"])
}

AutoPresetsCaptureResolution(*) {
    try {
        key := AutoPresetsResolutionKey()
        if (key = "") {
            throw Error("未找到 DNF 游戏窗口，无法截取分辨率。")
        }
        AutoPresets_AddResolutionKey(key)
        AutoPresetsSyncResolutionList(key)
    } catch Error as e {
        MsgBox(e.Message,, "Icon!")
    }
}

AutoPresetsDeleteResolution(*) {
    global gAutoPresetsSelectedResolution
    key := gAutoPresetsSelectedResolution
    if (key = "") {
        return
    }
    AutoPresets_RemoveResolutionKey(key)
    dir := AutoPresetsSkillResolutionDir(key)
    if (dir != "" && DirExist(dir)) {
        try DirDelete(dir, true)
    }
    chatPath := AutoPresetsChatIconPathForResolution(key)
    if (chatPath != "" && FileExist(chatPath)) {
        try FileDelete(chatPath)
    }
    gAutoPresetsSelectedResolution := ""
    AutoPresetsSyncResolutionList()
}

AutoPresetsApplyCapturedChat(path) {
    global gAutoPresetsSelectedChatPath
    gAutoPresetsSelectedChatPath := path
    AutoPresetsRefreshChatPreview()
    if AutoPresets_IsSessionRunning() {
        AutoPresets_StartChatWatch()
    }
}

AutoPresetsCaptureChatIcon(*) {
    PresetRegionPickCommitIfOpen()
    try {
        AutoPresetsApplyCapturedChat(AutoPresetsChatIcon_UpdateForResolution(AutoPresetsResolveSelectedResolution()))
    } catch Error as e {
        MsgBox(e.Message,, "Icon!")
    }
}

AutoPresetsDeleteChatIcon(*) {
    global gAutoPresetsSelectedChatPath, gAutoPresetsSelectedResolution
    path := ""
    key := gAutoPresetsSelectedResolution
    if (key != "") {
        path := AutoPresetsChatIconPathForResolution(key)
    }
    if (path = "" || !FileExist(path)) {
        path := gAutoPresetsSelectedChatPath
    }
    if (path = "" || !FileExist(path)) {
        return
    }
    try FileDelete(path)
    gAutoPresetsSelectedChatPath := ""
    AutoPresetsRefreshChatPreview()
    if AutoPresets_IsSessionRunning() {
        AutoPresets_StartChatWatch()
    }
}

#Include ./AutoPresetsRegionPick.ahk
