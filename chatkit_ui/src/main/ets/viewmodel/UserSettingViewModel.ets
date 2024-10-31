import { ChatKitClient, ConversationRepo, SettingRepo } from '@nimkit/chatkit'
import { V2NIMP2PMessageMuteMode } from '@nimsdk/base'

@ObservedV2
export class UserSettingViewModel {
  @Trace conversationId: string = "";
  accountId: string = "";
  //是否消息通知
  @Trace isMessageNotify: boolean = false
  //是否置顶
  @Trace isStickTop: boolean = false

  async init(conversationId: string) {
    this.conversationId = conversationId
    this.accountId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    await this.getConversationInfo().catch((e: Error) => {
      console.error(e.message)
    })
  }

  /**
   * 获取是否置顶和通知
   */
  async getConversationInfo() {
    try {
      const conversation = await ConversationRepo.getConversation(this.conversationId)
      this.isStickTop = conversation?.stickTop ?? false
      this.isMessageNotify = !(conversation?.mute ?? false)
    } catch (err) {
      console.error(err)
    }
  }

  /**
   * 置顶或者取消置顶会话
   * @param stickTop 是否置顶
   */
  async stickTopConversation(stickTop: boolean) {
    try {
      await ConversationRepo.stickTopConversation(this.conversationId, stickTop)
      this.isStickTop = stickTop
    } catch (error) {
      this.isStickTop = !stickTop
    }
  }

  /**
   * 设置群消息是否通知
   * @param isOn
   */
  async setP2PNotify(isOn: boolean) {
    try {
      await SettingRepo.setP2PMessageMuteMode(this.accountId,
        isOn ? V2NIMP2PMessageMuteMode.V2NIM_P2P_MESSAGE_MUTE_MODE_OFF :
        V2NIMP2PMessageMuteMode.V2NIM_P2P_MESSAGE_MUTE_MODE_ON)
      this.isMessageNotify = isOn
    } catch (e) {
      this.isMessageNotify = !isOn
    }
  }
}