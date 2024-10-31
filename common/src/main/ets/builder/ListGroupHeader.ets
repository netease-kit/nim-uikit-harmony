// 自定义组件groupHeader，作为ListItemGroup的头部组件，即A、B、C等字母列表项
@Builder
export function ListGroupHeader(titleLetter: ResourceStr) {
  Column() {
    Text(titleLetter)
      .fontColor('#B3B7BC')
      .fontSize(14)
      .backgroundColor(Color.White)
      .width('100%')
      .margin({ top: 16, left: 40 })

    Row()
      .height(1)
      .width('100%')
      .backgroundColor('#DBE0E8')
      .margin({ top: 8, left: 40 })
  }
  .width('100%')
  .height(56)
  .backgroundColor(Color.White)
}