import { V2NIMMessageAttachment } from '@nimsdk/base';
import { mergedMessageCustomType } from '../constant/Constant';
import { MergedMessageAttachment } from '../model/CustomMessageAttachment';

export class CustomMessageUtils {
  public static attachmentOfCustomMessage(attachment: V2NIMMessageAttachment) {
    if (attachment.raw) {
      try {
        let attachmentObject = JSON.parse(attachment.raw) as object
        return attachmentObject
      } catch (err) {
        console.error(err)
        return undefined
      }
    }
    return undefined
  }

  public static typeOfCustomMessage(attachment: V2NIMMessageAttachment) {
    let customAttachment = CustomMessageUtils.attachmentOfCustomMessage(attachment)
    if (customAttachment) {
      return customAttachment["type"] as number
    }
    return undefined
  }

  public static dataOfCustomMessage(attachment: V2NIMMessageAttachment) {
    let customAttachment = CustomMessageUtils.attachmentOfCustomMessage(attachment)
    let type = CustomMessageUtils.typeOfCustomMessage(attachment)
    if (type === mergedMessageCustomType) {
      return customAttachment?.["data"] as MergedMessageAttachment
    }
    return customAttachment?.["data"] as object
  }

  public static heightOfCustomMessage(attachment: V2NIMMessageAttachment) {
    let customAttachment = CustomMessageUtils.attachmentOfCustomMessage(attachment)
    if (customAttachment) {
      return customAttachment["customHeight"] as number
    }
    return undefined
  }

  /// 是否是【未知消息】
  public static isUnknownMessage(attachment?: V2NIMMessageAttachment) {
    if (attachment) {
      const customType = CustomMessageUtils.typeOfCustomMessage(attachment)
      switch (customType) {
        case mergedMessageCustomType:
          return false
        default:
          return true
      }
    }
    return false
  }
}