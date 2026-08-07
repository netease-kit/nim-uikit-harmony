/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationIdUtilRepo, ErrorUtils } from '@nimkit/chatkit'
import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  NavigationBackBuilder,
  NECommonUtils
} from '@nimkit/common'
import { V2NIMConversation, V2NIMError } from '@nimsdk/base'
import {
  ConversationGroupInfo,
  isConversationGroupNotExistError,
  isConversationNotExistError
} from '../model/ConversationGroupModel'
import { ConversationGroupRouteParam } from '../model/ConversationGroupRouteParam'
import {
  CONVERSATION_GROUP_NAME_DIALOG_CONTAINER_HEIGHT,
  ConversationGroupNameDialog
} from '../view/ConversationGroupNameDialog'
import { ConversationGroupSelectConversationViewModel } from '../viewmodel/ConversationGroupSelectConversationViewModel'
import { ConversationGroupViewModel } from '../viewmodel/ConversationGroupViewModel'

const PAGE_BACKGROUND_COLOR: string = '#EFF1F4'
const PRIMARY_BLUE: string = '#337EFF'
const DANGER_RED: string = '#F24957'
const NAME_ROW_HEIGHT: number = 52
const SECTION_HEADER_HEIGHT: number = 40
const ADD_ROW_HEIGHT: number = 66
const MEMBER_ROW_HEIGHT: number = 66
const ROW_HORIZONTAL_PADDING: number = 20
const ACTION_TOUCH_SIZE: number = 40

@ComponentV2
export struct ConversationGroupSettingPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local groupViewModel?: ConversationGroupViewModel = undefined
  @Local group?: ConversationGroupInfo = undefined
  @Local groupName: string = ''
  @Local listViewModel: ConversationGroupSelectConversationViewModel =
    new ConversationGroupSelectConversationViewModel()
  private renameGroupDialog?: CustomDialogController = undefined

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.conversation_group_setting_title'),
          rightButtonTitle: $r('app.string.conversation_group_delete_short'),
          rightButtonColor: DANGER_RED,
          rightButtonAction: () => {
            this.showDeleteConfirm()
          },
          backgroundColor: PAGE_BACKGROUND_COLOR,
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        List() {
          ListItem() {
            this.groupNameItemBuilder(() => {
              this.openRenameDialog()
            })
          }

          ListItem() {
            this.sectionHeaderBuilder()
          }

          ListItem() {
            this.addConversationRowBuilder()
          }

          if (this.listViewModel.memberConversations.length <= 0 && !this.listViewModel.isLoadingMembers) {
            ListItem() {
              CommonEmptyResult({
                emptyImage: $r('app.media.no_history'),
                tips: $r('app.string.conversation_group_detail_empty')
              })
                .margin({ top: 80 })
            }
          } else {
            ForEach(this.listViewModel.memberConversations, (conversation: V2NIMConversation) => {
              ListItem() {
                this.memberRowBuilder(conversation)
              }
            }, (conversation: V2NIMConversation): string => {
              return `${conversation.conversationId}-${conversation.name ?? ''}-${conversation.unreadCount}`
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(PAGE_BACKGROUND_COLOR)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const params = this.pathStack.getParamByName('ConversationGroupSettingPage') as ConversationGroupRouteParam[]
      const param = params[0]
      if (param !== undefined) {
        this.groupViewModel = param.groupViewModel
        this.group = param.group
        this.groupName = param.group?.name ?? ''
        if (param.group?.groupId !== undefined) {
          this.listViewModel.initMembers(param.group.groupId)
        }
      }
    })
  }

  @Builder
  private groupNameItemBuilder(action: () => void) {
    Row() {
      Text($r('app.string.conversation_group_name_item'))
        .fontSize(16)
        .fontColor('#1F2329')
        .flexShrink(0)

      Text(this.groupName)
        .fontSize(15)
        .fontColor('#8A8F99')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .margin({ left: 12, right: 6 })

      Image($r('app.media.ic_conversation_group_detail_arrow'))
        .width(16)
        .height(16)
        .objectFit(ImageFit.Contain)
    }
    .height(NAME_ROW_HEIGHT)
    .width('100%')
    .padding({ left: ROW_HORIZONTAL_PADDING, right: ROW_HORIZONTAL_PADDING })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  private sectionHeaderBuilder() {
    Row() {
      Text($r('app.string.conversation_group_member_section'))
        .fontSize(13)
        .fontColor('#8A8F99')

      Text($r('app.string.conversation_group_member_section_count', this.listViewModel.memberConversations.length))
        .fontSize(13)
        .fontColor('#8A8F99')
    }
      .width('100%')
      .height(SECTION_HEADER_HEIGHT)
      .padding({ left: ROW_HORIZONTAL_PADDING, right: ROW_HORIZONTAL_PADDING })
      .backgroundColor(PAGE_BACKGROUND_COLOR)
      .alignItems(VerticalAlign.Center)
  }

  @Builder
  private addConversationRowBuilder() {
    Row() {
      Image($r('app.media.ic_conversation_group_detail_add'))
        .width(36)
        .height(36)
        .objectFit(ImageFit.Contain)

      Text($r('app.string.conversation_group_add_conversation'))
        .fontSize(16)
        .fontColor('#1F2329')
        .margin({ left: 12 })
    }
    .height(ADD_ROW_HEIGHT)
    .width('100%')
    .padding({ left: ROW_HORIZONTAL_PADDING, right: ROW_HORIZONTAL_PADDING })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openAddConversationPage()
    })
  }

  @Builder
  private memberRowBuilder(conversation: V2NIMConversation) {
    Row() {
      CommonAvatar({
        item: new AvatarItem(
          conversation.avatar,
          this.getAvatarShowName(conversation.name ?? this.getConversationTargetId(conversation)),
          AvatarColorUntil.getBackgroundColorById(this.getConversationTargetId(conversation))
        )
      })
        .width(42)
        .height(42)

      Column() {
        Text(conversation.name ?? this.getConversationTargetId(conversation))
          .fontSize(16)
          .fontColor('#1F2329')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .margin({ left: 12, right: 12 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      Stack() {
        Text($r('app.string.conversation_group_delete_short'))
          .fontSize(14)
          .fontColor(PRIMARY_BLUE)
          .width(54)
          .height(30)
          .borderRadius(15)
          .border({
            width: 1,
            color: PRIMARY_BLUE
          })
          .textAlign(TextAlign.Center)
      }
        .width(ACTION_TOUCH_SIZE + 24)
        .height(ACTION_TOUCH_SIZE)
        .alignContent(Alignment.Center)
        .onClick(() => {
          this.removeConversation(conversation)
        })
    }
    .height(MEMBER_ROW_HEIGHT)
    .width('100%')
    .padding({ left: ROW_HORIZONTAL_PADDING, right: ROW_HORIZONTAL_PADDING })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
  }

  private openRenameDialog(): void {
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    const groupViewModel = this.groupViewModel
    const group = this.group
    if (groupViewModel === undefined || group === undefined) {
      return
    }
    const dialog = new CustomDialogController({
      builder: ConversationGroupNameDialog({
        title: $r('app.string.conversation_group_rename_title'),
        initialName: this.groupName,
        onSubmitName: (name: string): Promise<void> => {
          return groupViewModel.updateConversationGroup(group.groupId, name)
        },
        onSubmitSuccess: (name: string): void => {
          this.groupName = name
          group.name = name
        },
        onSubmitError: (error: Error): void => {
          this.showSaveGroupNameError(error)
        },
        onDialogClose: () => {
          this.closeRenameGroupDialog()
        }
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
      backgroundBlurStyle: BlurStyle.NONE,
      keyboardAvoidMode: KeyboardAvoidMode.NONE,
      height: CONVERSATION_GROUP_NAME_DIALOG_CONTAINER_HEIGHT,
      width: '100%',
      autoCancel: false,
      openAnimation: {
        duration: 0,
        curve: Curve.Linear,
        playMode: PlayMode.Alternate
      },
      closeAnimation: {
        duration: 0,
        curve: Curve.Linear,
        playMode: PlayMode.Alternate
      }
    })
    this.renameGroupDialog = dialog
    this.renameGroupDialog.open()
  }

  private openAddConversationPage(): void {
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    const groupViewModel = this.groupViewModel
    const group = this.group
    if (groupViewModel === undefined || group === undefined) {
      return
    }
    this.pathStack.pushPath({
      name: 'ConversationGroupSelectConversationPage',
      param: new ConversationGroupRouteParam(groupViewModel, group),
      onPop: (popInfo: PopInfo) => {
        if (popInfo.result === true) {
          this.pathStack.pop(true)
          return
        }
        const addedConversations = popInfo.result as V2NIMConversation[] | undefined
        if (addedConversations !== undefined && addedConversations.length > 0) {
          this.listViewModel.appendMemberConversations(addedConversations)
          return
        }
        this.listViewModel.refreshMembers()
      }
    })
  }

  private closeRenameGroupDialog(): void {
    this.renameGroupDialog?.close()
    this.renameGroupDialog = undefined
  }

  private showSaveGroupNameError(error: Error): void {
    const v2Error = error as V2NIMError
    if (isConversationGroupNotExistError(v2Error)) {
      NECommonUtils.showToast($r('app.string.conversation_group_not_exist_tips'))
      this.closeRenameGroupDialog()
      this.pathStack.pop(true)
    } else {
      NECommonUtils.showToast($r('app.string.conversation_group_save_failed'))
    }
  }

  private showDeleteConfirm(): void {
    AlertDialog.show({
      title: $r('app.string.conversation_group_delete_title'),
      message: $r('app.string.conversation_group_delete_message'),
      autoCancel: true,
      buttons: [
        {
          value: $r('app.string.conversation_group_cancel'),
          fontColor: '#666666',
          action: () => {}
        },
        {
          value: $r('app.string.conversation_group_delete_action'),
          fontColor: DANGER_RED,
          action: () => {
            this.deleteGroup()
          }
        }
      ]
    })
  }

  private async deleteGroup(): Promise<void> {
    const groupViewModel = this.groupViewModel
    const group = this.group
    if (groupViewModel === undefined || group === undefined) {
      return
    }
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    try {
      await groupViewModel.deleteConversationGroup(group.groupId)
      this.pathStack.pop(true)
    } catch (e) {
      if (isConversationGroupNotExistError(e as V2NIMError)) {
        NECommonUtils.showToast($r('app.string.conversation_group_not_exist_tips'))
        this.pathStack.pop(true)
      } else {
        NECommonUtils.showToast($r('app.string.conversation_group_delete_failed'))
      }
    }
  }

  private async removeConversation(conversation: V2NIMConversation): Promise<void> {
    const groupViewModel = this.groupViewModel
    const group = this.group
    if (groupViewModel === undefined || group === undefined) {
      return
    }
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    try {
      const result = await groupViewModel.removeConversationsFromGroup(group.groupId, [conversation.conversationId])
      const failedResult = result?.find((item) =>
      item.conversationId === conversation.conversationId && item.error !== undefined)
      if (failedResult !== undefined) {
        this.handleRemoveConversationFailed(failedResult.error as V2NIMError, conversation.conversationId)
        return
      }
      this.listViewModel.removeMemberConversations([conversation.conversationId])
    } catch (e) {
      this.handleRemoveConversationFailed(e as V2NIMError, conversation.conversationId)
    }
  }

  private handleRemoveConversationFailed(error: V2NIMError, conversationId: string): void {
    if (isConversationGroupNotExistError(error)) {
      NECommonUtils.showToast($r('app.string.conversation_group_not_exist_tips'))
      this.pathStack.pop(true)
      return
    }
    if (isConversationNotExistError(error)) {
      NECommonUtils.showToast($r('app.string.conversation_group_conversation_not_exist_tips'))
      this.listViewModel.removeMemberConversations([conversationId])
      return
    }
    NECommonUtils.showToast($r('app.string.conversation_group_remove_failed'))
  }

  private getConversationTargetId(conversation: V2NIMConversation): string {
    return ConversationIdUtilRepo.parseConversationTargetId(conversation.conversationId)
  }

  private getAvatarShowName(sourceName: string): string {
    const size = sourceName.length
    if (size <= 2) {
      return sourceName
    }
    return sourceName.substring(size - 2)
  }
}

@Builder
export function ConversationGroupSettingPageBuilder() {
  ConversationGroupSettingPage()
}
