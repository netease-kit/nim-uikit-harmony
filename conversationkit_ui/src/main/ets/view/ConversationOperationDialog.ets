/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationRepo } from '@nimkit/chatkit'
import { V2NIMConversation } from '@nimsdk/base'

@CustomDialog
export struct ConversationOperationDialog {
  @State conversationInfo: V2NIMConversation | null = null
  private controller: CustomDialogController = new CustomDialogController({
    builder: ConversationOperationDialog({}),
  })

  build() {
    if (this.conversationInfo != null) {
      Column({ space: 10 }) {
        if (this.conversationInfo.stickTop) {
          Text($r('app.string.unstick_top_conversation'))
            .fontSize(16)
            .fontColor('#222222')
            .onClick(() => {
              ConversationRepo.stickTopConversation(this.conversationInfo?.conversationId ?? '', false)
              this.controller.close()
            })
        } else {
          Text($r('app.string.stick_top_conversation'))
            .fontSize(16)
            .fontColor('#222222')
            .onClick(() => {
              ConversationRepo.stickTopConversation(this.conversationInfo?.conversationId ?? '', true)
              this.controller.close()
            })
        }
        Text($r('app.string.delete_conversation'))
          .fontSize(16)
          .fontColor('#222222')
          .onClick(() => {
            ConversationRepo.deleteConversation(this.conversationInfo?.conversationId ?? '')
            this.controller.close()
          })
      }.padding({ top: 10, bottom: 5 })
    }
  }
}