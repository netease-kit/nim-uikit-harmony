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
  MatchSearchText,
  NavigationBackBuilder,
  NECommonUtils
} from '@nimkit/common'
import { V2NIMConversation, V2NIMError } from '@nimsdk/base'
import {
  buildConversationGroupSuccessNameList,
  CONVERSATION_GROUP_SELECT_CONVERSATION_LIMIT,
  ConversationGroupOperationFailureKind,
  isConversationNotExistError,
  pickConversationsByIds,
  resolveConversationGroupOperationFailureKind
} from '../model/ConversationGroupModel'
import { ConversationGroupRouteParam } from '../model/ConversationGroupRouteParam'
import { ConversationGroupSelectConversationViewModel } from '../viewmodel/ConversationGroupSelectConversationViewModel'
import { ConversationGroupViewModel } from '../viewmodel/ConversationGroupViewModel'

@ComponentV2
export struct ConversationGroupSelectConversationPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local groupViewModel?: ConversationGroupViewModel = undefined
  @Local groupId: string = ''
  @Local viewModel: ConversationGroupSelectConversationViewModel =
    new ConversationGroupSelectConversationViewModel()

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.conversation_group_add_conversation_title_count',
            this.viewModel.selectedCount(), CONVERSATION_GROUP_SELECT_CONVERSATION_LIMIT),
          leftButtonTitle: $r('app.string.conversation_group_cancel'),
          leftButtonColor: '#666666',
          rightButtonTitle: $r('app.string.conversation_group_confirm'),
          rightButtonColor: this.canSubmitSelectedConversations() ? '#337EFF' : '#B3B7BC',
          rightButtonAction: () => {
            if (this.canSubmitSelectedConversations()) {
              this.submitSelectedConversations()
            }
          },
          backgroundColor: Color.White,
          showDivideLine: false,
          leftButtonAction: () => {
            this.pathStack.pop()
          },
          buttonTextWidth: 56
        })

        this.searchBuilder()

        Row() {
          Text($r('app.string.conversation_group_recent_conversation'))
            .fontSize(16)
            .fontColor('#333333')
        }
        .height(44)
        .width('100%')
        .padding({ left: 20, right: 20 })
        .backgroundColor(Color.White)
        .alignItems(VerticalAlign.Center)

        if (this.viewModel.displayCandidates.length <= 0 && !this.viewModel.isLoadingCandidates) {
          CommonEmptyResult({
            emptyImage: $r('app.media.no_history'),
            tips: $r('app.string.conversation_group_detail_empty')
          })
            .margin({ top: 120 })
        } else {
          List() {
            ForEach(this.viewModel.displayCandidates, (conversation: V2NIMConversation) => {
              ListItem() {
                ConversationGroupCandidateConversationItem({
                  conversation: conversation,
                  keyword: this.viewModel.keyword,
                  checked: this.viewModel.isSelected(conversation.conversationId),
                  onSelectionChange: (conversationId: string, selected: boolean): boolean => {
                    const reachedLimit = this.viewModel.setSelection(conversationId, selected)
                    if (reachedLimit) {
                      NECommonUtils.showToast($r('app.string.conversation_group_select_limit_tips'))
                      return false
                    }
                    return true
                  }
                })
              }
            }, (conversation: V2NIMConversation): string => {
              return `${conversation.conversationId}-${conversation.name ?? ''}`
            })

            ListItem() {
              Row()
                .height(24)
            }
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .backgroundColor(Color.White)
          .onReachEnd(() => {
            this.viewModel.loadMoreCandidates()
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const params = this.pathStack.getParamByName('ConversationGroupSelectConversationPage') as ConversationGroupRouteParam[]
      const param = params[0]
      if (param !== undefined) {
        this.groupViewModel = param.groupViewModel
        this.groupId = param.group?.groupId ?? ''
        if (this.groupId.length > 0) {
          this.viewModel.initCandidates(this.groupId)
        }
      }
    })
  }

  @Builder
  private searchBuilder() {
    Row() {
      Row() {
        Image($r('app.media.nav_search'))
          .width(18)
          .height(18)
          .margin({ left: 12, right: 8 })

        TextInput({ placeholder: $r('app.string.conversation_group_search_placeholder') })
          .fontSize(14)
          .fontColor('#1F2329')
          .placeholderColor('#A7ABB3')
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .height(40)
          .padding({ left: 0, right: 0, top: 0, bottom: 0 })
          .cancelButton({
            style: CancelButtonStyle.INPUT,
            icon: {
              src: $r('app.media.input_clean'),
              size: 16,
              color: '#B3B7BC'
            }
          })
          .onChange((value: string) => {
            this.viewModel.search(value)
          })
      }
      .layoutWeight(1)
      .height(40)
      .borderRadius(8)
      .backgroundColor('#F5F6F8')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(64)
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
  }

  private async submitSelectedConversations(): Promise<void> {
    const groupViewModel = this.groupViewModel
    if (groupViewModel === undefined || this.groupId.length <= 0) {
      this.pathStack.pop()
      return
    }
    const selectedIds = this.viewModel.selectedConversationIds.slice()
    if (selectedIds.length <= 0) {
      return
    }
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    try {
      const result = await groupViewModel.addConversationsToGroup(this.groupId, selectedIds)
      const failedIds: Set<string> = new Set()
      const failedErrors: V2NIMError[] = []
      const failedConversationNotExistIds: string[] = []
      result?.forEach((item) => {
        if (item.error !== undefined) {
          failedIds.add(item.conversationId)
          failedErrors.push(item.error)
          if (isConversationNotExistError(item.error)) {
            failedConversationNotExistIds.push(item.conversationId)
          }
        }
      })
      const successIds = selectedIds.filter((conversationId: string): boolean => !failedIds.has(conversationId))
      const successConversations = pickConversationsByIds(this.viewModel.candidateConversations, successIds)
      if (successIds.length > 0) {
        this.viewModel.markMembersAdded(successIds)
      }
      if (failedIds.size > 0) {
        if (await this.shouldReturnAfterAddFailed(failedErrors, failedConversationNotExistIds)) {
          this.pathStack.pop(true)
          return
        }
        if (successIds.length <= 0) {
          this.showAddFailedToast(failedErrors)
          return
        }
        const successNames = buildConversationGroupSuccessNameList(
          successConversations,
          this.getStringResource($r('app.string.conversation_group_partial_add_name_separator')),
          this.getStringResource($r('app.string.conversation_group_partial_add_name_overflow_suffix'))
        )
        if (successNames.length <= 0) {
          NECommonUtils.showToast($r('app.string.conversation_group_partial_add_failed'))
        } else {
          NECommonUtils.showToast($r('app.string.conversation_group_partial_add_success_tips', successNames))
        }
      }
      this.pathStack.pop(successConversations)
    } catch (e) {
      if (await this.shouldReturnAfterAddFailed([e as V2NIMError], selectedIds)) {
        this.pathStack.pop(true)
        return
      }
      this.showAddFailedToast([e as V2NIMError])
    }
  }

  private getStringResource(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id)
  }

  private canSubmitSelectedConversations(): boolean {
    return this.viewModel.selectedCount() > 0
  }

  private async shouldReturnAfterAddFailed(errors: V2NIMError[], failedIds: string[]): Promise<boolean> {
    const failureKind = resolveConversationGroupOperationFailureKind(errors)
    if (failureKind === ConversationGroupOperationFailureKind.GROUP_NOT_EXIST) {
      NECommonUtils.showToast($r('app.string.conversation_group_not_exist_tips'))
      return true
    }
    const hasConversationNotExistError = errors.some((error: V2NIMError): boolean => isConversationNotExistError(error))
    if (hasConversationNotExistError && failedIds.length > 0) {
      const failedIdSet: Set<string> = new Set(failedIds)
      const preservedSelectedIds = this.viewModel.selectedConversationIds.filter((conversationId: string): boolean =>
      !failedIdSet.has(conversationId))
      await this.viewModel.refreshCandidates(preservedSelectedIds)
    }
    return false
  }

  private showAddFailedToast(errors: V2NIMError[]): void {
    const failureKind = resolveConversationGroupOperationFailureKind(errors)
    if (failureKind === ConversationGroupOperationFailureKind.BELONGED_GROUP_LIMIT) {
      NECommonUtils.showToast($r('app.string.conversation_group_belonged_group_limit_tips'))
      return
    }
    if (failureKind === ConversationGroupOperationFailureKind.CONVERSATIONS_IN_GROUP_LIMIT) {
      NECommonUtils.showToast($r('app.string.conversation_group_conversations_in_group_limit_tips'))
      return
    }
    if (failureKind === ConversationGroupOperationFailureKind.CONVERSATION_NOT_EXIST) {
      NECommonUtils.showToast($r('app.string.conversation_group_conversation_not_exist_tips'))
      return
    }
    NECommonUtils.showToast($r('app.string.conversation_group_add_failed'))
  }
}

@ComponentV2
struct ConversationGroupCandidateConversationItem {
  @Param conversation: V2NIMConversation | undefined = undefined
  @Param keyword: string = ''
  @Param checked: boolean = false
  @Param onSelectionChange?: (conversationId: string, selected: boolean) => boolean = undefined
  @Local currentChecked: boolean = false

  aboutToAppear(): void {
    this.currentChecked = this.checked
  }

  @Monitor('checked')
  onCheckedChange(): void {
    this.currentChecked = this.checked
  }

  build() {
    Row() {
      Checkbox()
        .select(this.currentChecked)
        .width(18)
        .height(18)
        .selectedColor('#337EFF')
        .hitTestBehavior(HitTestMode.None)

      CommonAvatar({
        item: new AvatarItem(
          this.conversation?.avatar,
          this.getAvatarShowName(this.conversationName()),
          AvatarColorUntil.getBackgroundColorById(this.conversationTargetId())
        )
      })
        .width(36)
        .height(36)
        .margin({ left: 12 })

      MatchSearchText({
        allText: this.conversationName(),
        searchText: this.keyword,
        fontSize: 16,
        normalFontColor: '#333333',
        highlightFontColor: '#337EFF'
      })
      .layoutWeight(1)
      .margin({ left: 12, right: 16 })
    }
    .height(52)
    .width('100%')
    .padding({ left: 20 })
    .backgroundColor(Color.White)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      const conversationId = this.conversation?.conversationId ?? ''
      if (conversationId.length <= 0) {
        return
      }
      const nextChecked = !this.currentChecked
      if (this.onSelectionChange?.(conversationId, nextChecked) === true) {
        this.currentChecked = nextChecked
      }
    })
  }

  private conversationName(): string {
    return this.conversation?.name ?? this.conversationTargetId()
  }

  private conversationTargetId(): string {
    return ConversationIdUtilRepo.parseConversationTargetId(this.conversation?.conversationId ?? '')
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
export function ConversationGroupSelectConversationPageBuilder() {
  ConversationGroupSelectConversationPage()
}
