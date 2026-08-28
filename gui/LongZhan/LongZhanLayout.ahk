#Requires AutoHotkey v2.0

class LongZhanLayout {
    static Window() => UiContentLayout(16, 24)
    static MarginX() => 16
    static WindowWidth() => this.ContentRight() + 16

    static ListWidth() => 120
    static PreviewGap() => 8
    static PreviewX() => this.MarginX() + this.ListWidth() + this.PreviewGap()
    static PreviewWidth() => 200
    static PreviewHeight() => 64
    static ContentRight() => this.PreviewX() + this.PreviewWidth()
    static ListHeight() => 120
    static PresetListHeight() => 120

    static EnableY() => 44
    static HotkeyY() => 78
    static PresetLabelY() => this.HotkeyY() + ExLayout.ControlHeight() + 12
    static PresetListY() => this.PresetLabelY() + 24
    static SkillKeyY() => this.PresetListY()
    static PickBtnY() => this.PresetListY() + this.PresetListHeight() + 12
    static MiddleY() => this.PickBtnY() + ExLayout.ControlHeight() + 16
    static ListY() => this.MiddleY() + 24
    static PreviewY() => this.ListY()
    static CaptureBtnY() => this.PreviewY() + this.PreviewHeight() + 12
    static SaveY() => Max(this.ListY() + this.ListHeight(), this.CaptureBtnY() + ExLayout.ControlHeight()) + 8
}
