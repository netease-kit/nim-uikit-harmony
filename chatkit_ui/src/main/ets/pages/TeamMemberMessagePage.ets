/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import { Logger } from '@nimkit/common';
import {
  AvatarColorUntil,
  AvatarItem,
  CommonEmptyResult,
  NavigationBackBuilder, NECommonUtils, UserAvatarNameItem,
} from '@nimkit/common'
import { TeamMemberMessageParams, TeamMemberMessageViewModel } from '../viewmodel/TeamMemberMessageViewModel'
import { MemberHistoryMessageComponent } from '../view/MemberHistoryMessageComponent'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { V2NIMConversationType } from '@nimsdk/base'
import { ChatKitClient, IMKitConfigCenter, NEAIUserCache, TeamMemberCache } from '@nimkit/chatkit'
import { ChatBaseViewModel } from '../viewmodel/ChatBaseViewModel'

// 跳转页面入口函数
@Builder
export function TeamMemberMessagePageBuilder() {
  TeamMemberMessagePage()
}

/**
 * 群成员消息页面
 */
@ComponentV2
export struct TeamMemberMessagePage {
  pathStack: NavPathStack = new NavPathStack()

  //会话Id
  conversationId?: string
  //发送者Id
  senderId?: string

  @Local viewModel: TeamMemberMessageViewModel = new TeamMemberMessageViewModel()
  @Local avatarNameInfo: UserAvatarNameItem | undefined = undefined
  @Local messageInfoList: NIMMessageInfo[] = []

  // 监听消息删除/撤回
  @Monitor("viewModel.revokeAndeDeleteMission")
  onRevokeAndeDeleteMissionChange(monitor: IMonitor) {
    if (this.viewModel.revokeAndeDeleteMission) {
      this.convertToMessageInfoList()
      this.viewModel.resetRevokeAndeDeleteMission()
    }
  }

  // 初始化数据
  async initData() {
    let params = this.pathStack.getParamByName("TeamMemberMessagePage") as TeamMemberMessageParams[]
    if (params.length > 0) {
      let param = params[params.length -1]
      this.conversationId = param.conversationId
      this.senderId = param.senderId
      if (this.conversationId && this.senderId) {
        // 初始化 viewModel 并注册监听
        this.viewModel.init(this.conversationId, this.senderId)
        await this.getNameAvatarItem();
        await this.loadMessages()
      }
    } else {
      this.pathStack.removeByName("TeamMemberMessagePage")
    }

  }

  // 加载消息
  async loadMessages() {
    if (ChatKitClient.connectBroken() && IMKitConfigCenter.enableCloudSearch) {
      NECommonUtils.showToast($r('app.string.chat_network_error_tips'), Alignment.Center)
      return
    }

    if (this.viewModel.isLoading) {
      return
    }
    this.viewModel.isLoading = true
    try {
      await this.viewModel.searchMessages()
      this.convertToMessageInfoList()
    } catch (err) {
      Logger.error('ChatKitUI', 'TeamMemberMessagePage loadMessages error:', err)
    } finally {
      this.viewModel.isLoading = false
    }
  }

  // 将 V2NIMMessage 转换为 NIMMessageInfo
  convertToMessageInfoList() {
    this.messageInfoList = []
    let lastMessageTime = 0
    for (let i = 0; i < this.viewModel.messageList.length; i++) {
      const msg = this.viewModel.messageList[i]
      const msgInfo = new NIMMessageInfo(msg)
      msgInfo.setLastMessageTime(lastMessageTime)
      lastMessageTime = msg.createTime
      this.messageInfoList.push(msgInfo)
    }
  }

  // 获取头像信息
  async getNameAvatarItem() {
    let sendMember = await TeamMemberCache.getInstance().getMemberById(this.senderId ?? '')
    let avatar = new AvatarItem(
      sendMember?.userInfo?.avatar,
      sendMember?.getAvatarName(),
      AvatarColorUntil.getBackgroundColorById(this.senderId ?? '')
    )
    let nick = sendMember?.getNickname() ?? ''
    this.avatarNameInfo = {
      avatar: avatar,
      name: nick
    }
  }

  getMessageAvatarNameItem(item: NIMMessageInfo): UserAvatarNameItem {
    const displaySenderId = item.getDisplaySenderId()
    const aiUser = NEAIUserCache.getAIUser(displaySenderId)
    if (aiUser) {
      const aiName = aiUser.name ?? aiUser.accountId
      return {
        avatar: new AvatarItem(
          aiUser.avatar,
          aiName.length > 2 ? aiName.substring(aiName.length - 2, aiName.length) : aiName,
          AvatarColorUntil.getBackgroundColorById(displaySenderId)
        ),
        name: aiName
      }
    }
    return this.avatarNameInfo ?? {
      avatar: new AvatarItem(
        undefined,
        displaySenderId.length > 2 ? displaySenderId.substring(displaySenderId.length - 2, displaySenderId.length) :
        displaySenderId,
        AvatarColorUntil.getBackgroundColorById(displaySenderId)
      ),
      name: displaySenderId
    }
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.chat_new_message_search_by_member'),
          backgroundColor: $r('sys.color.white'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        if (this.messageInfoList.length === 0 && !this.viewModel.isLoading) {
          // 空状态展示
          CommonEmptyResult({
            emptyImage: $r('app.media.no_history'),
            tips: $r('app.string.team_history_record_empty_tip')
          })
            .margin({
              top: 74
            })
        } else {
          // 消息列表
          List() {
            ForEach(this.messageInfoList, (item: NIMMessageInfo, index: number) => {
              ListItem() {
                MemberHistoryMessageComponent({
                  message: item,
                  userAvatarName: this.getMessageAvatarNameItem(item),
                  onMessageClick: {
                    onItemClick: () => {
                      if (ChatBaseViewModel.currentViewModel) {
                        ChatBaseViewModel.currentViewModel.setAnchorMessage(item)
                      }
                      if (item.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
                        this.pathStack.popToName('ChatP2PPage')
                      } else if (item.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
                        this.pathStack.popToName('ChatTeamPage')
                      }
                    }
                  }
                })
              }
              .margin({
                top: index === 0 ? 12 : 8,
                bottom: 8
              })
            }, (item: NIMMessageInfo) => item.message.messageClientId)

            // 底部加载状态
            ListItem() {
              if (this.viewModel.isLoading) {
                // 加载中
                Row() {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                  Text($r('app.string.chat_message_loading'))
                    .fontSize(14)
                    .fontColor('#999999')
                    .margin({ left: 8 })
                }
                .width('100%')
                .height(50)
                .justifyContent(FlexAlign.Center)
              } else if (!this.viewModel.hasMore) {
                // 没有更多了
                Row() {
                  Text($r('app.string.chat_message_no_more_data'))
                    .fontSize(14)
                    .fontColor('#999999')
                }
                .width('100%')
                .height(50)
                .justifyContent(FlexAlign.Center)
              }
            }
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .backgroundColor($r('sys.color.white'))
          .onReachEnd(() => {
            // 上拉加载更多
            if (this.viewModel.hasMore && !this.viewModel.isLoading) {
              this.loadMessages()
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.white'))
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      // 获取页面参数
      this.initData()
    })
    .onDisAppear(() => {
      // 页面销毁时取消注册监听
      this.viewModel.onDestroy()
    })
  }

}
