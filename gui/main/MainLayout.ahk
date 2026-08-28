#Requires AutoHotkey v2.0

class MainLayout {
    static StandardMargin() => 16
    static GuiWidth() => MainKeyLayoutData.KeyboardWidth() + 32
    static GuiHeight() => this.BottomY() + 248
    static ButtonColumnX() => this.GuiWidth() - this.StandardMargin() - this.ButtonColumnWidth()
    static ButtonColumnWidth() => 96
    ; 与参考版一致：键盘区 + 顶部说明一行（主键连发间隔在下方「配置设置」右栏）
    static KeyPanelHeight() => MainKeyLayoutData.KeyboardHeight() + 22
    static BottomY() => 8 + this.KeyPanelHeight() + 12

    static ConfigHelpX() => 16
    static ConfigHelpY() => this.BottomY() + 6
    static ConfigHelpWidth() => 324
    static ConfigListTop() => this.BottomY() + 34
    static ConfigSectionBottom() => this.GuiHeight() - this.StandardMargin()
    static ConfigListHeight() => this.ConfigSectionBottom() - this.ConfigListTop()
    static ConfigListX() => 16
    static ConfigListWidth() => 150
    static ConfigFieldX() => 174
    static ConfigFieldWidth() => 140
    static ConfigFieldLabelHeight() => 24
    static ConfigFieldEditHeight() => 22
    static ConfigFieldGroupTop(index) {
        lt := this.ConfigListTop()
        switch index {
            case 1:
                return lt
            case 2:
                return lt + 50
            case 3:
                return lt + 100
            default:
                return lt
        }
    }
    static ConfigFieldLabelY(index) => this.ConfigFieldGroupTop(index)
    static ConfigFieldEditY(index) => this.ConfigFieldGroupTop(index) + this.ConfigFieldLabelHeight()

    static ExRowTop() => this.BottomY() + 34
    static ExRowHeight() => 34
    static ExLeftColumnX() => 334
    static ExRightColumnX() => 488
    static ExToggleWidth() => 40
    static ExLeftLinkWidth() => 104
    static ExRightLinkWidth() => 84

    static ActionButtonWidth() => this.ButtonColumnWidth()
    static ActionButtonCount() => 4
    static ActionButtonGap() => 6
    static ActionColumnTop() => this.BottomY() + 6
    static ActionColumnBottom() => this.GuiHeight() - this.StandardMargin()
    static ActionButtonHeight() {
        n := this.ActionButtonCount()
        avail := this.ActionColumnBottom() - this.ActionColumnTop()
        return Floor((avail - this.ActionButtonGap() * (n - 1)) / n)
    }
    static ActionButtonY(index) {
        return this.ActionColumnTop() + (index - 1) * (this.ActionButtonHeight() + this.ActionButtonGap())
    }
}

class SettingLayout {
    static Window() => UiContentLayout(0, 0)
    static TabWidth() => 400
    static TabHeight() => 300
}

class QuickSwitchLayout {
    static Window() => UiContentLayout(12, 14)
}
