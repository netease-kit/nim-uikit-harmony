/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import { vibrator } from '@kit.SensorServiceKit';
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { CommonConstants } from '@nimkit/common';
import { SettingRepo } from '../repo/SettingRepo';
import { V2NIMMessage, V2NIMConversationType, V2NIMMessageAIStreamStatus } from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';
import notification from '@ohos.notification';

/**
 * 通知点击跳转参数
 */
export interface NotificationWantParams {
  conversationId: string;
  conversationType: number;
}

/**
 * 通知显示信息
 */
interface NotificationDisplayInfo {
  title: string;
  text: string;
}

/**
 * 通知提醒工具类
 * 用于收到新消息时触发响铃和震动
 * 
 * 判断逻辑：
 * 1. 先判断系统通知开关，如果关闭则不响铃不震动
 * 2. 再判断 SDK 的 dndOn（新消息通知开关），如果关闭则不响铃不震动
 * 3. 再判断系统铃声模式：
 *    - RINGER_MODE_SILENT(0): 静音模式，不响铃不震动
 *    - RINGER_MODE_VIBRATE(1): 震动模式，只震动不响铃
 *    - RINGER_MODE_NORMAL(2): 响铃模式，可响铃+震动（取决于用户开关）
 * 4. 最后判断用户响铃/震动开关
 */
export class NotificationHelper {
  private static readonly TAG: string = 'NotificationHelper';
  private static lastNotifyTime: number = 0;
  // 最小通知间隔，避免频繁触发（毫秒）
  private static readonly MIN_NOTIFY_INTERVAL: number = 1000;
  // AVPlayer 实例
  private static avPlayer: media.AVPlayer | undefined = undefined;
  // 通知 ID 计数器
  private static notificationId: number = 1000;
  // 通知渠道 ID
  private static readonly CHANNEL_ID: string = 'nim_message_channel';
  // 通知渠道是否已创建
  private static channelCreated: boolean = false;

  /**
   * 检查系统通知是否开启
   * @returns true 表示系统通知开启，false 表示系统通知关闭
   */
  private static async isSystemNotificationEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `isSystemNotificationEnabled error: ${JSON.stringify(error)}`);
      // 默认开启
      return true;
    }
  }

  /**
   * 获取系统铃声模式
   * @returns RINGER_MODE_SILENT(0) / RINGER_MODE_VIBRATE(1) / RINGER_MODE_NORMAL(2)
   */
  private static async getRingerMode(): Promise<audio.AudioRingMode> {
    try {
      const audioManager = audio.getAudioManager();
      const volumeManager = audioManager.getVolumeManager();
      const groupId = audio.DEFAULT_VOLUME_GROUP_ID;
      const volumeGroupManager = await volumeManager.getVolumeGroupManager(groupId);
      return await volumeGroupManager.getRingerMode();
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `getRingerMode error: ${JSON.stringify(error)}`);
      // 默认返回响铃模式
      return audio.AudioRingMode.RINGER_MODE_NORMAL;
    }
  }

  /**
   * 检查新消息通知是否开启（从 SDK 获取 dndConfig）
   * @returns true 表示通知开启，false 表示通知关闭（免打扰）
   */
  private static async isNotificationEnabled(): Promise<boolean> {
    try {
      const dndConfig = await SettingRepo.getDndConfig();
      if (dndConfig && dndConfig.dndOn) {
        // dndOn = true 表示开启免打扰，即关闭通知
        return false;
      }
      return true;
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `isNotificationEnabled error: ${JSON.stringify(error)}`);
      // 默认开启通知
      return true;
    }
  }

  /**
   * 检查会话是否设置了免打扰
   * @param conversationId 会话 ID
   * @returns true 表示会话免打扰，false 表示会话不免打扰
   */
  private static async isConversationMuted(conversationId: string): Promise<boolean> {
    try {
      const isMuted = await SettingRepo.getConversationMuteStatus(conversationId);
      return isMuted ?? false;
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `isConversationMuted error: ${JSON.stringify(error)}`);
      // 默认不免打扰
      return false;
    }
  }

  /**
   * 检查消息列表中是否有非免打扰会话的消息
   * @param messages 消息列表
   * @returns true 表示有需要通知的消息，false 表示所有消息都来自免打扰会话
   */
  private static async hasNonMutedMessage(messages: V2NIMMessage[]): Promise<boolean> {
    // 使用 Set 避免重复检查同一会话
    const checkedConversations = new Set<string>();

    for (const message of messages) {
      const conversationId = message.conversationId;
      if (!conversationId || checkedConversations.has(conversationId)) {
        continue;
      }
      checkedConversations.add(conversationId);

      const isMuted = await NotificationHelper.isConversationMuted(conversationId);
      if (!isMuted) {
        // 找到一个非免打扰会话的消息，需要通知
        return true;
      }
    }
    // 所有消息都来自免打扰会话
    return false;
  }

  /**
   * 触发新消息提醒（响铃和/或震动）
   * 判断顺序：
   * 1. 系统通知开关
   * 2. SDK 新消息通知开关（dndOn）
   * 3. 会话级别免打扰检查（P2P/Team）
   * 4. 系统铃声模式
   * 5. 用户响铃/震动开关
   * @param messages 消息列表，用于检查会话级别免打扰
   */
  static async notifyNewMessage(messages?: V2NIMMessage[]): Promise<void> {
    const now = Date.now();
    // 防止频繁触发
    if (now - NotificationHelper.lastNotifyTime < NotificationHelper.MIN_NOTIFY_INTERVAL) {
      return;
    }
    NotificationHelper.lastNotifyTime = now;

    // 1. 检查系统通知开关
    const systemNotificationEnabled = await NotificationHelper.isSystemNotificationEnabled();
    if (!systemNotificationEnabled) {
      Logger.info('ChatKit', NotificationHelper.TAG, 'System notification disabled, skip notification');
      return;
    }

    // 2. 检查 SDK 新消息通知开关
    const notificationEnabled = await NotificationHelper.isNotificationEnabled();
    if (!notificationEnabled) {
      Logger.info('ChatKit', NotificationHelper.TAG, 'Notification disabled (dndOn), skip notification');
      return;
    }

    // 3. 检查会话级别免打扰（P2P/Team）
    if (messages && messages.length > 0) {
      const hasNonMuted = await NotificationHelper.hasNonMutedMessage(messages);
      if (!hasNonMuted) {
        Logger.info('ChatKit', NotificationHelper.TAG, 'All messages are from muted conversations, skip notification');
        return;
      }
    }

    // 4. 获取系统铃声模式
    const ringerMode = await NotificationHelper.getRingerMode();
    Logger.info('ChatKit', NotificationHelper.TAG, `RingerMode: ${ringerMode}`);

    // 静音模式：不响铃不震动
    if (ringerMode === audio.AudioRingMode.RINGER_MODE_SILENT) {
      Logger.info('ChatKit', NotificationHelper.TAG, 'Silent mode, skip notification');
      return;
    }

    // 5. 从 AppStorage 读取用户配置
    const ringEnabled = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_NOTIFY_RING) ?? true;
    const vibrateEnabled = AppStorage.get<boolean>(CommonConstants.KEY_SETTING_NOTIFY_VIBRATE) ?? true;

    // 震动模式：只震动不响铃
    if (ringerMode === audio.AudioRingMode.RINGER_MODE_VIBRATE) {
      if (vibrateEnabled) {
        NotificationHelper.triggerVibrate();
      }
      return;
    }

    // 响铃模式：响铃+震动（根据用户设置）
    if (ringEnabled) {
      NotificationHelper.triggerRing();
    }
    if (vibrateEnabled) {
      NotificationHelper.triggerVibrate();
    }
  }

  /**
   * 触发震动
   */
  private static triggerVibrate(): void {
    try {
      // 使用预设震动效果
      vibrator.startVibration({
        type: 'time',
        duration: 200
      }, {
        id: 0,
        usage: 'notification'
      }, (error) => {
        if (error) {
          Logger.error('ChatKit', NotificationHelper.TAG, `Vibrate failed: ${JSON.stringify(error)}`);
        }
      });
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `Vibrate error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 触发响铃
   * 使用 AVPlayer 播放 rawfile 中的通知音
   */
  private static async triggerRing(): Promise<void> {
    try {
      // 如果正在播放，先停止
      if (NotificationHelper.avPlayer) {
        await NotificationHelper.avPlayer.reset();
      } else {
        NotificationHelper.avPlayer = await media.createAVPlayer();
        NotificationHelper.setupAVPlayerCallback(NotificationHelper.avPlayer);
      }

      // 设置 rawfile 中的通知音频
      // 使用 fdSrc 方式播放 rawfile 资源
      const context = getContext();
      const resourceManager = context.resourceManager;
      const fileDescriptor = await resourceManager.getRawFd('notification.wav');
      
      NotificationHelper.avPlayer.fdSrc = fileDescriptor;
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `Ring error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 设置 AVPlayer 回调
   */
  private static setupAVPlayerCallback(avPlayer: media.AVPlayer): void {
    avPlayer.on('error', (err) => {
      Logger.error('ChatKit', NotificationHelper.TAG, `AVPlayer error: ${err.code}, ${err.message}`);
      avPlayer.reset();
    });

    avPlayer.on('stateChange', async (state: string) => {
      switch (state) {
        case 'initialized':
          avPlayer.prepare();
          break;
        case 'prepared':
          avPlayer.play();
          break;
        case 'completed':
          avPlayer.stop();
          break;
        case 'stopped':
          avPlayer.reset();
          break;
        default:
          break;
      }
    });
  }

  /**
   * 创建通知渠道
   */
  private static async ensureNotificationChannel(): Promise<void> {
    if (NotificationHelper.channelCreated) {
      return;
    }
    try {
      // 检查是否有通知权限
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        // 请求通知权限
        await notificationManager.requestEnableNotification();
      }
      NotificationHelper.channelCreated = true;
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `ensureNotificationChannel error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 创建 WantAgent 用于点击通知后跳转
   * @param conversationId 会话 ID
   * @param conversationType 会话类型
   * @returns WantAgent 对象
   */
  private static async createWantAgent(conversationId: string, conversationType: number): Promise<WantAgent | undefined> {
    try {
      const context = getContext();
      const bundleName = context.applicationInfo.name;
      const abilityName = 'IMAbility';

      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: bundleName,
            abilityName: abilityName,
            parameters: {
              conversationId: conversationId,
              conversationType: conversationType
            }
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: NotificationHelper.notificationId,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      return await wantAgent.getWantAgent(wantAgentInfo);
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `createWantAgent error: ${JSON.stringify(error)}`);
      return undefined;
    }
  }

  /**
   * 获取通知显示内容
   * @param message 消息对象
   * @returns 通知标题和内容
   */
  private static getNotificationDisplayInfo(message: V2NIMMessage): NotificationDisplayInfo {
    const resourceManager = getContext().resourceManager
    let title = '';
    let text = '';

    // 获取发送者名称作为标题
    if (message.conversationType === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
      title = message.senderId ?? resourceManager.getStringByNameSync('notification_new_message_title')
    } else {
      // 群消息：显示群名或群 ID
      title = resourceManager.getStringByNameSync('notification_group_message_title')
    }

    if (NotificationHelper.isAIStreamMessageStreaming(message)) {
      text = resourceManager.getStringByNameSync('chat_ai_message_progressing')
      return { title, text };
    }

    // 根据消息类型显示不同内容
    switch (message.messageType) {
      case 0: // 文本消息
        text = message.text ?? resourceManager.getStringByNameSync('notification_message_type_text')
        break;
      case 1: // 图片消息
        text = resourceManager.getStringByNameSync('notification_message_type_image')
        break;
      case 2: // 音频消息
        text = resourceManager.getStringByNameSync('notification_message_type_audio')
        break;
      case 3: // 视频消息
        text = resourceManager.getStringByNameSync('notification_message_type_video')
        break;
      case 4: // 位置消息
        text = resourceManager.getStringByNameSync('notification_message_type_location')
        break;
      case 5: // 通知消息
        text = resourceManager.getStringByNameSync('notification_message_type_notification')
        break;
      case 6: // 文件消息
        text = resourceManager.getStringByNameSync('notification_message_type_file')
        break;
      default:
        text = resourceManager.getStringByNameSync('notification_message_type_text')
        break;
    }

    return { title, text };
  }

  private static isAIStreamMessageStreaming(message: V2NIMMessage): boolean {
    if (!message.aiConfig?.aiStream) {
      return false
    }
    const status = message.aiConfig.aiStreamStatus
    return status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_PLACEHOLDER ||
      status === V2NIMMessageAIStreamStatus.V2NIM_MESSAGE_AI_STREAM_STATUS_STREAMING
  }

  /**
   * 发布系统通知（带点击跳转）
   * @param message 新消息
   */
  static async publishNotification(message: V2NIMMessage): Promise<void> {
    try {
      // 如果当前正在该会话，不发通知
      if (message.conversationId === ChatKitClient.getCurrentConversationId()) {
        Logger.info('ChatKit', NotificationHelper.TAG, 'Current conversation, skip notification');
        return;
      }

      // 确保通知渠道已创建
      await NotificationHelper.ensureNotificationChannel();

      // 获取显示信息
      const displayInfo = NotificationHelper.getNotificationDisplayInfo(message);

      // 创建 WantAgent
      const notificationWantAgent = await NotificationHelper.createWantAgent(
        message.conversationId ?? '',
        message.conversationType ?? 0
      );

      // 创建通知内容
      const notificationContent: notificationManager.NotificationContent = {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: displayInfo.title,
          text: displayInfo.text
        }
      };

      // 创建通知请求
      const notificationRequest: notificationManager.NotificationRequest = {
        id: NotificationHelper.notificationId++,
        slotType: notification.SlotType.SOCIAL_COMMUNICATION,
        content: notificationContent,
        wantAgent: notificationWantAgent
      };

      // 发布通知
      await notificationManager.publish(notificationRequest);
      Logger.info('ChatKit', NotificationHelper.TAG, `Published notification for conversation: ${message.conversationId}`);
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `publishNotification error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 发布带会话信息的系统通知（供外部调用，传入消息列表）
   * @param messages 消息列表
   */
  static async publishNotificationForMessages(messages: V2NIMMessage[]): Promise<void> {
    if (messages.length === 0) {
      return;
    }
    // 只为最新的一条消息发布通知
    const latestMessage = messages[messages.length - 1];
    if (latestMessage) {
      await NotificationHelper.publishNotification(latestMessage);
    }
  }

  /**
   * 清除所有通知和角标
   */
  static async clearAllNotifications(): Promise<void> {
    try {
      // 取消所有通知
      await notificationManager.cancelAll();
      // 清除角标
      await notificationManager.setBadgeNumber(0);
      Logger.info('ChatKit', NotificationHelper.TAG, 'Cleared all notifications and badge');
    } catch (error) {
      Logger.error('ChatKit', NotificationHelper.TAG, `clearAllNotifications error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 释放资源
   */
  static async release(): Promise<void> {
    if (NotificationHelper.avPlayer) {
      await NotificationHelper.avPlayer.release();
      NotificationHelper.avPlayer = undefined;
    }
  }
}
