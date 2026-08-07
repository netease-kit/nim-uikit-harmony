/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NavigationBackBuilder, NECommonUtils } from '@nimkit/common'
import { V2NIMError } from '@nimsdk/base'
import {
  ConversationGroupInfo,
  ConversationGroupKind,
  isConversationGroupLimitError,
  moveConversationGroupKeysByIndex
} from '../model/ConversationGroupModel'
import { ConversationGroupRouteParam } from '../model/ConversationGroupRouteParam'
import {
  CONVERSATION_GROUP_NAME_DIALOG_CONTAINER_HEIGHT,
  ConversationGroupNameDialog
} from '../view/ConversationGroupNameDialog'
import { ConversationGroupViewModel } from '../viewmodel/ConversationGroupViewModel'

const PAGE_BACKGROUND_COLOR: string = '#EFF1F4'
const GROUP_BLOCK_MARGIN: number = 20
const GROUP_BLOCK_RADIUS: number = 8
const GROUP_ROW_HEIGHT: number = 46
const GROUP_DIVIDER_HEIGHT: number = 1
const ACTION_TOUCH_SIZE: number = 40
const CREATE_BUTTON_HEIGHT: number = 50
const CREATE_BUTTON_BOTTOM: number = 54
const CREATE_BUTTON_LIST_BOTTOM_SPACE: number = CREATE_BUTTON_HEIGHT + CREATE_BUTTON_BOTTOM + 16

@ComponentV2
export struct ConversationGroupManagePage {
  pathStack: NavPathStack = new NavPathStack()
  @Local viewModel: ConversationGroupViewModel = new ConversationGroupViewModel()
  private createGroupDialog?: CustomDialogController = undefined

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.conversation_group_manage_title'),
          backgroundColor: PAGE_BACKGROUND_COLOR,
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        Stack() {
          this.groupListBuilder()
          this.createButtonBuilder()
        }
        .width('100%')
        .layoutWeight(1)
        .alignContent(Alignment.Bottom)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(PAGE_BACKGROUND_COLOR)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const params = this.pathStack.getParamByName('ConversationGroupManagePage') as ConversationGroupViewModel[]
      if (params[0] !== undefined) {
        this.viewModel = params[0]
      }
    })
  }

  @Builder
  private groupListBuilder() {
    List() {
      ListItem() {
        this.sectionHeaderBuilder($r('app.string.conversation_group_visible_section'))
      }
      .selectable(false)

      ForEach(this.visibleFixedGroups(), (group: ConversationGroupInfo, index?: number) => {
        ListItem() {
          this.groupRowBuilder(group, false, index ?? 0, this.viewModel.visibleGroups.length)
        }
        .selectable(false)
      }, (group: ConversationGroupInfo, index?: number): string => {
        return this.groupListItemKey('visible-fixed', group, index ?? 0, this.viewModel.visibleGroups.length)
      })

      ForEach(this.visibleMovableGroups(), (group: ConversationGroupInfo, index?: number) => {
        ListItem() {
          this.groupRowBuilder(group, false, this.visibleFixedGroups().length + (index ?? 0),
            this.viewModel.visibleGroups.length)
        }
      }, (group: ConversationGroupInfo, index?: number): string => {
        return this.groupListItemKey('visible', group, this.visibleFixedGroups().length + (index ?? 0),
          this.viewModel.visibleGroups.length)
      })
        .onMove((from: number, to: number): void => {
          this.moveVisibleGroup(from, to)
        })

      ListItem() {
        this.sectionHeaderBuilder($r('app.string.conversation_group_hidden_section'))
      }
      .selectable(false)

      if (this.viewModel.hiddenGroups.length > 0) {
        ForEach(this.viewModel.hiddenGroups, (group: ConversationGroupInfo, index?: number) => {
          ListItem() {
            this.groupRowBuilder(group, true, index ?? 0, this.viewModel.hiddenGroups.length)
          }
        }, (group: ConversationGroupInfo, index?: number): string => {
          return this.groupListItemKey('hidden', group, index ?? 0, this.viewModel.hiddenGroups.length)
        })
      }

      ListItem() {
        Column() {}
          .width('100%')
          .height(CREATE_BUTTON_LIST_BOTTOM_SPACE)
      }
      .selectable(false)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private sectionHeaderBuilder(title: ResourceStr) {
    Text(title)
      .fontSize(13)
      .fontColor('#8A8F99')
      .width('100%')
      .height(40)
      .padding({ left: 20, right: 20 })
      .backgroundColor(PAGE_BACKGROUND_COLOR)
      .textAlign(TextAlign.Start)
  }

  @Builder
  private groupRowBuilder(group: ConversationGroupInfo, hidden: boolean, index: number, total: number) {
    Row() {
      Column() {
        Row() {
          this.visibilityActionBuilder(group, hidden)

          Text(group.name)
            .fontSize(16)
            .fontColor('#1F2329')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 10 })

          if (group.canSetting) {
            this.settingActionBuilder(group)
          }

          if (!hidden && group.kind !== ConversationGroupKind.ALL) {
            this.dragHandleBuilder()
          }
        }
        .height(index < total - 1 ? GROUP_ROW_HEIGHT - GROUP_DIVIDER_HEIGHT : GROUP_ROW_HEIGHT)
        .width('100%')
        .padding({ left: 16, right: 10 })
        .alignItems(VerticalAlign.Center)

        if (index < total - 1) {
          Divider()
            .height(GROUP_DIVIDER_HEIGHT)
            .strokeWidth(GROUP_DIVIDER_HEIGHT)
            .color('#F5F8FC')
            .width('100%')
        }
      }
      .height(GROUP_ROW_HEIGHT)
      .layoutWeight(1)
      .backgroundColor(Color.White)
      .borderRadius({
        topLeft: index === 0 ? GROUP_BLOCK_RADIUS : 0,
        topRight: index === 0 ? GROUP_BLOCK_RADIUS : 0,
        bottomLeft: index === total - 1 ? GROUP_BLOCK_RADIUS : 0,
        bottomRight: index === total - 1 ? GROUP_BLOCK_RADIUS : 0
      })
      .onClick(() => {
        if (group.canSetting) {
          this.openSettingPage(group)
        }
      })
    }
    .height(GROUP_ROW_HEIGHT)
    .width('100%')
    .padding({ left: GROUP_BLOCK_MARGIN, right: GROUP_BLOCK_MARGIN })
  }

  @Builder
  private visibilityActionBuilder(group: ConversationGroupInfo, hidden: boolean) {
    Stack() {
      if (hidden) {
        Image($r('app.media.ic_conversation_group_manage_plus_green'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
      } else if (group.canHide) {
        Image($r('app.media.ic_conversation_group_manage_minus_red'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
      } else {
        Image($r('app.media.ic_conversation_group_manage_minus_gray'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
      }
    }
    .width(ACTION_TOUCH_SIZE)
    .height(ACTION_TOUCH_SIZE)
    .alignContent(Alignment.Center)
    .onClick(() => {
      if (group.canHide || hidden) {
        if (hidden) {
          this.viewModel.moveToVisible(group)
        } else {
          this.viewModel.moveToHidden(group)
        }
      }
    })
  }

  @Builder
  private settingActionBuilder(group: ConversationGroupInfo) {
    Stack() {
      Image($r('app.media.ic_conversation_group_manage_setting'))
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)
    }
    .width(ACTION_TOUCH_SIZE)
    .height(ACTION_TOUCH_SIZE)
    .alignContent(Alignment.Center)
    .onClick(() => {
      this.openSettingPage(group)
    })
  }

  @Builder
  private dragHandleBuilder() {
    Stack() {
      Image($r('app.media.ic_conversation_group_manage_drag'))
        .width(16)
        .height(14)
        .objectFit(ImageFit.Contain)
        .draggable(false)
    }
    .width(ACTION_TOUCH_SIZE)
    .height(ACTION_TOUCH_SIZE)
    .alignContent(Alignment.Center)
    .draggable(false)
  }

  @Builder
  private createButtonBuilder() {
    Row() {
      Button($r('app.string.conversation_group_create_action'), { type: ButtonType.Normal, stateEffect: true })
        .fontSize(16)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .height(CREATE_BUTTON_HEIGHT)
        .borderRadius(8)
        .backgroundColor('#337EFF')
        .onClick(() => {
          this.openCreateGroupPage()
        })
    }
      .width('100%')
      .height(CREATE_BUTTON_HEIGHT)
      .padding({ left: 30, right: 30 })
      .margin({ bottom: CREATE_BUTTON_BOTTOM })
      .alignItems(VerticalAlign.Center)
      .zIndex(1)
  }

  private openCreateGroupPage(): void {
    const dialog = new CustomDialogController({
      builder: ConversationGroupNameDialog({
        title: $r('app.string.conversation_group_create_title'),
        onSubmitName: async (name: string): Promise<void> => {
          await this.viewModel.createConversationGroup(name)
        },
        onSubmitError: (error: Error): void => {
          this.showCreateGroupError(error)
        },
        onDialogClose: () => {
          this.closeCreateGroupDialog()
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
    this.createGroupDialog = dialog
    this.createGroupDialog.open()
  }

  private showCreateGroupError(error: Error): void {
    if (isConversationGroupLimitError(error as V2NIMError)) {
      NECommonUtils.showToast($r('app.string.conversation_group_limit_tips'))
    } else {
      NECommonUtils.showToast($r('app.string.conversation_group_save_failed'))
    }
  }

  private closeCreateGroupDialog(): void {
    this.createGroupDialog?.close()
    this.createGroupDialog = undefined
  }

  private openSettingPage(group: ConversationGroupInfo): void {
    this.pathStack.pushPath({
      name: 'ConversationGroupSettingPage',
      param: new ConversationGroupRouteParam(this.viewModel, group)
    })
  }

  private visibleFixedGroups(): ConversationGroupInfo[] {
    return this.viewModel.visibleGroups.filter((group: ConversationGroupInfo): boolean =>
    group.kind === ConversationGroupKind.ALL)
  }

  private visibleMovableGroups(): ConversationGroupInfo[] {
    return this.viewModel.visibleGroups.filter((group: ConversationGroupInfo): boolean =>
    group.kind !== ConversationGroupKind.ALL)
  }

  private groupListItemKey(section: string, group: ConversationGroupInfo, index: number, total: number): string {
    const firstState = index === 0 ? 'first' : 'not-first'
    const lastState = index === total - 1 ? 'last' : 'not-last'
    return `${section}-${group.groupKey}-${group.name}-${group.unreadCount}-${firstState}-${lastState}-${total}`
  }

  private moveVisibleGroup(from: number, to: number): void {
    const fixedGroupKeys = this.visibleFixedGroups().map((group: ConversationGroupInfo): string => group.groupKey)
    const movableGroupKeys = this.visibleMovableGroups().map((group: ConversationGroupInfo): string => group.groupKey)
    this.viewModel.reorderVisible(fixedGroupKeys.concat(moveConversationGroupKeysByIndex(movableGroupKeys, from, to)))
  }
}

@Builder
export function ConversationGroupManagePageBuilder() {
  ConversationGroupManagePage()
}
