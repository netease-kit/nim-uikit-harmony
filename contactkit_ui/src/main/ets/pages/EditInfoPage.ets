/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ContactRepo, ErrorUtils } from '@nimkit/chatkit';
import { NavigationBackBuilder, NECommonUtils } from '@nimkit/common';
import { EditType } from '../model/MineInfoItem';

export class EditInfoParam {
  title?: ResourceStr
  content?: ResourceStr
  accountId?: ResourceStr
  editType?: EditType

  constructor(title?: ResourceStr,
    content?: ResourceStr,
    editType?: EditType,
    accountId?: ResourceStr) {
    this.title = title
    this.content = content
    this.editType = editType
    this.accountId = accountId
  }
}

@ComponentV2
export struct EditTextInput {
  @Param content: string | undefined = undefined;
  @Param maxLength: number = 0;
  @Param type: InputType = InputType.Normal;
  @Param onTextChange?: (value: string) => void = undefined

  build() {
    TextInput({ text: this.content })
      .fontSize(16)
      .fontColor("#333333")
      .height(50)
      .margin({ left: 20, right: 20 })
      .backgroundColor(Color.White)
      .borderRadius(8)
      .cancelButton({
        style: CancelButtonStyle.INPUT,
        icon: {
          src: $r('app.media.input_clean'),
          size: 16,
          color: "#B3B7BC"
        }
      })
      .maxLength(this.maxLength)
      .type(this.type)
      .showCounter(true, {
        thresholdPercentage: 1
      })
      .onChange((value: string) => {
        this.onTextChange?.(value)
      })
  }
}

// 跳转页面入口函数
@Builder
export function EditInfoPageBuilder() {
  EditInfoPage()
}

@ComponentV2
export struct EditInfoPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local title?: ResourceStr = undefined
  @Local content?: string = undefined
  @Local editType?: EditType = undefined
  @Local accountId?: string = undefined
  @Local maxLength?: number = 0
  @Local showCleanButton: boolean = false
  // 【保存】按钮点击事件
  saveInfo = async () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      try {
        if (this.accountId) {
          /// 更改好友备注
          // 不支持全空格
          if (this.content && this.content?.length > 0 && this.content?.trim().length === 0) {
            NECommonUtils.showToast($r('app.string.all_space_not_support'))
            this.content = ""
            return
          }
          await ContactRepo.setFriendInfo(this.accountId, {
            alias: this.content
          })
        } else {
          /// 更改自己信息
          switch (this.editType) {
            case EditType.nick:
              if (this.content?.length === 0) {
                this.content = ChatKitClient.getLoginUserId()
              }
              ContactRepo.updateSelfUserProfile({
                name: this.content
              })
              break
            case EditType.mobile:
              ContactRepo.updateSelfUserProfile({
                mobile: this.content
              })
              break
            case EditType.email:
              ContactRepo.updateSelfUserProfile({
                email: this.content
              })
              break
            case EditType.sign:
              ContactRepo.updateSelfUserProfile({
                sign: this.content
              })
              break
            default:
              break
          }
        }
        NECommonUtils.showToast($r('app.string.mine_info_save_ok'))
        this.pathStack.pop(this.content)
      } catch (err) {
        console.error(err)
      }
    }
  }

  requestData(): void {
    const editInfoParam = this.pathStack.getParamByName("EditInfoPage")[0] as EditInfoParam
    this.title = editInfoParam.title
    this.content = editInfoParam.content?.toString()
    this.accountId = editInfoParam.accountId?.toString()
    this.editType = editInfoParam.editType

    switch (this.editType) {
      case EditType.nick || EditType.alias:
        this.maxLength = 15
        break
      case EditType.mobile:
        this.maxLength = 11
        break
      case EditType.email:
        this.maxLength = 30
        break
      case EditType.sign:
        this.maxLength = 50
        break
      default:
        break
    }
  }

  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: this.title,
        rightButtonTitle: $r('app.string.mine_info_save'),
        rightButtonColor: "#666666",
        rightButtonAction: this.saveInfo,
        backgroundColor: '#EFF1F4',
        leftButtonAction: () => {
          this.pathStack.pop()
        }
      })

      if (this.editType === EditType.nick || this.editType === EditType.alias) {
        EditTextInput({
          content: this.content,
          maxLength: this.maxLength,
          type: InputType.Normal,
          onTextChange: (value) => {
            this.content = value
          }
        })
      }

      if (this.editType === EditType.mobile) {
        EditTextInput({
          content: this.content,
          maxLength: this.maxLength,
          type: InputType.PhoneNumber,
          onTextChange: (value) => {
            this.content = value
          }
        })
      }

      if (this.editType === EditType.email) {
        EditTextInput({
          content: this.content,
          maxLength: this.maxLength,
          type: InputType.Email,
          onTextChange: (value) => {
            this.content = value
          }
        })
      }

      if (this.editType == EditType.sign) {
        Stack() {
          TextArea({ text: this.content, })
            .fontSize(16)
            .fontColor("#333333")
            .height(100)
            .margin({ left: 20, right: 20 })
            .backgroundColor(Color.White)
            .borderRadius(8)
            .maxLength(this.maxLength)
            .showCounter(true, {
              thresholdPercentage: 1
            })
            .onChange((value: string) => {
              this.content = value
              this.showCleanButton = value.length > 0
            })

          if (this.showCleanButton) {
            Image($r('app.media.input_clean'))
              .width(16)
              .height(16)
              .margin({
                top: 16,
                right: 36
              })
              .onClick(() => {
                this.content = ""
              })
          }
        }
        .alignContent(Alignment.End)
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }
}