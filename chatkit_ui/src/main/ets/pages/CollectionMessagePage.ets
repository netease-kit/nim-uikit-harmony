/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
    CommonEmptyResult,
    DoubleAlertDialog,
    ImagesIndexModel,
    ImageViewDialog,
    NavigationBackBuilder,
    NECommonUtils,
    VideoViewerDialog
} from '@nimkit/common';
import { V2NIMMessageType } from '@nimsdk/base';
import pasteboard from '@ohos.pasteboard';
import { ConversationSelectParam } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectParam';
import { ConversationSelectModel } from '@nimkit/chatkit/src/main/ets/model/ConversationSelectModel';
import {
    conversationSelectLimitCount,
    CustomMessageUtils,
    ErrorUtils,
    MergedMessageAttachment,
    mergedMessageCustomType
} from '@nimkit/chatkit';
import { ForwardMessageDialog } from '../view/ForwardMessageDialog';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { DeviceUtils } from '../common/DeviceUtils';
import { AudioPlayerManager } from '../manager/AudioPlayerManager';
import {
    downLoadAndOpenFile,
    getMessageVideoRatio,
    getMessageVideoUrl
} from '../common/MessageHelper';
import { CollectionMessageViewModel } from '../viewmodel/CollectionMessageViewModel';
import { CollectionMessageModel } from '../model/CollectionMessageModel';
import { CollectionMessageComponent } from '../view/CollectionMessageComponent';
import { common } from '@kit.AbilityKit';
import { showLocationDetail } from '../common/ChatUtils';
import { TextMessageDetailDialog } from '../view/TextMessageDetailDialog';
import { NEEmojiManager } from '../manager/NEEmojiManager';

@CustomDialog
export struct CollectionMoreActionDialog {
  @BuilderParam collectionMessageModel: CollectionMessageModel
  @BuilderParam dialogHeight: number
  @BuilderParam forwardMessageAction?: (message: NIMMessageInfo) => void
  @BuilderParam deleteCollectionMessage?: () => void
  controller?: CustomDialogController
  copyMessage = () => {
    const copyData =
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.collectionMessageModel.message?.message.text)
    pasteboard.getSystemPasteboard().setData(copyData).then(() => {
      NECommonUtils.showToast($r('app.string.copy_success'))
      this.cancel()
    })
  }
  forwardMessage = () => {
    if (this.collectionMessageModel.message) {
      this.forwardMessageAction?.(this.collectionMessageModel.message)
    }
    this.cancel()
  }
  cancel = () => {
    this.controller?.close()
  }

  build() {
    Column() {
      Column() {
        Text($r("app.string.chat_operation_delete"))
          .fontSize(14)
          .fontColor("#E6605C")
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.deleteCollectionMessage)

        if (this.collectionMessageModel.message?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
          Row()
            .height(1)
            .width('100%')
            .backgroundColor("#EFF1F4")

          Text($r("app.string.chat_operation_copy"))
            .fontSize(14)
            .fontColor("#333333")
            .textAlign(TextAlign.Center)
            .height(42)
            .width('100%')
            .onClick(this.copyMessage)
        }

        if (this.collectionMessageModel.message?.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO &&
          this.collectionMessageModel.message?.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_CALL) {
          Row()
            .height(1)
            .width('100%')
            .backgroundColor("#EFF1F4")

          Text($r("app.string.chat_operation_forward"))
            .fontSize(14)
            .fontColor("#333333")
            .textAlign(TextAlign.Center)
            .height(42)
            .width('100%')
            .onClick(this.forwardMessage)
        }
      }
      .height(this.dialogHeight)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 12, right: 12 })

      Column() {
        Text($r('app.string.mine_edit_cancel'))
          .fontSize(14)
          .fontColor("#333333")
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
    .height(this.dialogHeight + 52)
    .backgroundColor(Color.Transparent)
  }
}

@ComponentV2
export struct CollectionMessagePage {
  pathStack: NavPathStack = new NavPathStack()
  viewModel: CollectionMessageViewModel = new CollectionMessageViewModel();
  conversationId: string = '';
  @Local imagesIndexModel?: ImagesIndexModel
  @Local currentImageIndex: number = 0
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
  @Local videoFileUrl?: string
  @Local videoRatio?: number
  videoViewerDialog: CustomDialogController = new CustomDialogController({
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
  @Local tapCollectionMessage?: CollectionMessageModel
  @Local collectionMoreActionDialogHeight: number = 42
  @Local forwardMessages: NIMMessageInfo[] = []
  @Local forwardConversations: ConversationSelectModel[] = []
  @Local currentConversationName?: string
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
  deleteAlertSureAction = () => {
    if (ErrorUtils.checkNetworkAndToast() && this.tapCollectionMessage?.collection) {
      this.viewModel.deleteCollectionMessage(this.tapCollectionMessage)
    }
  }
  deleteAlertDialog?: CustomDialogController = new CustomDialogController({
    builder: DoubleAlertDialog({
      title: $r('app.string.chat_team_error_tip_title'),
      message: $r('app.string.mine_remove_collection_tip'),
      sureAction: this.deleteAlertSureAction
    }),
    cornerRadius: 14,
    backgroundColor: Color.White,
    height: 140,
    width: 270,
  })
  forwardMessageClick = () => {
    if (ErrorUtils.checkNetworkAndToast()) {
      this.pathStack.pushPath({
        name: 'ConversationSelectPage',
        param: new ConversationSelectParam([], conversationSelectLimitCount, this.forwardMessageAction)
      })
    }
  }
  deleteCollectionMessage = async () => {
    this.deleteAlertDialog?.open()
    this.collectionMoreActionDialog.close()
  }
  collectionMoreActionDialog: CustomDialogController = new CustomDialogController({
    builder: CollectionMoreActionDialog({
      collectionMessageModel: this.tapCollectionMessage,
      dialogHeight: this.collectionMoreActionDialogHeight,
      forwardMessageAction: this.forwardMessageClick,
      deleteCollectionMessage: this.deleteCollectionMessage
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Bottom,
    backgroundColor: Color.Transparent,
    backgroundBlurStyle: BlurStyle.NONE,
  })
  textMessageDetailDialog: CustomDialogController = new CustomDialogController({
    builder: TextMessageDetailDialog({
      message: this.tapCollectionMessage?.message
    }),
    cornerRadius: 0,
    alignment: DialogAlignment.Center,
    backgroundColor: Color.White,
    height: '100%',
    width: '100%',
    customStyle: true
  })
  private listScroller: Scroller = new Scroller()
  private scrollIndex: number = 0

  @Monitor("viewModel.topInsert")
  scrollToTop() {
    if (this.scrollIndex === 0) {
      this.listScroller.scrollToIndex(0)
    }
    this.viewModel.topInsert = false
  }

  forwardMessageAction = (selectedList: ConversationSelectModel[]) => {
    if (this.tapCollectionMessage?.message) {
      this.forwardMessages = [this.tapCollectionMessage.message]
      this.forwardConversations = selectedList
      this.forwardMessageDialog.open()
    }
  }

  getMoreActionDialogHeight(message?: NIMMessageInfo): number {
    let height = 42
    if (message?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
      height += 43
    }
    if (message?.message.messageType !== V2NIMMessageType.V2NIM_MESSAGE_TYPE_AUDIO) {
      height += 43
    }
    return height
  }

  aboutToAppear(): void {
    NEEmojiManager.instance.setup();
    DeviceUtils.rootDirPath = getContext(this).filesDir
  }

  async requestChatData() {
    this.viewModel.getCollectionMessageList()
  }

  async showImageDetail(msg?: NIMMessageInfo) {
    try {
      const imageModel = await this.viewModel.getMessageImageUrls(msg)
      this.imagesIndexModel = imageModel
      this.imageViewerDialog.open()
    } catch (err) {
      console.log(err)
    }
  }

  showVideoDetail(msg: NIMMessageInfo) {
    //点击视频消息前关闭所有音频
    AudioPlayerManager.instance.stopPlayAll()
    this.videoFileUrl = getMessageVideoUrl(msg)
    this.videoRatio = getMessageVideoRatio(msg)
    if (this.videoFileUrl) {
      this.videoViewerDialog.open()
    }
  }

  @Builder
  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r("app.string.chat_operation_collection"),
        backgroundColor: '#EFF1F4',
        leftButtonAction: () => {
          this.pathStack.pop()
        },
      })
      if (this.viewModel.collectionListEmpty) {
        CommonEmptyResult({
          tips: $r('app.string.mine_collection_empty')
        })
          .margin({
            top: 56 + 74,
          })
      }
      RelativeContainer() {
        List({ space: 12, scroller: this.listScroller }) {
          ForEach(this.viewModel.collectionList, (item: CollectionMessageModel) => {
            ListItem() {
              CollectionMessageComponent({
                collection: item,
                onMessageClick: {
                  onAvatarClick: undefined,
                  onItemLongClick: undefined,
                  onItemClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                    this.tapCollectionMessage = item
                    if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
                      this.showImageDetail(msg)
                    } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
                      downLoadAndOpenFile(msg, getContext(this))
                    } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
                      this.showVideoDetail(msg)
                    } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT) {
                      this.textMessageDetailDialog.open()
                    } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
                      showLocationDetail(msg, getContext(this) as common.UIAbilityContext)
                    } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_CUSTOM) {
                      const attachment = msg.message.attachment
                      if (attachment) {
                        const type = CustomMessageUtils.typeOfCustomMessage(attachment)
                        if (type === mergedMessageCustomType) {
                          let data = CustomMessageUtils.dataOfCustomMessage(attachment)
                          if (data as MergedMessageAttachment) {
                            this.pathStack.pushPath({
                              name: 'MergeMessageDetailPage',
                              param: data as MergedMessageAttachment
                            })
                          }
                        }
                      }
                    }
                  }
                },
                onMoreButtonClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                  this.tapCollectionMessage = item
                  this.collectionMoreActionDialogHeight = this.getMoreActionDialogHeight(msg)
                  this.collectionMoreActionDialog.open()
                },
              })
            }
          }, (item: CollectionMessageModel, index?: number) => item.message?.message.messageClientId)
        }
        .id("collectionPageListView")
        .cachedCount(20)
        .padding({ bottom: 56 })
        .maintainVisibleContentPosition(true)
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "__container__", align: VerticalAlign.Top },
        })
        .width('100%')
        .height('100%')
        .onScrollIndex((start: number, end: number, center: number) => {
          this.scrollIndex = start
        })
        .listDirection(Axis.Vertical)
        .onReachEnd(() => {
          if (this.viewModel.collectionList &&
            this.viewModel.collectionList.length > 0 &&
            !this.viewModel.isFinished) {
            this.viewModel.getCollectionMessageList()
          }
        })
        .scrollBar(BarState.Off)
      }
    }
    .hideTitleBar(true)
    .backgroundColor('#EFF1F4')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      let param = this.pathStack.getParamByName("CollectionMessagePage") as string[];
      if (param.length > 0) {
        this.conversationId = param[0];
        this.requestChatData();
      } else {
        this.pathStack.removeByName("CollectionMessagePage")
      }
    })
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
  }
}

// 跳转页面入口函数
@Builder
export function CollectionMessagePageBuilder() {
  CollectionMessagePage()
}
