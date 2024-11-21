import { mergedMessageAvatarKey, mergedMessageNickKey } from '@nimkit/chatkit';
import { TailString } from '@nimkit/common';
import { V2NIMMessage } from '@nimsdk/base';
import { ChatInfo } from '../model/ChatInfo';

@ObservedV2
export class MergeMessageInfo extends ChatInfo {
  getServerExtensionValue(key: string, param?: string | V2NIMMessage | undefined): string {
    if (param as V2NIMMessage) {
      const message = param as V2NIMMessage
      if (message.serverExtension) {
        const remoteExt = JSON.parse(message.serverExtension) as object
        return remoteExt[key]
      }
    }
    return ""
  }

  getChatUserAvatarUrl(param?: string | V2NIMMessage | undefined): string {
    return this.getServerExtensionValue(mergedMessageAvatarKey, param)
  }

  getChatUserAvatarName(param?: string | V2NIMMessage | undefined): string {
    return TailString(this.getChatUserShowName(param))
  }

  getChatUserShowName(param?: string | V2NIMMessage): string {
    return this.getServerExtensionValue(mergedMessageNickKey, param)
  }
}