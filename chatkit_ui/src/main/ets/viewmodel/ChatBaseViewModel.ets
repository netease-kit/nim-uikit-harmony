/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ChatKitClient, ChatRepo, ConversationRepo, StorageRepo } from '@nimkit/chatkit';
import fs from '@ohos.file.fs';
import {
  V2NIMMessage,
  V2NIMMessageDeletedNotification,
  V2NIMMessageFileAttachment,
  V2NIMMessageImageAttachment,
  V2NIMMessageRevokeNotification,
  V2NIMMessageSendingState,
  V2NIMMessageType,
  V2NIMMessageVideoAttachment
} from '@nimsdk/base';
import { NIMMessageInfo } from '../model/NIMMessageInfo';
import { ChatInfo } from '../model/ChatInfo';
import '../common/MessageHelper';
import {
  getFileMessageAttachmentExt,
  getFileMessageAttachmentName,
  getMessageAttachmentPath,
  saveLocalRevokeMessage,
  saveLocalRevokeMessageFormOther
} from '../common/MessageHelper';
import { ChatConst } from '../constants/ChatConst';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileUri } from '@kit.CoreFileKit';
import { ImagesIndexModel } from '@nimkit/common';
import { openFileWithApp } from '../common/ChatUtils';
import { Context } from '@kit.AbilityKit';
import { DeviceUtils } from '../common/DeviceUtils';
import { image } from '@kit.ImageKit';

@ObservedV2
export class ChatBaseViewModel {
  @Trace
  conversationId: string = "";
  accountId: string = "";
  @Trace
  chatInfo: ChatInfo | undefined = undefined;
  isLoading = false;
  hasMore = false;
  revokeMsg: NIMMessageInfo | undefined = undefined;
  sendingMsgClientId: string = '';
  saveRevokeClientId: string = '';
  private msgDirection: number = 0;

  init(conversationId: string, chatInfo: ChatInfo) {
    this.conversationId = conversationId
    this.accountId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    this.chatInfo = chatInfo;
    ChatRepo.onReceiverMessage(this.onReceiveFun)
    ChatRepo.onSendMessage(this.onSendFun)
    ChatRepo.onDeleteMessage(this.onDeleteFun)
    ChatRepo.onRevokeMessage(this.onRevokeFun)
    // 清理未读数
    ConversationRepo.clearUnreadCountByIds([this.conversationId])
  }

  onReceiveFun = (messages: V2NIMMessage[]) => {
    let hasNew = false;
    let receiveMsg: NIMMessageInfo[] = [];
    messages.forEach((msg, index, messages) => {
      if (msg.conversationId == this.conversationId) {
        let msgInfo = this.chatInfo?.addMessage(msg);
        if (msgInfo !== undefined) {
          receiveMsg.push(msgInfo)
        }
        hasNew = true;
      }
    });
    if (hasNew) {
      this.chatInfo?.setReceiveMsg(true);
      this.toHandleReceiveMessage(receiveMsg)
    }
  }
  onSendFun = (message: V2NIMMessage): void => {
    if (message.conversationId === this.conversationId) {
      if (message.sendingState == V2NIMMessageSendingState.V2NIM_MESSAGE_SENDING_STATE_SENDING) {
        if (message.messageClientId !== this.sendingMsgClientId) {
          this.sendingMsgClientId = message.messageClientId
          this.chatInfo?.addMessage(message)
          this.chatInfo?.setReceiveMsg(true)
        }

      } else {
        this.chatInfo?.updateMessageStatus(message)
      }
    }
  }
  onDeleteFun = (messages: V2NIMMessageDeletedNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId === this.conversationId) {
        this.chatInfo?.deleteMessage(msg.messageRefer.messageClientId)
      }
    })
  }
  onRevokeFun = (messages: V2NIMMessageRevokeNotification[]) => {
    messages.forEach((msg, index, messages) => {
      if (msg.messageRefer.conversationId === this.conversationId) {
        let revokeMsg = this.chatInfo?.getMessage(msg.messageRefer.messageClientId)
        this.chatInfo?.revokeMessage(msg.messageRefer.messageClientId)
        if (this.saveRevokeClientId == revokeMsg?.message.messageServerId) {
          return
        }
        this.saveRevokeClientId = revokeMsg?.message.messageServerId ?? ''
        if (revokeMsg !== undefined && msg.messageRefer.senderId == ChatKitClient.getLoginUserId()) {
          saveLocalRevokeMessage(msg.messageRefer.conversationId, revokeMsg, true)
        } else {
          saveLocalRevokeMessageFormOther(msg.messageRefer.conversationId, msg, true)
        }
      }
    })
  }

  // 拉取历史消息
  async getMessageList(): Promise<NIMMessageInfo[]> {
    const messageList: V2NIMMessage[] = await ChatRepo.getMessageList({
      "conversationId": this.conversationId,
      "limit": ChatConst.chatMessagePageSize,
      "direction": this.msgDirection
    })
    let result: NIMMessageInfo[] = [];
    if (messageList.length == ChatConst.chatMessagePageSize) {
      this.hasMore = true;
    } else {
      this.hasMore = false;
    }
    for (let index = messageList.length - 1; index >= 0; index--) {
      let msgInfo = this.chatInfo?.addMessage(messageList[index]);
      if (msgInfo != undefined) {
        result.push(msgInfo);
      }
    }
    // 修改接受消息标志，如果有新消息则更新接受消息标志，否则列表滚动到底部
    this.chatInfo?.setReceiveMsg(true);
    return result;
  }

  toHandleReceiveMessage(message: NIMMessageInfo[]) {

  }

  canLoadMore(): boolean {
    return this.hasMore && !this.isLoading;
  }

  // 拉取历史消息
  async getMoreMessageList(anchorMsg: NIMMessageInfo): Promise<NIMMessageInfo[]> {
    if (this.isLoading) {
      return []
    }
    this.isLoading = true;
    const messageList: V2NIMMessage[] = await ChatRepo.getMessageList({
      "anchorMessage": anchorMsg.message,
      "conversationId": this.conversationId,
      "limit": ChatConst.chatMessagePageSize,
      "direction": this.msgDirection,
    })
    let result: NIMMessageInfo[] = [];
    // SDK 返回消息不太稳定，所以按照更小的值判断是否有下一页
    if (messageList.length >= ChatConst.chatMessagePageSize - 5) {
      this.hasMore = true;
    } else {
      this.hasMore = false;
    }
    for (let index = 0; index < messageList.length; index++) {
      let msg = new NIMMessageInfo(messageList[index]);
      if (index < messageList.length - 1) {
        msg.setLastMessageTime(messageList[index+1].createTime);
      }
      this.chatInfo?.msgList.unshift(msg)
      result.push(msg);
    }
    this.isLoading = false;
    return result;
  }

  deleteMessage(msg: NIMMessageInfo) {
    ChatRepo.deleteMessage(msg.message, undefined, false);
  }

  revokeMessage(msg: NIMMessageInfo) {
    ChatRepo.revokeMessage(msg.message).then(() => {
    }).catch((err: BusinessError) => {
      console.error(`netease Invoke startAbility failed, code is ${err.code}, message is ${err.message}`);
    });
  }

  clearUnreadCount() {
    ConversationRepo.clearUnreadCountByIds([this.conversationId])
  }


  // 发送文本消息
  async sendMessage(text: string) {
    const message = ChatRepo.createTextMessage(text);
    try {
      ChatRepo.sendMessage(message, this.conversationId!)
    } catch (err) {
      console.log("net ease send message error", err, message.sendingState.toString());
    }
  }

  // 发送图片消息
  async sendImageMessage(uri: string) {
    try {
      if (uri.length > 0) {
        let fileType = ""
        const subStrings = uri.split(".");
        if (subStrings.length > 0) {
          fileType = subStrings[subStrings.length - 1];
        }
        // 将文件 拷贝到 临时目录
        const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
        // （以时间戳）生成一个新的文件名
        const fileName = Date.now() + '.' + fileType
        // 通过缓存路径+文件名 拼接出完整的路径
        let fileDir = DeviceUtils.rootDirPath + '/temp/'
        const copyFilePath = fileDir + fileName
        if (!fs.accessSync(fileDir)) {
          await fs.mkdir(fileDir)
        }
        fs.copyFileSync(file.fd, copyFilePath)
        const imageSource = image.createImageSource(file.fd);
        let imageInfo = imageSource.getImageInfoSync()
        const message = await ChatRepo.createImageMessage(copyFilePath, file.name, undefined, imageInfo?.size.width,
          imageInfo?.size.height);
        ChatRepo.sendMessage(message, this.conversationId!, undefined, (percentage: number) => {
          let msgInfo = this.chatInfo?.getMessage(message.messageClientId)
          if (msgInfo !== undefined) {
            let progress = percentage * 100
            msgInfo.setDownloadProgress(progress)
            if (progress >= 100) {
              msgInfo.setDownloadProgress(-1)
            }
          }
        });
      }
    } catch (err) {
      console.log("net ease send image error", err);
    }
  }

  // 发送视频消息
  async sendVideoMessage(uri: string, width?: number, height?: number) {
    try {
      let fileType = ""
      const subStrings = uri.split(".");
      if (subStrings.length > 0) {
        fileType = subStrings[subStrings.length - 1];
      }
      // 将文件 拷贝到 临时目录
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      // （以时间戳）生成一个新的文件名
      const fileName = Date.now() + '.' + fileType
      // 通过缓存路径+文件名 拼接出完整的路径
      let fileDir = DeviceUtils.rootDirPath + '/temp/'
      const copyFilePath = fileDir + fileName
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      fs.copyFileSync(file.fd, copyFilePath)
      const message = await ChatRepo.createVideoMessage(copyFilePath, file.name, undefined, width, height);
      ChatRepo.sendMessage(message, this.conversationId!, undefined, (percentage: number) => {
        let msgInfo = this.chatInfo?.getMessage(message.messageClientId)
        if (msgInfo !== undefined) {
          let progress = percentage * 100
          msgInfo.setDownloadProgress(progress)
          if (progress >= 100) {
            msgInfo.setDownloadProgress(-1)
          }
        }
      });
    } catch (err) {
      console.log("net ease send video error", err);
    }
  }

  // 发送文件消息
  async sendFileMessage(uri: string) {
    try {
      let fileType = ""
      const subStrings = uri.split(".");
      if (subStrings.length > 0) {
        fileType = subStrings[subStrings.length - 1];
      }
      // 将文件 拷贝到 临时目录
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      // （以时间戳）生成一个新的文件名
      const fileName = Date.now() + '.' + fileType
      // 通过缓存路径+文件名 拼接出完整的路径
      let fileDir = DeviceUtils.rootDirPath + '/temp/'
      const copyFilePath = fileDir + fileName
      if (!fs.accessSync(fileDir)) {
        await fs.mkdir(fileDir)
      }
      fs.copyFileSync(file.fd, copyFilePath)
      const message = await ChatRepo.createFileMessage(copyFilePath, file.name);
      ChatRepo.sendMessage(message, this.conversationId!, undefined, (percentage: number) => {
        let msgInfo = this.chatInfo?.getMessage(message.messageClientId)
        if (msgInfo !== undefined) {
          let progress = percentage * 100
          msgInfo.setDownloadProgress(progress)
          if (progress >= 100) {
            msgInfo.setDownloadProgress(-1)
          }
        }
      });
    } catch (err) {
      console.log("net ease send file error", err);
    }
  }

  /**
   * 发送语音消息
   * @param uri
   * @param duration 单位 s
   */
  async sendAudioMessage(uri: string, duration: number) {
    try {
      const message = await ChatRepo.createAudioMessage(uri, undefined, undefined, duration * 1000);
      await ChatRepo.sendMessage(message, this.conversationId!);

    } catch (err) {
      console.log("net ease send voice error", err);
    }
  }

  downLoadAndOpenFile(msg: NIMMessageInfo, context: Context) {
    let path = getMessageAttachmentPath(msg)
    if (path !== '') {
      fs.stat(path).then((stat: fs.Stat) => {
        let uri = fileUri.getUriFromPath(path);
        let fileName = getFileMessageAttachmentName(msg);
        let fileExt = getFileMessageAttachmentExt(msg);
        openFileWithApp(uri, fileName, fileExt, context)
      }).catch((err: BusinessError) => {
        console.error("netease get file info failed with error message: " + err.message + ", error code: " + err.code);
        this.downloadAttachment(msg, path)
      });
    }
  }

  // 消息附件下载
  async downloadAttachment(msg: NIMMessageInfo, path: string) {
    if (msg.message.attachment as V2NIMMessageFileAttachment) {
      let fileAttachment = msg.message.attachment as V2NIMMessageFileAttachment;
      if (fileAttachment.url !== undefined) {
        msg.setDownloadProgress(1)
        try {
          await StorageRepo.downloadFile(fileAttachment.url, path, (progress: number) => {
            if (progress < 100) {
              this.chatInfo?.downloadProgressMap.set(msg.message.messageClientId, progress)
              msg.setDownloadProgress(progress)
            } else {
              if (progress == 100) {
                msg.setDownloadProgress(100)
              }
              msg.setDownloadProgress(-1)
              this.chatInfo?.downloadProgressMap.delete(msg.message.messageClientId)
            }
          }
          )
        } catch (err) {
          console.log('netease downloadAttachment', err)
          msg.setDownloadProgress(-1)
        }
      }
    }
  }

  onDestroy(): void {
    ChatRepo.offReceiverMessage(this.onReceiveFun)
    ChatRepo.offSendMessage(this.onSendFun)
    ChatRepo.offDeleteMessage(this.onDeleteFun)
    ChatRepo.offRevokeMessage(this.onRevokeFun)
    // 清理未读数
    ConversationRepo.clearUnreadCountByIds([this.conversationId])
  }


  /*
    获取消息列表中的图片url列表，并返回当前消息的图片的下标，用于图片查看器
   */
  async getMessageImageUrls(message?: NIMMessageInfo): Promise<ImagesIndexModel> {
    let model = new ImagesIndexModel()
    this.chatInfo?.msgList.messageData.forEach(async (msg) => {
      if (msg?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_IMAGE) {
        const imageAttach = msg.message.attachment as V2NIMMessageImageAttachment
        if (imageAttach) {
          let path = getMessageAttachmentPath(msg)

          // 本地存在（已下载）
          if (fs.accessSync(path)) {
            const uri = fileUri.getUriFromPath(path)
            model.imageUrls.push(uri)

            // 当前点击的图片
            if (msg?.message.messageClientId === message?.message.messageClientId) {
              model.currentIndex = model.imageUrls.length - 1
            }
          } else if (imageAttach.url) {
            // 未下载
            // 先展示缩略图
            const imageThumbUrl = ChatKitClient.nim.storageUtil?.imageThumbUrl(imageAttach.url, 350)
            if (imageThumbUrl) {
              model.imageUrls.push(imageThumbUrl)

              // 当前点击的图片
              if (msg?.message.messageClientId === message?.message.messageClientId) {
                model.currentIndex = model.imageUrls.length - 1
              }

              // 下载后替换为原图
              try {
                let path = getMessageAttachmentPath(msg)
                await this.downloadAttachment(msg, path)

                if (fs.accessSync(path)) {
                  const uri = fileUri.getUriFromPath(path)
                  const imageIndex = model.imageUrls.indexOf(imageThumbUrl)
                  model.imageUrls[imageIndex] = uri
                }
              } catch (err) {
                console.log('netease getMessageImageUrls', err)
              }
            }
          }
        }
      }
    })
    return model
  }

  /*
    获取消息的视频 url，用于视频查看器
   */
  getMessageVideoUrl(msg: NIMMessageInfo): string | undefined {
    let path = getMessageAttachmentPath(msg)
    if (msg.downloadProgress < 0) {
      if (path !== '' && fs.accessSync(path)) {
        return path
      } else {
        this.downloadAttachment(msg, path)
        return undefined
      }
    }
    return undefined
  }

  /*
    获取消息的视频宽高比
   */
  getMessageVideoRatio(message?: NIMMessageInfo) {
    const attachment = message?.message.attachment as V2NIMMessageVideoAttachment
    if (attachment && attachment.height > 0) {
      return attachment.width / attachment.height
    }
    return 0
  }
}

