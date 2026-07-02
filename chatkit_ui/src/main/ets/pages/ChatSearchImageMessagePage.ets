/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import { Logger } from '@nimkit/common';
import { CommonEmptyResult, ImagesIndexModel, ImageViewDialog, NavigationBackBuilder, NECommonUtils, } from '@nimkit/common'
import { ChatSearchImageMessageParams, ChatSearchImageMessageViewModel, DateGroupedMessages } from '../viewmodel/ChatSearchImageMessageViewModel'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { getMessageImageUrls } from '../common/MessageHelper'
import { MessageItemClick } from '../view/MessageItemClick'
import { ChatBaseViewModel } from '../viewmodel/ChatBaseViewModel'
import { V2NIMConversationType, V2NIMTeamType } from '@nimsdk/base'
import { ChatKitClient, conversationSelectLimitCount, ConversationSelectParam, ErrorUtils, IMKitConfigCenter, TeamRepo } from '@nimkit/chatkit'
import { ConversationSelectModel } from '@nimkit/chatkit'
import { ForwardMessageDialog } from '../view/ForwardMessageDialog'
import { ChatUserInfo } from '../model/ChatUserInfo'
import { ChatTeamInfo } from '../model/ChatTeamInfo'

// 跳转页面入口函数
@Builder
export function ChatSearchImageMessagePageBuilder() {
  ChatSearchImageMessagePage()
}

/**
 * 图片消息操作对话框
 */
@CustomDialog
struct ImageMessageActionDialog {
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
  forwardImage = () => {
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
          .onClick(this.forwardImage)

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
 * 图片消息组件
 */
@ComponentV2
struct ImageMessageItem {
  @Param message?: NIMMessageInfo = undefined
  @Param onMessageClick?: MessageItemClick = undefined
  @Local thumbUrl?: string
  @Local url?: string

  build() {
    Column() {
      Image(this.thumbUrl ?? this.url)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(4)
        .gesture(LongPressGesture().onAction((event: GestureEvent) => {
          this.onMessageClick?.onItemLongClick?.(event, this.message)
        }), GestureMask.IgnoreInternal)
    }
    .width('100%')
    .height('100%')
  }

  aboutToAppear(): void {
    this.url = this.message?.getImageUrl()
    this.message?.getImageThumbUrl().then((thumbUrl) => {
      this.thumbUrl = thumbUrl
    })
  }
}

/**
 * 图片搜索页面
 */
@ComponentV2
export struct ChatSearchImageMessagePage {
  pathStack: NavPathStack = new NavPathStack()
  // 会话Id
  conversationId?: string
  @Local viewModel: ChatSearchImageMessageViewModel = new ChatSearchImageMessageViewModel()
  @Local chatInfo: ChatTeamInfo | ChatUserInfo | undefined = undefined
  @Local imagesIndexModel?: ImagesIndexModel
  @Local tapMessage?: NIMMessageInfo
  @Local forwardMessages: NIMMessageInfo[] = []
  @Local forwardConversations: ConversationSelectModel[] = []
  @Local currentConversationName?: string
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
  // 图片预览对话框
  imageViewerDialog: CustomDialogController = new CustomDialogController({
    builder: ImageViewDialog({
      imagesIndexModel: this.imagesIndexModel
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Center,
    backgroundColor: Color.Black,
    backgroundBlurStyle: BlurStyle.NONE,
    height: '100%',
    width: '100%',
    customStyle: true,
  })
  // 长按操作对话框
  imageActionDialog?: CustomDialogController

  // 初始化数据
  async initData() {
    let params = this.pathStack.getParamByName('ChatSearchImageMessagePage') as ChatSearchImageMessageParams[]
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
      this.pathStack.removeByName('ChatSearchImageMessagePage')
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
        // 计算新增的 ListItem 数量（每个分组有2个ListItem：日期标题 + 图片网格）
        const newGroupCount = this.viewModel.groupedMessageList.length
        const addedGroups = newGroupCount - previousGroupCount
        if (addedGroups > 0) {
          // 新增的 ListItem 数量 = 新增分组数 * 2（日期标题 + 图片网格）
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
      Logger.error('ChatKitUI', 'ChatSearchImageMessagePage loadMessages error:', err)
    }
  }

  // 获取所有图片消息列表（从所有分组中收集）
  getAllImageMessages(): NIMMessageInfo[] {
    const allMessages: NIMMessageInfo[] = []
    for (const group of this.viewModel.groupedMessageList) {
      allMessages.push(...group.messages)
    }
    return allMessages
  }

  // 显示图片详情（支持左右滑动查看所有图片）
  async showImageDetail(msg?: NIMMessageInfo) {
    try {
      // 获取所有图片消息列表，支持左右滑动查看
      const allImageMessages = this.getAllImageMessages()
      const imageModel = await getMessageImageUrls(msg, undefined, allImageMessages)
      this.imagesIndexModel = imageModel
      this.imageViewerDialog.open()
    } catch (err) {
      Logger.error('ChatKitUI', 'ChatSearchImageMessagePage showImageDetail error:', err)
    }
  }

  // 显示长按操作对话框
  showImageActionDialog(msg?: NIMMessageInfo) {
    this.tapMessage = msg
    // 每次打开前重新创建 dialog，确保使用最新的 tapMessage 和回调
    this.imageActionDialog = new CustomDialogController({
      builder: ImageMessageActionDialog({
        message: this.tapMessage,
        onMessageLocateChat: this.locateChat,
        onMessageForward: this.forwardMessage
      }),
      cornerRadius: 0,
      alignment: DialogAlignment.Bottom,
      backgroundColor: Color.Transparent,
      backgroundBlurStyle: BlurStyle.NONE,
    })
    this.imageActionDialog.open()
  }

  // 计算Grid列数，根据屏幕宽度自适应
  getGridColumns(): number {
    return 4
  }

  // 计算图片item宽度
  getImageItemSize(): string {
    return '100%'
  }

  build() {
    NavDestination() {
      Column() {
        NavigationBackBuilder({
          title: $r('app.string.search_by_photo'),
          backgroundColor: $r('sys.color.white'),
          leftButtonAction: () => {
            this.pathStack.pop()
          }
        })

        if (this.viewModel.groupedMessageList.length === 0 && !this.viewModel.isLoading) {
          // 空状态展示
          CommonEmptyResult({
            emptyImage: $r('app.media.no_history'),
            tips: $r('app.string.search_image_empty_tip')
          })
            .margin({
              top: 74
            })
        } else {
          // 按日期分组的图片消息列表
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

              // 该日期下的图片网格
              ListItem() {
                Grid() {
                  ForEach(group.messages, (item: NIMMessageInfo) => {
                    GridItem() {
                      ImageMessageItem({
                        message: item,
                        onMessageClick: {
                          onItemClick: () => {
                            // 点击查看图片详情
                            this.showImageDetail(item)
                          },
                          onItemLongClick: () => {
                            // 长按显示操作菜单
                            this.showImageActionDialog(item)
                          }
                        }
                      })
                    }
                    .width('100%')
                    .aspectRatio(1)
                    .onClick(() => {
                      this.showImageDetail(item)
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
