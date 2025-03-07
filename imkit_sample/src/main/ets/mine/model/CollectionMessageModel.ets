import { NIMMessageInfo } from '@nimkit/chatkit_ui/src/main/ets/model/NIMMessageInfo';
import { V2NIMCollection } from '@nimsdk/base';

export class CollectionMessageModel {
  /// 消息对象
  message?: NIMMessageInfo
  /// 会话名称
  conversationName?: string
  /// 发送者昵称
  senderName?: string
  /// 用户头像
  avatar?: string
  /// 收藏数据对象
  collection?: V2NIMCollection
}