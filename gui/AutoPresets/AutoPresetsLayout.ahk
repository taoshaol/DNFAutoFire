#Requires AutoHotkey v2.0

class AutoPresetsLayout {
    ; 窗口与内容边界
    static Window() => UiContentLayout(16, 24)
    static MarginX() => 16
    static WindowWidth() => this.ContentRight() + 16

    ; 下部配置列表、技能图列表与右侧技能预览列
    static ListWidth() => 80
    static SkillIconListGap() => 4
    static SkillIconListX() => this.MarginX() + this.ListWidth() + this.SkillIconListGap()
    static SkillIconListWidth() => this.ListWidth()
    static RightGap() => 8
    static RightX() => this.SkillIconListX() + this.SkillIconListWidth() + this.RightGap()
    static RightWidth() => 120
    static ContentRight() => this.RightX() + this.RightWidth()
    static PreviewWidth() => 120
    static PreviewHeight() => 120
    static PreviewY() => this.ListY()

    ; 中部分辨率列表与聊天预览
    static ResolutionListWidth() => 120
    static PreviewColGap() => 52
    static PreviewColX() => this.MarginX() + this.ResolutionListWidth() + this.PreviewColGap()
    static ChatPreviewWidth() => 120
    static ChatPreviewHeight() => 48
    static ResolutionListX() => this.MarginX()
    static ResolutionListHeight() => 160
    static RowActionY() => this.PreviewY() + this.PreviewHeight() + 12

    ; 顶部启用开关、热键、严格标准与框选按钮
    static EnableY() => 44
    static HotkeyY() => 78
    static StrictY() => this.HotkeyY() + ExLayout.ControlHeight() + 10
    static PickBtnY() => this.StrictY() + 26

    ; 中部、下部和保存区的纵向位置
    static MiddleY() => this.PickBtnY() + ExLayout.ControlHeight() + 16
    static MiddlePreviewY() => this.MiddleY() + 16
    static ResolutionListY() => this.MiddlePreviewY()
    static ResolutionCaptureBtnY() => this.ResolutionListY() + this.ResolutionListHeight() + 8
    static ResolutionBtnY() => this.ResolutionCaptureBtnY() + ExLayout.ControlHeight() + 8
    static ChatY() => this.MiddlePreviewY()
    static ChatBtnY() => this.ChatY() + this.ChatPreviewHeight() + 8
    static LowerY() {
        leftBottom := this.ResolutionBtnY() + ExLayout.ControlHeight()
        rightBottom := this.ChatBtnY() + ExLayout.ControlHeight()
        return (leftBottom > rightBottom ? leftBottom : rightBottom) + 8
    }
    static ListY() => this.LowerY() + 24
    static ListHeight() => 160
    static SaveY() => this.ListY() + this.ListHeight() + 8
}
