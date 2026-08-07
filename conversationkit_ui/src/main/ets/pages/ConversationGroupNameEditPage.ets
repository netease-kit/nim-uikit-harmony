/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils } from '@nimkit/chatkit'
import { NavigationBackBuilder, NECommonUtils } from '@nimkit/common'
import { V2NIMError } from '@nimsdk/base'
import {
  CONVERSATION_GROUP_NAME_MAX_LENGTH,
  isConversationGroupLimitError,
  normalizeConversationGroupName
} from '../model/ConversationGroupModel'
import {
  ConversationGroupNameEditMode,
  ConversationGroupRouteParam
} from '../model/ConversationGroupRouteParam'
import { ConversationGroupViewModel } from '../viewmodel/ConversationGroupViewModel'

@ComponentV2
export struct ConversationGroupNameEditPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel?: ConversationGroupViewModel = undefined
  @Local routeParam: ConversationGroupRouteParam = new ConversationGroupRouteParam()
  @Local groupName: string = ''
  @Local title: ResourceStr = $r('app.string.conversation_group_create_title')

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: this.title,
          rightButtonTitle: $r('app.string.conversation_group_done'),
          rightButtonColor: '#337EFF',
          rightButtonAction: () => {
            this.saveGroupName()
          },
          backgroundColor: '#EFF1F4',
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        TextInput({
          text: this.groupName,
          placeholder: $r('app.string.conversation_group_name_placeholder')
        })
          .fontSize(16)
          .fontColor('#1F2329')
          .height(50)
          .margin({ left: 20, right: 20, top: 12 })
          .padding({ left: 16, right: 16 })
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
          .maxLength(CONVERSATION_GROUP_NAME_MAX_LENGTH)
          .showCounter(true, {
            thresholdPercentage: 1
          })
          .onChange((value: string) => {
            this.groupName = value
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#EFF1F4')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const params = this.pathStack.getParamByName('ConversationGroupNameEditPage') as ConversationGroupRouteParam[]
      const param = params[0]
      if (param !== undefined) {
        this.routeParam = param
        this.viewModel = param.groupViewModel
        this.groupName = param.group?.name ?? ''
        this.title = param.editMode === ConversationGroupNameEditMode.RENAME ?
          $r('app.string.conversation_group_rename_title') :
          $r('app.string.conversation_group_create_title')
      }
    })
  }

  private async saveGroupName(): Promise<void> {
    const viewModel = this.viewModel
    if (viewModel === undefined) {
      this.pathStack.pop()
      return
    }
    const name = normalizeConversationGroupName(this.groupName)
    if (name.length <= 0) {
      NECommonUtils.showToast($r('app.string.conversation_group_name_empty_tips'))
      this.groupName = ''
      return
    }
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    try {
      if (this.routeParam.editMode === ConversationGroupNameEditMode.RENAME &&
        this.routeParam.group?.groupId !== undefined) {
        await viewModel.updateConversationGroup(this.routeParam.group.groupId, name)
      } else {
        await viewModel.createConversationGroup(name)
      }
      this.pathStack.pop(name)
    } catch (e) {
      if (isConversationGroupLimitError(e as V2NIMError)) {
        NECommonUtils.showToast($r('app.string.conversation_group_limit_tips'))
      } else {
        NECommonUtils.showToast($r('app.string.conversation_group_save_failed'))
      }
    }
  }
}

@Builder
export function ConversationGroupNameEditPageBuilder() {
  ConversationGroupNameEditPage()
}
