/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationRepo, ErrorUtils } from '@nimkit/chatkit'
import { V2NIMConversation } from '@nimsdk/base'

@CustomDialog
export struct ConversationOperationDialog {
  @State conversationInfo: V2NIMConversation | null = null
  private controller: CustomDialogController = new CustomDialogController({
    builder: ConversationOperationDialog(),
  })

  build() {
    if (this.conversationInfo != null) {
      Column({ space: 10 }) {
        if (this.conversationInfo.stickTop) {
          Text($r('app.string.unstick_top_conversation'))
            .fontSize(16)
            .fontColor('#333333')
            .onClick(() => {
              if (ErrorUtils.checkNetworkAndToast()) {
                ConversationRepo.stickTopConversation(this.conversationInfo?.conversationId ?? '', false)
              }
              this.controller.close()
            })
            .height(30)
            .width('100%')
            .margin({ top: 15 })
            .textAlign(TextAlign.Center)
        } else {
          Text($r('app.string.stick_top_conversation'))
            .fontSize(16)
            .fontColor('#333333')
            .onClick(() => {
              if (ErrorUtils.checkNetworkAndToast()) {
                ConversationRepo.stickTopConversation(this.conversationInfo?.conversationId ?? '', true)
              }
              this.controller.close()
            })
            .height(30)
            .width('100%')
            .margin({ top: 15 })
            .textAlign(TextAlign.Center)
        }
        Line().height(1).backgroundColor('#EFF1F4').width('100%').opacity(0.5)
        Text($r('app.string.delete_conversation'))
          .fontSize(16)
          .fontColor('#333333')
          .onClick(() => {
            if (ErrorUtils.checkNetworkAndToast()) {
              ConversationRepo.deleteConversation(this.conversationInfo?.conversationId ?? '')
            }
            this.controller.close()
          })
          .height(30)
          .width('100%')
          .margin({ bottom: 15 })
          .textAlign(TextAlign.Center)
      }.width('100%').backgroundColor($r('sys.color.white'))
    }
  }
}