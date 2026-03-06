/**
 * Usage
 *             CommonQuickSearchButton({
 icon: $r('app.media.icon_search_team_member'),
 text: $r('app.string.team_member'),
 onClick: () => {
 this.pathStack.push('SearchTeamMemberPage', [this.conversationId])
 }
 })
 */

@ComponentV2
export struct CommonQuickSearchButton {
  @Require
  @Param
  icon: Resource | string

  @Require
  @Param
  text: Resource | string

  @Param
  onClickHandler: () => void = () => {}

  @Param
  visible: Visibility = Visibility.Visible

  @Local
  localFillColor: string | Color = '#999999'

  @Local
  localBackgroundColor: string | Color = '#F3F4F6'

  @Local
  localFontColor: string | Color = Color.Gray

  /**
   * 宽度 25%，整体正方形，上面是 icon，下面是描述
   */
  build() {
    Column() {
      Row() {
        Image(this.icon)
          .width(24)  // 图标尺寸
          .height(24)
          .fillColor(this.localFillColor)  // 图标颜色（如果是SVG）
      }
      .width(48)  // 圆形背景尺寸
      .height(48)
      .backgroundColor(this.localBackgroundColor)  // 灰色背景
      .borderRadius(24)  // 圆形
      .justifyContent(FlexAlign.Center)  // 图标居中
      .alignItems(VerticalAlign.Center)
      .margin({ top: 10 })

      Text(this.text)
        .fontSize(12)
        .fontColor(this.localFontColor)
        .margin({ top: 12 })
    }
    .width('23%')
    .visibility(this.visible)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down || event.type === TouchType.Move) {
        this.localFillColor = '#3A80F4'
        this.localBackgroundColor = '#EAF1FA'
        this.localFontColor = '#3A80F4'
      } else {
        this.localFillColor = '#999999'
        this.localBackgroundColor = '#F3F4F6'
        this.localFontColor = Color.Gray
      }
    })
    .onClick(() => {
      this.onClickHandler()
    })
  }
}