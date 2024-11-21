// 用于显示合并后的消息的发送方Nick的key
export const mergedMessageNickKey: string = 'mergedMessageNickKey';

// 用于显示合并后的消息的发送方avatar的key
export const mergedMessageAvatarKey: string = 'mergedMessageAvatarKey';

// 合并转发消息文件名前缀
export const multiForwardFileName = "multiForward"

/// 合并转发消息最大层数(深度): 3
export let mergedMessageMaxDepth = 3

/// 合并转发消息限制条数: 100
export let mergedMessageLimitCount = 100

/// 逐条转发消息限制条数: 10
export let singleMessageLimitCount = 10

/// 批量删除消息限制条数: 50
export let deleteMessagesLimitCount = 50

/// 合并转发自定义消息 type: 101
export let mergedMessageCustomType = 101

/// 合并转发自定义消息 cellHeight: 130
export let mergedMessageCellHeight: number = 130

/// 会话选择器最大选择数量: 9
export let conversationSelectLimitCount: number = 9

// 最新操作的类型
export let keyExtensionLastOptType = "lastOpt"

// 群自定义配置参数，用于是否群中所有人都可以@所有人配置的KEY值
export let keyExtensionAtAll = "yxAllowAt"

// 群自定义配置参数，用于是否群中管理员可以@所有人，允许所有群成员@所有人
export let typeExtensionAllowAll = "all"

// 群自定义配置参数，用于是否群中管理员可以@所有人，只允许管理员@所有人
export let typeExtensionAllowManager = "manager"

/// 收藏类型与消息类型映射(在类型基础上+1000)
export let collectionTypeOffset = 1000

/// 回复消息key, 用于不使用 thread 的消息回复方案
export let keyReplyMsgKey = "yxReplyMsg"

/// 被拉入黑名单
export let errCodeInBlock = 102426

/// 非好友
export let errCodeNoFriend = 104404