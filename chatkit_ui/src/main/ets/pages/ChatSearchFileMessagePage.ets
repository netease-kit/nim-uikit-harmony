/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import { AvatarColorUntil, AvatarItem, CommonAvatar, CommonEmptyResult, NavigationBackBuilder, NECommonUtils, UserAvatarNameItem } from '@nimkit/common'
import { ChatSearchFileMessageParams, ChatSearchFileMessageViewModel, DateGroupedMessages } from '../viewmodel/ChatSearchFileMessageViewModel'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { V2NIMConversationType, V2NIMTeamType, V2NIMUser } from '@nimsdk/base'
import { ChatKitClient, conversationSelectLimitCount, ConversationSelectParam, ErrorUtils, IMKitConfigCenter, NEFriendUserCache,
  NEUserWithFriend,
  TeamMemberCache, TeamMemberWithUser, TeamRepo } from '@nimkit/chatkit'
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel'
import { ForwardMessageDialog } from '../view/ForwardMessageDialog'
import { ChatUserInfo } from '../model/ChatUserInfo'
import { ChatTeamInfo } from '../model/ChatTeamInfo'
import { fileBuilder } from '../view/MessageComponentBuilder'
import { ChatInfo } from '../model/ChatInfo'
import { downLoadAndOpenFile } from '../common/MessageHelper'

// 跳转页面入口函数
@Builder
export function ChatSearchFileMessagePageBuilder() {
  ChatSearchFileMessagePage()
}

/**
 * 文件消息操作对话框
 */
@CustomDialog
struct FileMessageActionDialog {
  message?: NIMMessageInfo
  controller?: CustomDialogController
  // 消息收藏回调
  onMessageCollect?: () => void
  // 转发回调
  onMessageForward?: () => void
  //实现收藏到聊天
  collectMessage = () => {
    this.cancel()
    this.onMessageCollect?.()
  }
  // 实现转发功能
  forwardFile = () => {
    this.cancel()
    this.onMessageForward?.()
  }
  cancel = () => {
    this.controller?.close()
  }

  private getDialogHeight(): number {
    const actionCount = IMKitConfigCenter.enableCollection ? 3 : 2
    const dividerHeight = IMKitConfigCenter.enableCollection ? 1 : 0
    return 42 * actionCount + 10 + dividerHeight
  }

  build() {
    Column() {
      Column() {

        Text($r('app.string.chat_operation_forward'))
          .fontSize(14)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.forwardFile)


        if (IMKitConfigCenter.enableCollection) {
          Row()
            .height(1)
            .width('100%')
            .backgroundColor('#EFF1F4')

          Text($r('app.string.chat_operation_collection'))
            .fontSize(14)
            .fontColor('#333333')
            .textAlign(TextAlign.Center)
            .height(42)
            .width('100%')
            .onClick(this.collectMessage)
        }

      }
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 12, right: 12 })

      Column() {
        Text($r('app.string.mine_edit_cancel'))
          .fontSize(14)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.cancel)
      }
      .height(42)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ top: 10, left: 12, right: 12 })
    }
    .height(this.getDialogHeight())
    .backgroundColor(Color.Transparent)
  }
}

/**
 * 文件消息组件（包含发送者信息）
 */
@ComponentV2
struct FileMessageItemWithSender {
  @Param message: NIMMessageInfo | undefined = undefined
  @Param @Require onMessageItemClick: (msg: NIMMessageInfo | undefined) => void
  @Param @Require onMessageMoreClick: (msg: NIMMessageInfo | undefined) => void
  @Param chatInfo: ChatInfo | undefined = undefined
  @Param userInfo: V2NIMUser | undefined = undefined
  @Local avatarNameInfo: UserAvatarNameItem | undefined = undefined
  @Local sendTime: string = ''

  aboutToAppear(): void {
    if (this.message) {
      // 格式化发送时间
      this.sendTime = this.formatTime(this.message.message.createTime)
      // 获取发送者信息
      this.loadSenderInfo()
    }
  }

  // 格式化时间为 "月日"
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    const month = date.getMonth() + 1
    const day = date.getDate()
    return `${month}月${day}日`
  }

  // 加载发送者信息
  private async loadSenderInfo() {
    if (!this.message) {
      return
    }
    const senderId = this.message.message.senderId
    if (this.avatarNameInfo === undefined) {
      if (this.message.message.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        // 群聊：从 TeamMemberCache 获取
        const sendMember: TeamMemberWithUser | undefined = await TeamMemberCache.getInstance().getMemberById(senderId ?? '')
        const avatar = new AvatarItem(
          sendMember?.userInfo?.avatar ?? this.userInfo?.avatar,
          sendMember?.getAvatarName() ?? this.userInfo?.name,
          AvatarColorUntil.getBackgroundColorById(senderId ?? '')
        )
        const nick = sendMember?.getNickname() ?? this.userInfo?.name ?? this.userInfo?.accountId ?? ''
        this.avatarNameInfo = {
          avatar: avatar,
          name: nick
        }
      } else if (this.message.message.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        // 单聊：从好友缓存或用户信息获取
        const friendUserInfo: NEUserWithFriend | undefined = NEFriendUserCache.getInstance().getFriendById(senderId ?? '')
        let avatarUrl: string | undefined = undefined
        let avatarName: string = ''
        let nick: string = ''

        if (friendUserInfo) {
          // 从好友缓存获取
          avatarUrl = friendUserInfo.user?.avatar
          avatarName = friendUserInfo.shortName() ?? ''
          nick = friendUserInfo.showName() ?? senderId ?? ''
        } else if (this.userInfo) {
          // 从传入的用户信息获取
          avatarUrl = this.userInfo.avatar
          avatarName = this.userInfo.name?.substring(Math.max(0, (this.userInfo.name?.length ?? 0) - 2)) ?? ''
          nick = this.userInfo.name ?? senderId ?? ''
        } else {
          // 兜底：使用 accountId
          avatarName = senderId?.substring(Math.max(0, (senderId?.length ?? 0) - 2)) ?? ''
          nick = senderId ?? ''
        }

        const avatar = new AvatarItem(
          avatarUrl,
          avatarName,
          AvatarColorUntil.getBackgroundColorById(senderId ?? '')
        )
        this.avatarNameInfo = {
          avatar: avatar,
          name: nick
        }
      }
    }
  }

  build() {
    Column() {
      // 发送者信息行
      Row() {
        // 发送者头像
        CommonAvatar({
          item: this.avatarNameInfo?.avatar,
        })
          .width(36)
          .height(36)
          .borderRadius(20)
          .id("otherAvatar")

        // 发送者名称
        Text(this.avatarNameInfo?.name)
          .fontSize(14)
          .fontColor('#333333')
          .margin({ left: 8 })
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 发送时间
        Text(this.sendTime)
          .fontSize(12)
          .fontColor('#666666')
          .flexShrink(0)
      }
      .width('100%')

      // 文件消息内容
      Row() {
        fileBuilder({
          message: this.message
        }).onClick(() => {
          this.onMessageItemClick?.(this.message)
        })

        // 更多操作按钮
        Image($r('app.media.ic_public_more_dot_vertical'))
          .width(24)
          .height(24)
          .margin({ right: 12 })
          .onClick(() => {
            this.onMessageMoreClick?.(this.message)
          })
      }
      .width('100%')
      .backgroundColor('#F4F4F4')
      .borderRadius(8)
      .margin({ top: 12 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .padding({
      left: 20,
      right: 20,
      top: 8,
      bottom: 8
    })
  }
}

/**
 * 文件搜索页面
 */
@ComponentV2
export struct ChatSearchFileMessagePage {
  pathStack: NavPathStack = new NavPathStack()
  // 会话Id
  conversationId?: string
  @Local viewModel: ChatSearchFileMessageViewModel = new ChatSearchFileMessageViewModel()
  @Local chatInfo: ChatTeamInfo | ChatUserInfo | undefined = undefined
  @Local tapMessage?: NIMMessageInfo
  @Local forwardMessages: NIMMessageInfo[] = []
  @Local forwardConversations: ConversationSelectModel[] = []
  @Local currentConversationName?: string
  // List 滚动控制器
  private listScroller: Scroller = new Scroller()
  //收藏
  collectMessage = async () => {
    if (!IMKitConfigCenter.enableCollection) {
      return
    }
    if (this.tapMessage && this.chatInfo) {
      const senderId = this.tapMessage.message.senderId
      let senderName: string = ''
      let avatar: string | undefined = undefined

      if (this.tapMessage.message.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        const sendMember = await TeamMemberCache.getInstance().getMemberById(senderId ?? '')
        senderName = sendMember?.getNickname() ?? ''
        avatar = sendMember?.userInfo?.avatar
      } else {
        // P2P 单聊收藏：从好友缓存或用户信息获取
        const friendUserInfo = NEFriendUserCache.getInstance().getFriendById(senderId ?? '')
        if (friendUserInfo) {
          // 从好友缓存获取
          senderName = friendUserInfo.showName() ?? senderId ?? ''
          avatar = friendUserInfo.user?.avatar
        } else {
          // 从 ViewModel 的用户缓存获取
          const userInfo = this.viewModel.userMap.get(senderId)
          if (userInfo) {
            senderName = userInfo.name ?? senderId ?? ''
            avatar = userInfo.avatar
          } else {
            // 兜底：使用 chatInfo
            senderName = this.chatInfo.getChatUserShowName(senderId)
            avatar = this.chatInfo.getChatUserAvatarUrl(senderId)
          }
        }
      }

      const conversationName = this.chatInfo.getConversationName() ?? ''
      this.viewModel.collectionMessage(this.tapMessage, conversationName, senderName, avatar)
    }
  }
  forwardMessageDialog = new CustomDialogController({
    builder: ForwardMessageDialog({
      conversationList: this.forwardConversations,
      currentConversationName: this.currentConversationName,
      sendForwardMsg: (text: string | undefined) => {
        this.viewModel.forwardMessage(this.forwardMessages, this.forwardConversations, text)
      }
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 250,
    width: 276,
  })
  // 转发消息
  forwardMessage = () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      this.pathStack.pushPath({
        name: 'ConversationSelectPage',
        param: new ConversationSelectParam([], conversationSelectLimitCount, this.forwardMessageAction)
      })
    }
  }
  forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
    if (this.tapMessage?.message) {
      this.forwardMessages = [this.tapMessage]
      this.forwardConversations = selectedList
      this.currentConversationName = this.chatInfo?.getConversationName()
      this.forwardMessageDialog.open()
    }
  }
  // 长按操作对话框
  fileActionDialog?: CustomDialogController

  /**
   * 监听删除/撤回标志变化
   * 当消息被删除或撤回时，自动从列表中移除
   */
  @Monitor("viewModel.revokeAndeDeleteMission")
  onRevokeAndeDeleteMissionChange(monitor: IMonitor) {
    if (this.viewModel.revokeAndeDeleteMission) {
      // 重置标志
      this.viewModel.resetRevokeAndeDeleteMission()
    }
  }

  // 初始化数据
  async initData() {
    let params = this.pathStack.getParamByName('ChatSearchFileMessagePage') as ChatSearchFileMessageParams[]
    if (params.length > 0) {
      let param = params[params.length - 1]
      this.conversationId = param.conversationId
      if (this.conversationId) {
        this.viewModel.init(this.conversationId)
        // 首次加载
        const conversationType = ChatKitClient.nim.conversationIdUtil.parseConversationType(this.conversationId)
        const targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(this.conversationId);
        if (conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
          this.chatInfo = new ChatUserInfo()
          this.chatInfo.setConversationId(this.conversationId)
        } else {
          this.chatInfo = new ChatTeamInfo(this.conversationId)
          const teamInfo = await TeamRepo.getTeamInfo(targetId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL);
          (this.chatInfo as ChatTeamInfo).setTeam(teamInfo)
          ChatKitClient.selfLeaveTeam = false
        }
        await this.loadMessages(true)
      }
    } else {
      this.pathStack.removeByName('ChatSearchFileMessagePage')
    }
  }

  // 加载消息
  async loadMessages(scrollToTop: boolean = false) {
    try {
      if (ChatKitClient.connectBroken() && IMKitConfigCenter.enableCloudSearch) {
        NECommonUtils.showToast($r('app.string.chat_network_error_tips'), Alignment.Center)
        return
      }

      await this.viewModel.searchMessages()

      // 首次加载时滚动到顶部
      if (scrollToTop && this.viewModel.groupedMessageList.length > 0) {
        setTimeout(() => {
          this.listScroller.scrollEdge(Edge.Top)
        }, 100)
      }
    } catch (err) {
      console.error('ChatSearchFileMessagePage loadMessages error:', err)
    }
  }

  // 显示长按操作对话框
  showFileActionDialog(msg?: NIMMessageInfo) {
    this.tapMessage = msg
    // 每次打开前重新创建 dialog，确保使用最新的 tapMessage 和回调
    this.fileActionDialog = new CustomDialogController({
      builder: FileMessageActionDialog({
        message: this.tapMessage,
        onMessageCollect: IMKitConfigCenter.enableCollection ? this.collectMessage : undefined,
        onMessageForward: this.forwardMessage
      }),
      cornerRadius: 0,
      alignment: DialogAlignment.Bottom,
      backgroundColor: Color.Transparent,
      backgroundBlurStyle: BlurStyle.NONE,
    })
    this.fileActionDialog.open()
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.search_by_file'),
          backgroundColor: $r('sys.color.white'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        if (this.viewModel.groupedMessageList.length === 0 && !this.viewModel.isLoading) {
          // 空状态展示
          CommonEmptyResult({
            emptyImage: $r('app.media.no_history'),
            tips: $r('app.string.search_file_empty_tip')
          })
            .margin({
              top: 74
            })
        } else {
          // 按日期分组的文件消息列表
          List({ scroller: this.listScroller }) {
            // 遍历每个日期分组
            ForEach(this.viewModel.groupedMessageList, (group: DateGroupedMessages) => {
              // 日期标题（按年月分组）
              ListItem() {
                Text(this.formatGroupTitle(group.dateLabel))
                  .fontSize(14)
                  .fontColor('#666666')
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .padding({ left: 20, top: 16, bottom: 8 })
              }

              // 该日期下的文件列表
              ForEach(group.messages, (item: NIMMessageInfo) => {
                ListItem() {
                  FileMessageItemWithSender({
                    message: item,
                    chatInfo: this.chatInfo,
                    userInfo: this.viewModel.userMap.get(item.message.senderId),
                    onMessageItemClick: (msg) => {
                      if (msg !== undefined) {
                        downLoadAndOpenFile(msg, getContext(this), this.chatInfo)
                      }
                    },
                    onMessageMoreClick: (msg) => {
                      this.showFileActionDialog(msg)
                    },
                  })
                }
              }, (item: NIMMessageInfo) => item.message.messageClientId)
            }, (group: DateGroupedMessages) => group.getUniqueKey())

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
              } else if (!this.viewModel.hasMore && this.viewModel.groupedMessageList.length > 0) {
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
            // 滚动到底部时加载更多历史消息
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
  }

  // 格式化分组标题（按年月显示）
  private formatGroupTitle(dateLabel: string): string {
    // dateLabel 格式为 "X月X日" 或 "XXXX年X月X日"
    // 需要转换为 "XXXX年X月" 格式
    const now = new Date()
    const currentYear = now.getFullYear()

    // 匹配年月日
    const fullMatch = dateLabel.match(/(\d+)年(\d+)月(\d+)日/)
    const shortMatch = dateLabel.match(/(\d+)月(\d+)日/)

    if (fullMatch) {
      return `${fullMatch[1]}年${fullMatch[2]}月`
    } else if (shortMatch) {
      return `${currentYear}年${shortMatch[1]}月`
    }

    return dateLabel
  }
}
