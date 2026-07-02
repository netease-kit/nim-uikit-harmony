/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import { Logger } from '@nimkit/common';
import { CommonEmptyResult, NavigationBackBuilder, NECommonUtils, VideoViewerDialog, } from '@nimkit/common'
import { ChatSearchVideoMessageParams, ChatSearchVideoMessageViewModel, DateGroupedMessages } from '../viewmodel/ChatSearchVideoMessageViewModel'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { getMessageVideoRatio, getMessageVideoUrl, getVideoMessageThumbnail, getVideoMessageUrl } from '../common/MessageHelper'
import { V2NIMConversationType, V2NIMMessageFileAttachment, V2NIMMessageVideoAttachment, V2NIMTeamType } from '@nimsdk/base'
import { MessageItemClick } from '../view/MessageItemClick'
import { ChatBaseViewModel } from '../viewmodel/ChatBaseViewModel'
import { ChatKitClient, conversationSelectLimitCount, ConversationSelectParam, ErrorUtils, IMKitConfigCenter, TeamRepo } from '@nimkit/chatkit'
import { ConversationSelectModel } from '@nimkit/chatkit'
import { ForwardMessageDialog } from '../view/ForwardMessageDialog'
import { ChatUserInfo } from '../model/ChatUserInfo'
import { ChatTeamInfo } from '../model/ChatTeamInfo'
import { AudioPlayerManager } from '../manager/AudioPlayerManager'
import image from '@ohos.multimedia.image'

// 跳转页面入口函数
@Builder
export function ChatSearchVideoMessagePageBuilder() {
  ChatSearchVideoMessagePage()
}

/**
 * 视频消息操作对话框
 */
@CustomDialog
struct MessageActionDialog {
  message?: NIMMessageInfo
  controller?: CustomDialogController
  // 消息定位回调
  onMessageLocateChat?: () => void
  // 转发回调
  onMessageForward?: () => void
  //实现定位到聊天
  locateChat = () => {
    this.cancel()
    this.onMessageLocateChat?.()
  }
  // 实现转发功能
  forwardVideo = () => {
    this.cancel()
    this.onMessageForward?.()
  }
  cancel = () => {
    this.controller?.close()
  }

  build() {
    Column() {
      Column() {
        Text($r('app.string.chat_history_message_operation_locate'))
          .fontSize(14)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.locateChat)

        Row()
          .height(1)
          .width('100%')
          .backgroundColor('#EFF1F4')

        Text($r('app.string.chat_operation_forward'))
          .fontSize(14)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.forwardVideo)

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
    .height(42 * 4 + 10 + 2)
    .backgroundColor(Color.Transparent)
  }
}

/**
 * 视频消息组件
 */
@ComponentV2
struct VideoMessageItem {
  @Param message?: NIMMessageInfo = undefined
  @Param onMessageClick?: MessageItemClick = undefined
  @Local videoMessageThumbnail?: image.PixelMap
  @Local durationText: string = ''

  // 格式化视频时长（毫秒转为 mm:ss 格式）
  formatDuration(durationMs: number): string {
    const totalSeconds = Math.floor(durationMs / 1000)
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
  }

  showLoading() {
    if (this.message !== undefined &&
      (this.message.message.attachment as V2NIMMessageFileAttachment).path === undefined) {
      if (this.message.downloadProgress > 0) {
        return true
      }
    }
    return false
  }

  build() {
    Stack() {
      // 视频缩略图和底部信息
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(this.videoMessageThumbnail ?? getVideoMessageUrl(this.message))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(4)
          .gesture(LongPressGesture().onAction((event: GestureEvent) => {
            this.onMessageClick?.onItemLongClick?.(event, this.message)
          }), GestureMask.IgnoreInternal)

        // 视频图标和时长
        Row() {
          Image($r('app.media.ic_chat_search_video'))
            .width(16)
            .height(16)
            .fillColor(Color.White)

          Text(this.durationText)
            .fontSize(12)
            .fontColor(Color.White)
            .margin({ left: 2 })
        }
        .padding({ left: 4, right: 4, bottom: 4 })
      }
      .width('100%')
      .height('100%')

      // 下载进度条（居中显示）
      Progress({ value: 0, total: 100, type: ProgressType.Ring })
        .width(42)
        .height(42)
        .value(this.message?.downloadProgress)
        .color(Color.White)
        .style({ strokeWidth: 3 })
        .visibility(this.showLoading() ? Visibility.Visible : Visibility.Hidden)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  aboutToAppear(): void {
    if (this.message !== undefined) {
      // 获取视频缩略图
      getVideoMessageThumbnail(this.message).then((videoMessageThumbnail) => {
        this.videoMessageThumbnail = videoMessageThumbnail
      })

      // 获取视频时长
      const attachment = this.message.message.attachment as V2NIMMessageVideoAttachment
      if (attachment && attachment.duration !== undefined) {
        this.durationText = this.formatDuration(attachment.duration)
      }
    }
  }
}

/**
 * 视频搜索页面
 */
@ComponentV2
export struct ChatSearchVideoMessagePage {
  pathStack: NavPathStack = new NavPathStack()
  // 会话Id
  conversationId?: string
  @Local viewModel: ChatSearchVideoMessageViewModel = new ChatSearchVideoMessageViewModel()
  @Local chatInfo: ChatTeamInfo | ChatUserInfo | undefined = undefined
  @Local tapMessage?: NIMMessageInfo
  @Local forwardMessages: NIMMessageInfo[] = []
  @Local forwardConversations: ConversationSelectModel[] = []
  @Local currentConversationName?: string
  @Local videoFileUrl?: string
  @Local videoRatio?: number
  // List 滚动控制器
  private listScroller: Scroller = new Scroller()

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
  //定位到聊天
  locateChat = () => {
    if (ChatBaseViewModel.currentViewModel && this.tapMessage) {
      ChatBaseViewModel.currentViewModel.setAnchorMessage(this.tapMessage)
    }
    if (this.tapMessage?.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      this.pathStack.popToName('ChatP2PPage')
    } else if (this.tapMessage?.message.conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
      this.pathStack.popToName('ChatTeamPage')
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
  // 视频预览
  videoViewerDialog?: CustomDialogController
  // 长按操作对话框
  videoActionDialog?: CustomDialogController

  // 初始化数据
  async initData() {
    let params = this.pathStack.getParamByName('ChatSearchVideoMessagePage') as ChatSearchVideoMessageParams[]
    if (params.length > 0) {
      let param = params[params.length - 1]
      this.conversationId = param.conversationId
      if (this.conversationId) {
        this.viewModel.init(this.conversationId)
        // 首次加载，滚动到底部
        await this.loadMessages(true)
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
      }
    } else {
      this.pathStack.removeByName('ChatSearchVideoMessagePage')
    }
  }

  // 加载消息
  async loadMessages(scrollToBottom: boolean = false) {
    try {
      if (ChatKitClient.connectBroken() && IMKitConfigCenter.enableCloudSearch) {
        NECommonUtils.showToast($r('app.string.chat_network_error_tips'), Alignment.Center)
        return
      }

      // 记录加载前的分组数量
      const previousGroupCount = this.viewModel.groupedMessageList.length

      await this.viewModel.searchMessages()

      // 首次加载时滚动到底部
      if (scrollToBottom && this.viewModel.groupedMessageList.length > 0) {
        // 使用 setTimeout 确保 UI 渲染完成后再滚动
        setTimeout(() => {
          this.listScroller.scrollEdge(Edge.Bottom)
        }, 100)
      } else if (previousGroupCount > 0) {
        // 加载更多时，保持当前滚动位置
        // 计算新增的 ListItem 数量（每个分组有2个ListItem：日期标题 + 视频网格）
        const newGroupCount = this.viewModel.groupedMessageList.length
        const addedGroups = newGroupCount - previousGroupCount
        if (addedGroups > 0) {
          // 新增的 ListItem 数量 = 新增分组数 * 2（日期标题 + 视频网格）
          // 再加上顶部的加载状态 ListItem（index 0）
          const addedItemCount = addedGroups * 2
          setTimeout(() => {
            // 滚动到原来的位置 + 新增的item数量
            // 原来的第一个分组现在的 index = 1（顶部加载状态） + addedItemCount
            this.listScroller.scrollToIndex(addedItemCount + 1, false, ScrollAlign.START)
          }, 50)
        }
      }
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatSearchVideoMessagePage loadMessages error:', err)
    }
  }

  //显示视频详情
  showVideoDetail(msg: NIMMessageInfo) {
    AudioPlayerManager.instance.stopPlayAll()
    this.videoFileUrl = getMessageVideoUrl(msg, this.chatInfo)
    if (this.videoFileUrl === undefined) {
      NECommonUtils.showToast($r('app.string.chat_msg_download_tips'))
      return
    }
    this.videoRatio = getMessageVideoRatio(msg)
    if (this.videoFileUrl) {
      // 每次打开前重新创建 dialog，确保使用最新的视频参数
      this.videoViewerDialog = new CustomDialogController({
        builder: VideoViewerDialog({
          videoUrl: this.videoFileUrl,
          videoRatio: this.videoRatio
        }),
        cornerRadius: 0,
        alignment: DialogAlignment.Center,
        backgroundColor: Color.Black,
        backgroundBlurStyle: BlurStyle.NONE,
        height: '100%',
        width: '100%',
        customStyle: true
      })
      this.videoViewerDialog.open()
    }
  }

  // 显示长按操作对话框
  showVideoActionDialog(msg?: NIMMessageInfo) {
    this.tapMessage = msg
    // 每次打开前重新创建 dialog，确保使用最新的 tapMessage 和回调
    this.videoActionDialog = new CustomDialogController({
      builder: MessageActionDialog({
        message: this.tapMessage,
        onMessageLocateChat: this.locateChat,
        onMessageForward: this.forwardMessage
      }),
      cornerRadius: 0,
      alignment: DialogAlignment.Bottom,
      backgroundColor: Color.Transparent,
      backgroundBlurStyle: BlurStyle.NONE,
    })
    this.videoActionDialog.open()
  }

  // 计算Grid列数，根据屏幕宽度自适应
  getGridColumns(): number {
    return 4
  }

  // 计算视频item宽度
  getImageItemSize(): string {
    return '100%'
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.search_by_video'),
          backgroundColor: $r('sys.color.white'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        if (this.viewModel.groupedMessageList.length === 0 && !this.viewModel.isLoading) {
          // 空状态展示
          CommonEmptyResult({
            emptyImage: $r('app.media.no_history'),
            tips: $r('app.string.search_video_empty_tip')
          })
            .margin({
              top: 74
            })
        } else {
          // 按日期分组的视频消息列表
          List({ scroller: this.listScroller }) {
            // 顶部加载状态
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

            // 遍历每个日期分组
            ForEach(this.viewModel.groupedMessageList, (group: DateGroupedMessages) => {
              // 日期标题
              ListItem() {
                Text(group.dateLabel)
                  .fontSize(14)
                  .fontColor('#333333')
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .padding({ left: 12, top: 16, bottom: 8 })
              }

              // 该日期下的视频网格
              ListItem() {
                Grid() {
                  ForEach(group.messages, (item: NIMMessageInfo) => {
                    GridItem() {
                      VideoMessageItem({
                        message: item,
                        onMessageClick: {
                          onItemClick: () => {
                            // 点击查看视频详情
                            this.showVideoDetail(item)
                          },
                          onItemLongClick: () => {
                            // 长按显示操作菜单
                            this.showVideoActionDialog(item)
                          }
                        }
                      })
                    }
                    .width('100%')
                    .aspectRatio(1)
                    .onClick(() => {
                      this.showVideoDetail(item)
                    })
                  }, (item: NIMMessageInfo) => item.message.messageClientId)
                }
                .columnsTemplate('1fr 1fr 1fr 1fr')
                .columnsGap(2)
                .rowsGap(2)
                .width('100%')
                .padding({ left: 2, right: 2 })
              }
            }, (group: DateGroupedMessages) => group.getUniqueKey())
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .backgroundColor($r('sys.color.white'))
          .onReachStart(() => {
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
}
