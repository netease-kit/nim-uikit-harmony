/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils, UserAIBotRepo } from '@nimkit/chatkit';
import { NavigationBackBuilder, NECommonUtils } from '@nimkit/common';

export class EditBotNameParam {
  accid: string
  name: string
  icon: string
  /** 仅输入模式：点完成只返回名称，不调服务端接口 */
  inputOnly: boolean

  constructor(accid: string, name: string, icon: string, inputOnly: boolean = false) {
    this.accid = accid
    this.name = name
    this.icon = icon
    this.inputOnly = inputOnly
  }
}

@Builder
export function EditBotNamePageBuilder() {
  EditBotNamePage()
}

@ComponentV2
export struct EditBotNamePage {
  pathStack: NavPathStack = new NavPathStack()
  @Local content: string = ''
  @Local isSubmitting: boolean = false
  private accid: string = ''
  private icon: string = ''
  private originalName: string = ''
  private inputOnly: boolean = false
  private maxLength: number = 15

  private async doSave(): Promise<void> {
    const trimmed = this.content.trim()
    if (trimmed.length <= 0 || this.isSubmitting) return
    // 没有修改，直接返回
    if (trimmed === this.originalName) {
      this.pathStack.pop()
      return
    }
    // 仅输入模式：直接返回名称，不调接口
    if (this.inputOnly) {
      this.pathStack.pop(trimmed)
      return
    }
    if (!ErrorUtils.checkNetworkAndToast()) return
    this.isSubmitting = true
    try {
      console.info('[EditBotNamePage] doSave start, accid=' + this.accid + ', name=' + trimmed)
      await UserAIBotRepo.updateUserAIBot({
        accid: this.accid,
        name: trimmed,
        icon: this.icon.length > 0 ? this.icon : undefined
      })
      console.info('[EditBotNamePage] doSave success')
      NECommonUtils.showToast($r('app.string.bot_update_success'))
      const result: Record<string, string> = {
        'accid': this.accid,
        'name': trimmed,
        'icon': this.icon
      }
      this.pathStack.pop(result)
    } catch (err) {
      console.error('[EditBotNamePage] doSave error: ' + JSON.stringify(err))
      NECommonUtils.showToast($r('app.string.bot_create_fail'))
    } finally {
      this.isSubmitting = false
    }
  }

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.bot_name'),
        rightButtonTitle: $r('app.string.mine_info_save'),
        rightButtonColor: this.content.trim().length > 0 ? '#337EFF' : '#CCCCCC',
        rightButtonAction: (): void => {
          console.info('[EditBotNamePage] rightButton clicked, content=' + this.content + ', accid=' + this.accid + ', isSubmitting=' + this.isSubmitting)
          const trimmed = this.content.trim()
          console.info('[EditBotNamePage] trimmed=' + trimmed + ', originalName=' + this.originalName + ', equal=' + (trimmed === this.originalName))
          if (trimmed.length <= 0 || this.isSubmitting) {
            console.info('[EditBotNamePage] blocked by length or isSubmitting')
            return
          }
          if (trimmed === this.originalName) {
            console.info('[EditBotNamePage] no change, pop directly')
            this.pathStack.pop()
            return
          }
          console.info('[EditBotNamePage] checkNetwork=' + ErrorUtils.checkNetworkAndToast())
          this.doSave()
        },
        backgroundColor: '#EFF1F4',
        leftButtonAction: (): void => {
          this.pathStack.pop()
        }
      })

      TextInput({ text: this.content })
        .fontSize(16)
        .fontColor('#333333')
        .height(50)
        .margin({ left: 20, right: 20 })
        .backgroundColor(Color.White)
        .borderRadius(8)
        .cancelButton({
          style: CancelButtonStyle.INPUT,
          icon: {
            src: $r('app.media.input_clean'),
            size: 16,
            color: '#B3B7BC'
          }
        })
        .maxLength(this.maxLength)
        .type(InputType.Normal)
        .showCounter(true, {
          thresholdPercentage: 1
        })
        .onChange((value: string) => {
          this.content = value
        })
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const param = this.pathStack.getParamByName('EditBotNamePage')[0] as EditBotNameParam
      if (param) {
        this.accid = param.accid
        this.content = param.name
        this.icon = param.icon
        this.originalName = param.name
        this.inputOnly = param.inputOnly
      }
    })
  }
}