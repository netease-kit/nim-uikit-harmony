/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { MergeDetailMessageComponent } from '../view/MessageComponent';
import { NEEmojiManager } from '../manager/NEEmojiManager';
import { ImagesIndexModel, ImageViewDialog, NavigationBackBuilder, VideoViewerDialog } from '@nimkit/common';
import { DeviceUtils } from '../common/DeviceUtils';
import {
  downLoadAndOpenFile,
  getMessageImageUrls,
  getMessageVideoRatio,
  getMessageVideoUrl
} from '../common/MessageHelper';
import { V2NIMMessageLocationAttachment, V2NIMMessageType } from '@nimsdk/base';
import { CustomMessageUtils, MergedMessageAttachment, mergedMessageCustomType } from '@nimkit/chatkit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AudioPlayerManager } from '../manager/AudioPlayerManager';
import { common } from '@kit.AbilityKit';
import { MergeMessageDetailViewModel } from '../viewmodel/MergeMessageDetailViewModel';
import { MergeMessageInfo } from '../model/MergeMessageInfo';
import { sceneMap } from '@kit.MapKit';

@ComponentV2
export struct MergeMessageDetailPage {
  pathStack: NavPathStack = new NavPathStack()
  @Local mergeMessageInfo: MergeMessageInfo = new MergeMessageInfo('');
  viewModel: MergeMessageDetailViewModel = new MergeMessageDetailViewModel();
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
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    NEEmojiManager.instance.setup();
    DeviceUtils.rootDirPath = getContext(this).filesDir
  }

  async requestData() {
    let param = this.pathStack.getParamByName("MergeMessageDetailPage") as MergedMessageAttachment[];
    if (param.length > 0) {
      this.viewModel.init(this.mergeMessageInfo)
      this.viewModel.loadMergeMessage(this.pathStack, param[param.length - 1])
    } else {
      this.pathStack.removeByName("MergeMessageDetailPage")
    }
  }

  async showImageDetail(msg?: NIMMessageInfo) {
    try {
      const imageModel = await getMessageImageUrls(msg, this.mergeMessageInfo)
      this.imagesIndexModel = imageModel
      this.imageViewerDialog.open()
    } catch (err) {
      console.log(err)
    }
  }

  showVideoDetail(msg: NIMMessageInfo) {
    //点击视频消息前关闭所有音频
    AudioPlayerManager.instance.stopPlayAll()
    this.videoFileUrl = getMessageVideoUrl(msg, this.mergeMessageInfo)
    this.videoRatio = getMessageVideoRatio(msg)
    if (this.videoFileUrl) {
      this.videoViewerDialog.open()
    }
  }

  showLocationDetail(msg: NIMMessageInfo) {
    let attachment = msg.message.attachment as V2NIMMessageLocationAttachment

    let queryLocationOptions: sceneMap.LocationQueryOptions = {
      location: {
        latitude: attachment.latitude,
        longitude: attachment.longitude
      },
      name: attachment.address,
      address: attachment.address,
    };
    // 拉起地点详情页
    sceneMap.queryLocation(getContext(this) as common.UIAbilityContext, queryLocationOptions).then(() => {
      console.info("netease QueryLocation", "Succeeded in querying location.");
    }).catch((err: BusinessError) => {
      console.error("netease QueryLocation", `Failed to query Location, code: ${err.code}, message: ${err.message}`);
    });
  }

  @Builder
  build() {
    NavDestination() {
      NavigationBackBuilder({
        title: $r('app.string.chatHistoryBrief'),
        backgroundColor: Color.White,
        leftButtonAction: () => {
          this.pathStack.pop()
        },
      })

      RelativeContainer() {
        List({ space: 12, scroller: this.listScroller }) {
          LazyForEach(this.mergeMessageInfo.msgList, (msg: NIMMessageInfo) => {
            ListItem() {
              MergeDetailMessageComponent({
                message: msg,
                chatUserInfo: this.mergeMessageInfo,
                onMessageClick: {
                  onAvatarClick: undefined,
                  onItemLongClick: undefined,
                  onItemClick: (event: ClickEvent, msg: NIMMessageInfo | undefined) => {
                    if (msg) {
                      if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
                        this.showImageDetail(msg)
                      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_FILE) {
                        downLoadAndOpenFile(msg, getContext(this), this.mergeMessageInfo)
                      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_VIDEO) {
                        this.showVideoDetail(msg)
                      } else if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_LOCATION) {
                        this.showLocationDetail(msg)
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
                  }
                }
              })
            }
          }, (item: NIMMessageInfo, index?: number) => item.message.messageClientId)
        }
        .id("mergeMessageDetailPageListView")
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
      }
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.requestData()
    })
  }

  aboutToDisappear(): void {
    this.viewModel.onDestroy()
  }
}

// 跳转页面入口函数
@Builder
export function MergeMessageDetailPageBuilder() {
  MergeMessageDetailPage()
}

