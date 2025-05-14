import { DeprecatedConfig } from "./DeprecatedConfig"

/**
 * @deprecated
 */
@ComponentV2
export struct DeprecatedIndexButton {
  @Param pathStack?: NavPathStack | undefined = undefined
  build() {
    Button($r('app.string.loginIMSDK'), { type: ButtonType.Normal, stateEffect: true })
      .alignSelf(ItemAlign.Center)
      .onClick(() => {
        this.pathStack?.pushPath({ name: "DeprecatedLoginPage", param: 'SDK' })
      })
      .borderRadius(10)
      .height(50)
      .width('90%')
      .backgroundColor(0x337EFF)
      .visibility(DeprecatedConfig.releaseAppKey ? Visibility.None : Visibility.Visible)
      .margin({ top: 10 })
  }
}