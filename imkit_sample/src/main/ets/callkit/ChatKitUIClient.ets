/*
 * Copyright (c) 2026 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { NIMInterface, V2NIMErrorMap } from "@nimsdk/base";
import { NECallParam, NECallPushConfig, NECallType, NESetupConfig } from "@yunxin/callkit";
import { NECallUI, NEResult } from "@yunxin/callkit_ui";
import { common } from "@kit.AbilityKit";
import { JSON } from "@kit.ArkTS";
import { promptAction } from "@kit.ArkUI";
import { AbsCallKitClient } from "@nimkit/chatkit_ui/Index";

/**
 * 华为推送点击动作
 */
interface HarmonyClickAction {
  actionType: number; // 0: 打开应用
}

/**
 * 华为推送通知配置
 */
interface HarmonyNotification {
  category: string; // "IM"
  clickAction: HarmonyClickAction;
}

/**
 * 华为推送载荷
 */
interface HarmonyPayload {
  notification: HarmonyNotification;
}

/**
 * 华为推送选项
 */
interface HarmonyPushOptions {
  testMessage: boolean;
}

/**
 * 华为推送 harmonyField 结构
 */
interface HarmonyField {
  payload: HarmonyPayload;
  pushOptions: HarmonyPushOptions;
}

/**
 * 华为推送数据结构
 */
interface PushPayloadData {
  harmonyField: HarmonyField;
  harmonyPushType: number; // 0: 普通推送
}

export class CallKitClient extends AbsCallKitClient {
  className():  string {
    return "CallKitClient";
  }

  public init(context: common.Context, nim: NIMInterface, appKey: string, accountId: string, token: string): void {
    // 创建配置对象
    const config: NESetupConfig = new NESetupConfig(
      context,                    // common.Context 对象
      nim,                        // NIM SDK 实例
      appKey,                     // AppKey
      accountId,                  // 当前登录的账号ID
    );

    // 初始化 CallKit 引擎
    NECallUI.getInstance().setupEngine(config);

    // 登录 CallKit
    NECallUI.getInstance().login(
      appKey, // 云信 APP_KEY
      accountId, // 账号 ID
      token          // 账号 Token（从业务服务器获取）
    )
      .then((res: NEResult) => {
        console.log(`CallKit login success, res: ${JSON.stringify(res)}`);
      })
      .catch((err: Error) => {
        console.log(`CallKit login failed, err: ${JSON.stringify(err)}`);
      });
  }

  /**
   * 生成华为推送的 pushPayload
   * 使用普通推送类型 (harmonyPushType: 0)
   */
  private generatePushPayload(): string {
    const pushPayload: PushPayloadData = {
      harmonyField: {
        payload: {
          notification: {
            category: 'IM',
            clickAction: {
              actionType: 0
            }
          }
        },
        pushOptions: {
          testMessage: true
        }
      },
      harmonyPushType: 0
    };

    return JSON.stringify(pushPayload);
  }

  public call(target: string, callType: number): void {
    // 创建呼叫参数（核心：动态传入选中的callType）
    const param: NECallParam = new NECallParam(
      target, // 被叫用户账号ID
      callType// 动态赋值：音频=NECallType.AUDIO / 视频=NECallType.VIDEO
    );

    // 设置推送配置
    const pushConfig: NECallPushConfig = new NECallPushConfig();
    pushConfig.pushEnabled = true;
    pushConfig.pushTitle = '来电提醒';
    pushConfig.pushContent = callType === NECallType.AUDIO ? '您有一个音频通话' : '您有一个视频通话';
    pushConfig.pushPayload = this.generatePushPayload();
    param.pushConfig = pushConfig;

    console.info('CallKit', `call pushPayload: ${pushConfig.pushPayload}`);

    // 发起呼叫
    NECallUI.getInstance().call(param)
      .then((result: NEResult) => {
        console.info('CallKit', `call success, result: ${JSON.stringify(result)}`);
        if (result.code === 130004) {
          // Microphone media permission denied
          promptAction.showToast({ message: $r('app.string.chat_kit_call_microphone_permission_denied') })
        } else if (result.code === 130005) {
          // Camera media permission denied
          promptAction.showToast({ message: $r('app.string.chat_kit_call_camera_permission_denied') })
        }
      })
      .catch((err: Error) => {
        console.error('CallKit', `call failed, error: ${JSON.stringify(err.message)}`);
        if (err.message.includes(V2NIMErrorMap.V2NIM_ERROR_CODE_ACCOUNT_IN_BLOCK_LIST.message)) {
          promptAction.showToast({ message: $r('app.string.chat_kit_call_blocked') })
        } else if (err.message.includes(V2NIMErrorMap.V2NIM_ERROR_CODE_ILLEGAL_STATE.message)) {
          promptAction.showToast({ message: $r('app.string.chat_kit_call_illegal_state') })
        }
      });

  }
}