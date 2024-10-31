// 转发选择页面数据模型
@ObservedV2
export class ConversationSelectModel {
  // 会话id
  conversationId?: string
  // 会话名称
  name?: string
  // 会话头像
  avatar?: ResourceStr
  // 是否已选中
  @Trace isSelected: boolean = false
  // 会话人数，用于展示群人数（单聊默认为 0，群聊为群人数）
  memberCount: number = 0
}