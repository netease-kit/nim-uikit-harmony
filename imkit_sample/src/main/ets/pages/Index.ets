/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import {
  AIUserAgentProvider,
  AIUserManager,
  ChatKitClient, IMKitConfigCenter,
  IMKitCustomFactory,
  MessageCallback,
  MessageSendParams,
  PushConfigManager
} from '@nimkit/chatkit';
import { ChatKitConfig, MessageReactionManager } from '@nimkit/chatkit_ui';
import {
  AppLanguageCode,
  CommonConstants,
  getCurrentSystemLanguage,
  getStoredAppLanguage,
  NECommonUtils,
  resolveEffectiveAppLanguage,
  SUPPORTED_TRANSLATION_LANGUAGES,
  TranslationLanguageCode
} from '@nimkit/common';
import i18n from '@ohos.i18n';

import { NimRepository } from '../ability/NimRepository';
import { AppConfig } from '../constants/AppConfig';
import {
  resolveLocalConversationEnabled,
  resolveReadMessageEnabled,
  resolveTeamJoinAgreeModeEnabled
} from '../manager/GlobalConfigStorage';
import { preferences } from '@kit.ArkData';
import { V2NIMAIUser, V2NIMConversationType, V2NIMSendMessageParams } from '@nimsdk/base';
import { StartupPerfDebugTimer } from '../uitrace/StartupPerfDebugTimer';
import { registerSampleStickerPackages } from '../manager/StickerSampleConfig';

const AI_SEARCH_USER_ACCOUNT: string = 'search'
const AI_TRANSLATION_USER_ACCOUNT: string = 'translation'

/** 推送跳转数据 */
interface PushJumpData {
  sessionType: string   // "p2p" | "team"
  sessionId: string     // accountId 或 teamId
}

/** 华为推送点击动作 */
interface HarmonyClickAction {
  actionType: number    // 0: 打开应用
  data: PushJumpData    // 跳转数据（JSON 对象）
}

/** 华为推送通知 */
interface HarmonyNotification {
  category: string      // "IM"
  clickAction: HarmonyClickAction
}

/** 华为推送载荷 */
interface HarmonyPayload {
  notification: HarmonyNotification
}

/** 华为推送选项 */
interface HarmonyPushOptions {
  testMessage: boolean
}

/** 华为推送字段 */
interface HarmonyField {
  payload: HarmonyPayload
  pushOptions: HarmonyPushOptions
}

/** 推送载荷数据 */
interface PushPayloadData {
  harmonyField: HarmonyField
  harmonyPushType: number  // 0
}

/**
 * 消息发送回调实现
 * 在消息发送前注入华为推送跳转参数
 */
class MessageSendCallbackImpl implements MessageCallback {
  beforeSend(sendParams: MessageSendParams): MessageSendParams | undefined {
    // 解析 conversationId 获取会话类型
    const conversationId = sendParams.conversationId
    const conversationType = ChatKitClient.nim.conversationIdUtil.parseConversationType(conversationId)
    const targetId = ChatKitClient.nim.conversationIdUtil.parseConversationTargetId(conversationId)

    // 确定 sessionType 和 sessionId
    // 注意：推送是发给对方的，对方点击后需要跳转到和发送者的会话
    // - P2P：sessionId 应该是发送者的 ID（对方点击后跳转到和发送者的会话）
    // - Team：sessionId 是群 ID（不变）
    let sessionType: string
    let sessionId: string
    if (conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      sessionType = 'p2p'
      sessionId = ChatKitClient.nim.loginService.getLoginUser()
    } else if (conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
      sessionType = 'team'
      sessionId = targetId // 群会话：sessionId 是群 ID
    } else {
      sessionType = 'p2p'
      sessionId = ChatKitClient.nim.loginService.getLoginUser()
    }

    // 构造华为推送载荷
    const pushPayloadData: PushPayloadData = {
      harmonyField: {
        payload: {
          notification: {
            category: 'IM',
            clickAction: {
              actionType: 0,
              data: {
                sessionType: sessionType,
                sessionId: sessionId
              }
            }
          }
        },
        pushOptions: {
          testMessage: true
        }
      },
      harmonyPushType: 0
    }

    // 保留原有 params 配置，添加 pushPayload
    const params: V2NIMSendMessageParams = sendParams.params ?? {}
    // 保留原有 pushConfig 配置
    params.pushConfig = params.pushConfig ?? {}
    // 设置 pushPayload（华为推送跳转参数）
    params.pushConfig.pushPayload = JSON.stringify(pushPayloadData)

    sendParams.params = params
    return sendParams
  }
}

class AIUserAgentProviderImpl implements AIUserAgentProvider {
  getAiSearchUser(users: V2NIMAIUser[]): V2NIMAIUser | undefined {
    return users.find((user: V2NIMAIUser) => user.accountId === AI_SEARCH_USER_ACCOUNT)
  }

  getAiTranslateUser(users: V2NIMAIUser[]): V2NIMAIUser | undefined {
    return users.find((user: V2NIMAIUser) => user.accountId === AI_TRANSLATION_USER_ACCOUNT)
  }

  getAiTranslateLanguages(_users: V2NIMAIUser[]): string[] {
    return []
  }
}

/**
 * Index is the entry of application and Here is a list showing three buttons,
 * click the button to jump to different pages.
 */

// 初始化 PersistentStorage，必须在 @Entry 组件加载前执行
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_EARPIECE_MODE, false);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_MESSAGE_READ_OR, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_LOCAL_CONVERSATION, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_SHOWN_ONLINE_STATE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_ANTISPAM_TIP_MESSAGE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_CLOUD_SEARCH, false);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_COLLECTION_ENABLE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_PIN_ENABLE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_TYPING_STATUS, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_ONLY_FRIEND_CALL, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_TEAM_ENABLE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_TOP_MESSAGE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_AI_STREAM, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_RICH_TEXT_MESSAGE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_REACTION_ENABLE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_LAST_READ_POSITION_ENABLE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_TEAM_MANAGER_MAX_COUNT, 10);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_PUSH_CONFIG_ENABLED, false);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_PUSH_CONFIG_CONTENT, '');
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_NOTIFY_RING, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_NOTIFY_VIBRATE, true);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_AUTO_TRANSLATION_ENABLE_TIME, 0);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_TRANSLATION_TARGET_LANGUAGE, TranslationLanguageCode.ZH_CHS);
PersistentStorage.persistProp(CommonConstants.KEY_SETTING_APP_LANGUAGE, AppLanguageCode.Auto);

@Entry
@ComponentV2
struct Index {
  pathStack: NavPathStack = new NavPathStack()
  @Local showLoginPage: boolean = false

  private resolveAutoTranslationEnableTime(): number {
    const autoTranslationEnableTime = AppStorage.get<number>(CommonConstants.KEY_SETTING_AUTO_TRANSLATION_ENABLE_TIME)
    if (typeof autoTranslationEnableTime === 'number') {
      return autoTranslationEnableTime > 0 ? autoTranslationEnableTime : 0
    }
    const legacyAutoTranslate = AppStorage.get<boolean>('KEY_SETTING_TRANSLATION_AUTO')
    return legacyAutoTranslate ? Date.now() : 0
  }

  private resolveTranslationTargetLanguage(): string {
    const storedValue = AppStorage.get<string>(CommonConstants.KEY_SETTING_TRANSLATION_TARGET_LANGUAGE)
    if (storedValue && SUPPORTED_TRANSLATION_LANGUAGES.includes(storedValue as TranslationLanguageCode)) {
      return storedValue
    }
    return TranslationLanguageCode.ZH_CHS
  }

  private resolveAppLanguage(): AppLanguageCode {
    return resolveEffectiveAppLanguage(getStoredAppLanguage(), getCurrentSystemLanguage())
  }

  private syncAppPreferredLanguage(): void {
    const storedAppLanguage = getStoredAppLanguage()
    const preferredLanguage = storedAppLanguage === AppLanguageCode.Auto ? 'default' : storedAppLanguage
    try {
      i18n.System.setAppPreferredLanguage(preferredLanguage)
    } catch (e) {
      console.warn(`setAppPreferredLanguage failed: ${e}`)
    }
  }

  login = async (accountId: string, token: string) => {
    const nimRepository = NimRepository.getInstance(getContext(this))
    try {
      StartupPerfDebugTimer.startIfNotRunning('sample.auto_login')
      StartupPerfDebugTimer.mark('sample.login.begin')
      this.logPerf('sample.login.begin')
      await nimRepository.login(accountId, token, AppConfig.appKey)
    } catch (err) {
      StartupPerfDebugTimer.fail('sample.login.failed')
      this.logPerf('sample.login.failed', `${err}`)
      this.showLoginPage = true
      const tips = getContext(this).resourceManager.getStringSync($r('app.string.login_failed').id)
      NECommonUtils.showToast(tips + err)
      console.error(err)
    }
  }

  async onPageShow(): Promise<void> {
    registerSampleStickerPackages()
    AIUserManager.setProvider(new AIUserAgentProviderImpl())
    // MessageReactionManager.addCustomEmoji(1001, $r('app.media.custom_reaction'), 'sample_custom')
    let dataPreferences: preferences.Preferences | null = null;
    const options: preferences.Options = { name: 'imkit_data' };
    dataPreferences = preferences.getPreferencesSync(getContext(this), options);
    IMKitConfigCenter.enableLocalConversation = resolveLocalConversationEnabled(
      dataPreferences.getSync(CommonConstants.KEY_SETTING_LOCAL_CONVERSATION, undefined) as boolean | undefined
    )
    IMKitConfigCenter.enableShownOnlineState = dataPreferences.getSync(CommonConstants.KEY_SETTING_SHOWN_ONLINE_STATE, true) as boolean
    IMKitConfigCenter.enableTeamJoinAgreeModelAuth = resolveTeamJoinAgreeModeEnabled(
      dataPreferences.getSync(CommonConstants.KEY_SETTING_TEAM_JOIN_AGREE_MODE, undefined) as boolean | undefined
    )
    const legacyReadMessageEnable = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_MESSAGE_READ_OR)
    const readMessageEnable = resolveReadMessageEnabled(
      dataPreferences.getSync(CommonConstants.KEY_SETTING_READ_MESSAGE, undefined) as boolean | undefined,
      legacyReadMessageEnable
    )
    IMKitConfigCenter.enableReadMessage = readMessageEnable
    ChatKitConfig.messageReadState = readMessageEnable
    AppStorage.set(CommonConstants.KEY_SETTING_MESSAGE_READ_OR, readMessageEnable)
    IMKitConfigCenter.enableAntiSpamTipMessage = AppStorage.get(CommonConstants.KEY_SETTING_ANTISPAM_TIP_MESSAGE) ?? true
    IMKitConfigCenter.enableCloudSearch = AppStorage.get(CommonConstants.KEY_SETTING_CLOUD_SEARCH) ?? false
    IMKitConfigCenter.enableCollection = AppStorage.get(CommonConstants.KEY_SETTING_COLLECTION_ENABLE) ?? true
    IMKitConfigCenter.enablePin = AppStorage.get(CommonConstants.KEY_SETTING_PIN_ENABLE) ?? true
    IMKitConfigCenter.enableTypingStatus = AppStorage.get(CommonConstants.KEY_SETTING_TYPING_STATUS) ?? true
    IMKitConfigCenter.enableOnlyFriendCall = AppStorage.get(CommonConstants.KEY_SETTING_ONLY_FRIEND_CALL) ?? true
    IMKitConfigCenter.enableTeam = AppStorage.get(CommonConstants.KEY_SETTING_TEAM_ENABLE) ?? true
    IMKitConfigCenter.enableTopMessage = AppStorage.get(CommonConstants.KEY_SETTING_TOP_MESSAGE) ?? true
    IMKitConfigCenter.enableAIStream = AppStorage.get(CommonConstants.KEY_SETTING_AI_STREAM) ?? true
    IMKitConfigCenter.enableRichTextMessage = AppStorage.get(CommonConstants.KEY_SETTING_RICH_TEXT_MESSAGE) ?? true
    ChatKitConfig.enableEmojiReaction = AppStorage.get(CommonConstants.KEY_SETTING_REACTION_ENABLE) ?? true
    ChatKitConfig.enableLastReadPosition = AppStorage.get(CommonConstants.KEY_SETTING_LAST_READ_POSITION_ENABLE) ?? true
    IMKitConfigCenter.teamManagerMaxCount = AppStorage.get(CommonConstants.KEY_SETTING_TEAM_MANAGER_MAX_COUNT) ?? 10
    IMKitConfigCenter.enableEarphoneMode = AppStorage.get(CommonConstants.KEY_SETTING_EARPIECE_MODE) ?? false
    const autoTranslationEnableTime = this.resolveAutoTranslationEnableTime()
    const translationTargetLanguage = this.resolveTranslationTargetLanguage()
    const appLanguage = this.resolveAppLanguage()
    AppStorage.set(CommonConstants.KEY_SETTING_AUTO_TRANSLATION_ENABLE_TIME, autoTranslationEnableTime)
    AppStorage.set(CommonConstants.KEY_SETTING_TRANSLATION_TARGET_LANGUAGE, translationTargetLanguage)
    AppStorage.set(CommonConstants.KEY_SETTING_APP_LANGUAGE, getStoredAppLanguage())
    IMKitConfigCenter.autoTranslationEnableTime = autoTranslationEnableTime
    IMKitConfigCenter.translationTargetLanguage = translationTargetLanguage
    this.syncAppPreferredLanguage()
    console.info(`effective app language: ${appLanguage}`)
    // 加载推送配置
    const pushConfigEnabled = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_PUSH_CONFIG_ENABLED) ?? false
    const pushConfigContent = AppStorage.get<string>(CommonConstants.KEY_SETTING_PUSH_CONFIG_CONTENT) ||
      PushConfigManager.getInstance().getDefaultConfig()
    PushConfigManager.getInstance().initConfig(pushConfigEnabled, pushConfigContent)

    if (AppConfig.userId) {
      this.login(AppConfig.userId, AppConfig.userToken)
    } else {
      this.showLoginPage = true
    }
    // 注册消息发送回调（注入华为推送跳转参数）
    IMKitCustomFactory.setMessageSendCallback(new MessageSendCallbackImpl())
  }

  build() {
    Navigation(this.pathStack) {
      if (this.showLoginPage) {
        Column() {
          Row().height(80)
          Image($r('app.media.im_uikit_icon'))
            .width(120).height(120)
          Text($r('app.string.ability_label')).fontSize(24)
            .fontColor('#333333')

          Row().height(127)

          Button($r('app.string.login'), { type: ButtonType.Normal, stateEffect: true })
            .alignSelf(ItemAlign.Center)
            .onClick(() => {
              StartupPerfDebugTimer.start('app.login_click')
              this.logPerf('app.login_click')
              this.login(AppConfig.userId, AppConfig.userToken)
            })
            .borderRadius(10)
            .height(50)
            .width('90%')
            .backgroundColor(0x337EFF)

          Row().height(200)

          Image($r('app.media.yunxin_icon'))
            .width(82).height(20)
        }
        .alignItems(HorizontalAlign.Center)
        .height('100%')
        .width('100%')
        .margin({ top: 10 })
      } else {
        Column() {
          Row().height(80)
          Image($r('app.media.im_uikit_icon'))
            .width(120).height(120)
          Text($r('app.string.ability_label')).fontSize(24)
            .fontColor('#333333')

          Row().height(12)

          Text($r('app.string.yunxin_comment')).fontSize(16)
            .fontColor('#666666')

          Row().height(330)

          Image($r('app.media.yunxin_icon'))
            .width(82).height(20)
        }
        .alignItems(HorizontalAlign.Center)
        .height('100%')
        .width('100%')
        .margin({ top: 10 })
      }
    }.mode(NavigationMode.Auto)
    .hideTitleBar(true)
  }

  private logPerf(_stage: string, _detail: string = ''): void {
  }
}
