#Requires AutoHotkey v2.0

global LongZhanText := Map(
    "SectionTitle", "龙战识别",
    "Enable", "启动龙战识别",
    "ToggleHotkey", "开关快捷键",
    "TipOn", "龙战识别已开启",
    "TipOff", "龙战识别已关闭",
    "PresetList", "配置列表",
    "SkillKey", "主动技能按键",
    "PickRegion", "龙战识别区域",
    "ResolutionList", "分辨率列表",
    "Capture", "截取",
    "Delete", "删除",
    "Save", "保存",
    "ResetRegionConfirmTitle", "重新设置识别区域",
    "ResetRegionConfirm", "多分辨率无需重新设置识别区域，直接重新截图即可。`n`n调整识别区域会导致之前截的图全部失效。",
    "ResetRegionConfirmAction", "重新设置识别区域",
    "Cancel", "取消",
    "HelpTitle", "龙战识别说明",
    "Help", "启动连发后，在 DNF 窗口内持续识别左下角龙战能量条。`n`n框选整条能量条（含龙头）。主动技能按键按首页配置列表分别绑定，切换配置或自动识别切角色后使用对应按键。需要你先自己按一次主动，等能量条出现后才会接管：掉到只剩蓝色（约 50%）时自动按一次补满。能量条整条消失后不再按键召回。`n`n启动开关、开关快捷键和识别区域为全局；主动技能按键随配置走。开关快捷键支持 Ctrl/Alt/Shift 组合键。连发运行时按该快捷键可开/关龙战识别：游戏窗口可见时在客户区右下角提示，游戏隐藏或最小化时在桌面右下角提示。"
)
