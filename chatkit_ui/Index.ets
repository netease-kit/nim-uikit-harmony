/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export { NEEmojiManager } from './src/main/ets/manager/NEEmojiManager'

export { ChatP2PPage } from './src/main/ets/pages/ChatP2PPage'

export { ChatKitConfig } from './src/main/ets/ChatKitConfig'

export { NIMMessageInfo } from './src/main/ets/model/NIMMessageInfo'

export { ForwardMessageDialog } from './src/main/ets/view/ForwardMessageDialog'

export { TextMessageDetailDialog } from './src/main/ets/view/TextMessageDetailDialog'

export { MessageItemClick } from './src/main/ets/view/MessageItemClick'

export { DeviceUtils } from './src/main/ets/common/DeviceUtils'

export { DateUtils } from './src/main/ets/common/DateUtils'

export { AudioPlayerManager } from './src/main/ets/manager/AudioPlayerManager'

export {
  downLoadAndOpenFile,
  getMessageImageUrls,
  getMessageVideoRatio,
  getMessageVideoUrl,
  sendMessageFailedTips
} from './src/main/ets/common/MessageHelper'

export { buildSendMessageParams } from './src/main/ets/common/SendMessageParamsHelper'

export { showLocationDetail } from './src/main/ets/common/ChatUtils'

export { pinMessageContent } from './src/main/ets/view/MessageComponentBuilder'

export { ChatKitUIClient } from './src/main/ets/ChatKitUIClient'

export { AbsCallKitClient } from './src/main/ets/AbsCallKitClient'

export { ChatSearchDateMessagePage } from './src/main/ets/pages/ChatSearchDateMessagePage'

export { ChatSearchDateMessageViewModel, ChatSearchDateMessageParams } from './src/main/ets/viewmodel/ChatSearchDateMessageViewModel'

export { TextLinkifyUtils, LinkInfo, LinkType } from './src/main/ets/utils/TextLinkifyUtils'

export { LinkClickUtils } from './src/main/ets/utils/LinkClickUtils'

export { parseTextWithLinks, TextNode, TextNodeType } from './src/main/ets/utils/TextNodeParser'
