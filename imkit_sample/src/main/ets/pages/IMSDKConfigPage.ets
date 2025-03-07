/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { CommonChooseDialog, NavigationBackBuilder, NECommonUtils } from '@nimkit/common'
import { AppConfig } from '../constants/AppConfig'
import { IMSDKConfigManager, IMSDKConfigModel } from '../manager/IMSDKConfigManager'
import { JSON } from '@kit.ArkTS'


@Entry
@ComponentV2
struct IMSDKConfigPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local isAutoParsing: boolean = true
  @Local modeDesc: ResourceStr = $r('app.string.login_config_mode_auto')
  configModel: IMSDKConfigModel = IMSDKConfigManager.getConfig() ?? new IMSDKConfigModel()
  inputAppKey: string = AppConfig.appKey
  inputEncrypt?: boolean
  inputLinkArr?: string
  inputLBSArr?: string[]
  inputCustomClientType?: number
  inputCustomTag?: string
  inputHttps?: boolean
  inputCertificateName?: string
  inputNOSDownloadArr?: string
  inputDownloadReplaceFormat?: string
  inputNOSUploadArr?: string
  inputUploadReplaceFormat?: string
  inputJsonData?: string
  onSwitchChange = (isOn: boolean) => {
    this.configModel.enableCustomConfig = isOn
  }
  saveAction = () => {
    try {
      if (this.isAutoParsing && this.inputJsonData && this.inputJsonData.length > 0) {
        let data = JSON.parse(this.inputJsonData) as object
        if (data) {
          this.inputAppKey = data['appKey'] as string
          this.inputEncrypt = (data['encrypt'] as string) === 'true' ? true : false
          this.inputLinkArr = data['linkUrl'] as string
          this.inputLBSArr = [data['lbsUrls'] as string]
          this.inputCustomClientType = data['customClientType'] as number
          this.inputCustomTag = data['customTag'] as string
          this.inputHttps = (data['https'] as string) === 'true' ? true : false
          this.inputCertificateName = data['harmonyCertificateName'] as string
          this.inputNOSDownloadArr = data['downloadHost'] as string
          this.inputDownloadReplaceFormat = data['downloadReplaceFormat'] as string
          this.inputNOSUploadArr = data['chunkUploadHost'] as string
          this.inputUploadReplaceFormat = data['uploadReplaceFormat'] as string
        }
      }
    } catch (err) {
      console.error(err)
      NECommonUtils.showToast($r('app.string.login_config_illegal'))
      return
    }

    this.configModel.configOptions = {
      loginServiceConfig: {
        lbsUrls: this.inputLBSArr,
        linkUrl: this.inputLinkArr,
        customClientType: this.inputCustomClientType,
        customTag: this.inputCustomTag,
        isHttps: this.inputHttps
      },
      storageServiceConfig: {
        downloadHost: this.inputNOSDownloadArr,
        downloadReplaceFormat: this.inputDownloadReplaceFormat
      },
      httpServiceConfig: {
        chunkUploadHost: this.inputNOSUploadArr,
        uploadReplaceFormat: this.inputUploadReplaceFormat
      },
      pushServiceConfig: {
        harmonyCertificateName: this.inputCertificateName
      },
      databaseServiceConfig: {
        encrypt: this.inputEncrypt,
        appKey: this.inputAppKey,
      }
    }
    IMSDKConfigManager.saveConfig(this.configModel)
    NECommonUtils.showToast($r('app.string.login_config_save_success'))
    this.pathStack.pop(true)
  }
  chooseModeDialog: CustomDialogController = new CustomDialogController({
    builder: CommonChooseDialog({
      content1: $r('app.string.login_config_mode_auto'),
      content2: $r('app.string.login_config_mode_manually'),
      onItemChosen: (index) => {
        this.isAutoParsing = index === 1
        this.modeDesc =
          index === 1 ? $r('app.string.login_config_mode_auto') : $r('app.string.login_config_mode_manually')
      }
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
    height: 140,
  })

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.login_privatized_cloud_configuration'),
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Scroll() {
          Column() {
            Row() {
              Text($r('app.string.login_config_effect'))
                .margin({ left: 16 })
              Blank().layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.configModel?.enableCustomConfig })
                .selectedColor("#337EFF")
                .width(46)
                .height(28)
                .margin({ right: 16 })
                .onChange(this.onSwitchChange)
            }
            .borderRadius(8)
            .backgroundColor(Color.White)
            .height(49)
            .margin({
              right: 20,
              left: 20
            })

            Text($r('app.string.login_config'))
              .backgroundColor(Color.Transparent)
              .textAlign(TextAlign.Start)
              .width('90%')
              .margin({
                top: 20,
                left: 32
              })

            Column() {
              Row() {
                Text($r('app.string.login_config_mode'))
                  .margin({ left: 16 })
                Blank().layoutWeight(1)
                Text(this.modeDesc)
                  .margin({ left: 5 })
                Image($r('app.media.arrow_right'))
                  .width(4.92)
                  .height(9.54)
                  .margin({
                    left: 5,
                    right: 16
                  })
              }
              .height(49)
              .onClick(() => {
                this.chooseModeDialog.open()
              })

              Divider()
                .color('#999999')
                .margin({
                  left: 16
                })

              if (this.isAutoParsing) {
                Text($r('app.string.login_config_content'))
                  .width('90%')
                  .height(49)

                TextArea({
                  text: this.inputJsonData
                })
                  .borderColor('#CCCCCC')
                  .borderWidth(1)
                  .margin({
                    left: 16,
                    right: 16,
                    bottom: 10
                  })
                  .height(200)
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputJsonData = value
                  })
              } else {
                Text($r('app.string.login_config_appKey'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputAppKey = value
                  })

                Text($r("app.string.login_config_encrypt", '(true/false)'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputEncrypt = value === 'true' ? true : false
                  })

                Text($r('app.string.login_config_link'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputLinkArr = value
                  })

                Text($r('app.string.login_config_lbs'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputLBSArr = [value]
                  })

                Text($r("app.string.login_config_custom_client_type", '(>0)'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .type(InputType.Number)
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputCustomClientType = Number(value)
                  })

                Text($r("app.string.login_config_custom_tag"))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputCustomTag = value
                  })

                Text($r("app.string.login_config_https", '(true/false)'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputHttps = value === 'true' ? true : false
                  })

                Text($r("app.string.login_config_certificate_name"))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputCertificateName = value
                  })

                Text($r('app.string.login_config_nos_download'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputNOSDownloadArr = value
                  })

                Text($r('app.string.login_config_nos_download_replaceFormat'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputDownloadReplaceFormat = value
                  })

                Text($r('app.string.login_config_nos_upload'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16,
                    bottom: 10
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputNOSUploadArr = value
                  })

                Text($r('app.string.login_config_nos_upload_replaceFormat'))
                  .width('90%')
                  .height(49)
                TextInput({
                  placeholder: $r('app.string.login_config_input')
                })
                  .borderRadius(8)
                  .borderWidth(1)
                  .borderColor('#CCCCCC')
                  .backgroundColor(Color.White)
                  .placeholderColor('#CCCCCC')
                  .margin({
                    left: 16,
                    right: 16,
                    bottom: 10
                  })
                  .onChange((value: string, previewText?: PreviewText) => {
                    this.inputUploadReplaceFormat = value
                  })
              }
            }
            .borderRadius(8)
            .backgroundColor(Color.White)
            .margin({
              top: 10,
              right: 20,
              left: 20
            })

            Button($r('app.string.save'))
              .backgroundColor(0x337EFF)
              .width('90%')
              .margin({
                top: 20,
                left: 20,
                right: 20
              })
              .onClick(this.saveAction)
          }
        }
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
        .height('100%')
        .padding({
          bottom: 400
        })
      }
    }
    .backgroundColor('#EFF1F4')
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    })
  }
}

@Builder
export function IMSDKConfigPageBuilder() {
  IMSDKConfigPage()
}