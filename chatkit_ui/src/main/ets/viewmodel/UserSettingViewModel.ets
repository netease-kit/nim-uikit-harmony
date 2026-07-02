import { Logger } from '@nimkit/common';
import {
  buildMineServerExtensionWithAIUserPin,
  canShowAIUserPinSwitch,
  ChatKitClient,
  ConversationRepo,
  ContactRepo,
  IMKitConfigCenter,
  isAIUserPinnedByMine,
  LocalConversationRepo,
  NEAIUserCache,
  SettingRepo
} from '@nimkit/chatkit';
import { V2NIMP2PMessageMuteMode, V2NIMUser, V2NIMUserUpdateParams } from '@nimsdk/base';

@ObservedV2
export class UserSettingViewModel {
  @Trace conversationId: string = "";
  accountId: string = "";
  //是否消息通知
  @Trace isMessageNotify: boolean = false
  //是否置顶
  @Trace isStickTop: boolean = false
  //是否显示 AI 数字人 PIN 置顶开关
  @Trace canShowAIUserPinSwitch: boolean = false
  //当前 AI 数字人是否展示在会话列表顶部 AI 横栏
  @Trace isAIUserPinned: boolean = false

  async init(conversationId: string) {
    this.conversationId = conversationId
    this.accountId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)
    await this.getConversationInfo().catch((e: Error) => {
      Logger.error('ChatKitUI', e.message)
    })
    this.getAIUserPinInfo()
  }

  /**
   * 获取是否置顶和通知
   */
  async getConversationInfo() {
    try {
      if (IMKitConfigCenter.enableLocalConversation) {
        const conversation = await LocalConversationRepo.getConversation(this.conversationId)
        this.isStickTop = conversation?.stickTop ?? false
        this.isMessageNotify = !(conversation?.mute ?? false)
      } else {
        const conversation = await ConversationRepo.getConversation(this.conversationId)
        this.isStickTop = conversation?.stickTop ?? false
        this.isMessageNotify = !(conversation?.mute ?? false)
      }

    } catch (err) {
      Logger.error('ChatKitUI', err)
    }
  }

  /**
   * 置顶或者取消置顶会话
   * @param stickTop 是否置顶
   */
  async stickTopConversation(stickTop: boolean) {
    try {
      if (IMKitConfigCenter.enableLocalConversation) {
        await LocalConversationRepo.stickTopConversation(this.conversationId, stickTop)
      } else {
        await ConversationRepo.stickTopConversation(this.conversationId, stickTop)
      }
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

  getAIUserPinInfo() {
    const aiUser = NEAIUserCache.getAIUser(this.accountId)
    const mineUser = NEAIUserCache.getMineUser()
    this.canShowAIUserPinSwitch = IMKitConfigCenter.enableAI && canShowAIUserPinSwitch(aiUser)
    this.isAIUserPinned = this.canShowAIUserPinSwitch &&
      isAIUserPinnedByMine(this.accountId, mineUser?.serverExtension)
  }

  async switchPinAIUser(isOpen: boolean) {
    const mineUser = NEAIUserCache.getMineUser()
    const nextServerExtension =
      buildMineServerExtensionWithAIUserPin(mineUser?.serverExtension, this.accountId, isOpen)
    try {
      await ContactRepo.updateSelfUserProfile({
        serverExtension: nextServerExtension
      } as V2NIMUserUpdateParams)
      if (mineUser) {
        const nextMineUser: V2NIMUser = {
          accountId: mineUser.accountId,
          name: mineUser.name,
          avatar: mineUser.avatar,
          sign: mineUser.sign,
          email: mineUser.email,
          birthday: mineUser.birthday,
          mobile: mineUser.mobile,
          gender: mineUser.gender,
          serverExtension: nextServerExtension,
          createTime: mineUser.createTime,
          updateTime: mineUser.updateTime
        }
        NEAIUserCache.setMineUser(nextMineUser)
      }
      const users = await ContactRepo.getUserListFromCloud([ChatKitClient.getLoginUserId()])
      if (users.length > 0) {
        NEAIUserCache.setMineUser(users[0])
      }
      this.isAIUserPinned = isOpen
    } catch (e) {
      this.isAIUserPinned = !isOpen
    }
  }
}
