/**
 * SubscriptionRepo
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−06-16
 *
 * Copyright © 2025 Netease. All rights reserved.
 */

import { V2NIMLoginStatus, V2NIMUserStatus, V2NIMUserStatusSubscribeResult } from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';
import { subscriptionOnlineStateDuration } from '../constant/Constant';


@ObservedV2
export class SubscriptionRepo {
  // 状态缓存（网络断开自动清除）
  @Trace static onlineStateMap: Map<string, boolean> = new Map();
  static subscriptionArray: string[] = [];

  /**
   * 订阅用户状态，包括在线状态，或自定义状态
   * 订阅时长为30天
   * 立即生效
   * @param V2NIMSubscribeUserStatusOption 订阅用户状态请求参数
   * @returns string[] 订阅失败的 account 数组
   */
  static async subscribeUserStatus(accountId: string): Promise<string[]> {
    const failedSubscribeUsers = await ChatKitClient.nim.subscriptionService?.subscribeUserStatus({
      accountIds: [accountId],
      duration: subscriptionOnlineStateDuration,
      immediateSync: true
    });

    if (!SubscriptionRepo.subscriptionArray.includes(accountId)) {
      SubscriptionRepo.subscriptionArray.push(accountId);
    }

    return failedSubscribeUsers;
  }

  /**
   * 取消订阅用户状态。返回值为取消订阅失败的用户列表
   *
   * @param V2NIMUnsubscribeUserStatusOption 取消订阅用户状态请求参数
   * @returns string[] 取消订阅失败的 account 数组
   */
  static async unsubscribeUserStatus(accountIds?: string[]): Promise<string[]> {
    const unsubscribeFailedUsers = await ChatKitClient.nim.subscriptionService?.unsubscribeUserStatus({
      accountIds: accountIds ?? []
    });
    const unsubscribeUsers = accountIds?.filter(accountId => !unsubscribeFailedUsers.includes(accountId));
    unsubscribeUsers?.forEach(accountId => SubscriptionRepo.onlineStateMap.delete(accountId));
    return unsubscribeFailedUsers;
  }

  /**
   * 查询用户状态订阅关系。
   * 输入账号列表，查询自己订阅了哪些账号列表，返回订阅账号列表
   *
   * @param accountIds 用户列表
   * @returns V2NIMUserStatusSubscribeResult[]
   */
  static async queryUserStatusSubscriptions(accountIds?: string[]): Promise<V2NIMUserStatusSubscribeResult[]> {
    return await ChatKitClient.nim.subscriptionService?.queryUserStatusSubscriptions(accountIds);
  }

  static async onLoginStatusFun(status: V2NIMLoginStatus): Promise<void> {
    switch (status) {
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGOUT:
        break;
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED:
        //SubscriptionRepo.resubscribe();
        break;
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINING:
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_UNLOGIN:
        // 断网或者状态错误还原在线状态
        SubscriptionRepo.onlineStateMap.clear();
        break;
      default:
      // doing nothing
        break;
    }
  }

  static addListener() {
    ChatKitClient.nim.subscriptionService.on('onUserStatusChanged', (userStatusList: V2NIMUserStatus[]) => {
      userStatusList.forEach((value: V2NIMUserStatus, index: number, array: V2NIMUserStatus[]) => {
        console.info('xxxx onUserStatusChanged', value.accountId, value.statusType === 1)
        SubscriptionRepo.onlineStateMap.set(value.accountId, value.statusType === 1);
      })
    })

    ChatKitClient.nim.loginService.on('onLoginStatus', SubscriptionRepo.onLoginStatusFun);
  }

  static async resubscribe() {
    // 登陆状态，发送请求才有效
    const accountIds = SubscriptionRepo.subscriptionArray;
    if (accountIds.length === 0) {
      return;
    }
    const chunkSize: number = 100;
    if (accountIds.length <= chunkSize) {
      await ChatKitClient.nim.subscriptionService.subscribeUserStatus({
        accountIds: accountIds,
        duration: subscriptionOnlineStateDuration,
        immediateSync: true });
    } else {
      for (let i = 0; i < accountIds.length; i += chunkSize) {
        const chunk: string[] = accountIds.slice(i, i + chunkSize);
        await ChatKitClient.nim.subscriptionService.subscribeUserStatus({
          accountIds: chunk,
          duration: subscriptionOnlineStateDuration,
          immediateSync: true });
      }
    }
  }

  static removeListener() {
    ChatKitClient.nim.subscriptionService.off('onUserStatusChanged', (userStatusList: V2NIMUserStatus[]) => {
    });
  }
}