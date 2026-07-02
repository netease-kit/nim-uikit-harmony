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
  static subscriptionInFlightSet: Set<string> = new Set();
  private static hasAddedListener: boolean = false;

  /**
   * 订阅用户状态，包括在线状态，或自定义状态
   * 订阅时长为30天
   * 立即生效
   * @param V2NIMSubscribeUserStatusOption 订阅用户状态请求参数
   * @returns string[] 订阅失败的 account 数组
   */
  static async subscribeUserStatus(accountId: string): Promise<string[]> {
    if (!accountId) {
      return [];
    }

    if (SubscriptionRepo.subscriptionArray.includes(accountId) ||
      SubscriptionRepo.subscriptionInFlightSet.has(accountId)) {
      return [];
    }

    SubscriptionRepo.subscriptionInFlightSet.add(accountId);
    try {
      SubscriptionRepo.addListener();
      const failedSubscribeUsers = await ChatKitClient.nim.subscriptionService?.subscribeUserStatus({
        accountIds: [accountId],
        duration: subscriptionOnlineStateDuration,
        immediateSync: true
      }) ?? [];

      if (!SubscriptionRepo.subscriptionArray.includes(accountId)) {
        SubscriptionRepo.subscriptionArray.push(accountId);
      }

      return failedSubscribeUsers;
    } finally {
      SubscriptionRepo.subscriptionInFlightSet.delete(accountId);
    }
  }

  static async subscribeUserStatusBatch(accountIds: string[]): Promise<string[]> {
    const uniqueAccountIds: string[] = SubscriptionRepo.filterSubscribableAccountIds(accountIds);
    if (uniqueAccountIds.length <= 0) {
      return [];
    }

    uniqueAccountIds.forEach((accountId: string): void => {
      SubscriptionRepo.subscriptionInFlightSet.add(accountId);
    });
    try {
      SubscriptionRepo.addListener();
      const failedSubscribeUsers: string[] = [];
      const chunkSize: number = 100;
      for (let i = 0; i < uniqueAccountIds.length; i += chunkSize) {
        const chunk: string[] = uniqueAccountIds.slice(i, i + chunkSize);
        const failedChunkUsers = await ChatKitClient.nim.subscriptionService?.subscribeUserStatus({
          accountIds: chunk,
          duration: subscriptionOnlineStateDuration,
          immediateSync: true
        }) ?? [];
        failedChunkUsers.forEach((accountId: string): void => {
          failedSubscribeUsers.push(accountId);
        });
      }

      uniqueAccountIds.forEach((accountId: string): void => {
        if (!failedSubscribeUsers.includes(accountId) &&
          !SubscriptionRepo.subscriptionArray.includes(accountId)) {
          SubscriptionRepo.subscriptionArray.push(accountId);
        }
      });
      return failedSubscribeUsers;
    } finally {
      uniqueAccountIds.forEach((accountId: string): void => {
        SubscriptionRepo.subscriptionInFlightSet.delete(accountId);
      });
    }
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
    }) ?? [];
    const unsubscribeUsers = accountIds?.filter(accountId => !unsubscribeFailedUsers.includes(accountId));
    unsubscribeUsers?.forEach((accountId: string): void => {
      SubscriptionRepo.onlineStateMap.delete(accountId);
      SubscriptionRepo.removeSubscribedAccount(accountId);
      SubscriptionRepo.subscriptionInFlightSet.delete(accountId);
    });
    return unsubscribeFailedUsers;
  }

  static getOnlineState(accountId?: string): boolean | undefined {
    if (!accountId) {
      return undefined;
    }
    return SubscriptionRepo.onlineStateMap.get(accountId);
  }

  static hasReachedSubscriptionLimit(limit: number = 3000): boolean {
    return SubscriptionRepo.subscriptionArray.length >= limit;
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
        SubscriptionRepo.resetSubscriptionState();
        break;
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED:
        //SubscriptionRepo.resubscribe();
        break;
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINING:
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_UNLOGIN:
        // 临时断线或重连中保留最近一次状态快照，避免会话页把已在线好友瞬间显示为离线。
        SubscriptionRepo.subscriptionInFlightSet.clear();
        break;
      default:
      // doing nothing
        break;
    }
  }

  static resetSubscriptionState(): void {
    SubscriptionRepo.onlineStateMap.clear();
    SubscriptionRepo.subscriptionArray = [];
    SubscriptionRepo.subscriptionInFlightSet.clear();
  }

  private static onUserStatusChangedFun = (userStatusList: V2NIMUserStatus[]): void => {
    userStatusList.forEach((value: V2NIMUserStatus, index: number, array: V2NIMUserStatus[]) => {
      SubscriptionRepo.onlineStateMap.set(value.accountId, value.statusType === 1);
    })
  }

  static addListener() {
    if (SubscriptionRepo.hasAddedListener) {
      return;
    }
    ChatKitClient.nim.subscriptionService?.on('onUserStatusChanged', SubscriptionRepo.onUserStatusChangedFun)
    ChatKitClient.nim.loginService.on('onLoginStatus', SubscriptionRepo.onLoginStatusFun);
    SubscriptionRepo.hasAddedListener = true;
  }

  private static filterSubscribableAccountIds(accountIds: string[]): string[] {
    const uniqueAccountIds: string[] = [];
    accountIds.forEach((accountId: string): void => {
      if (accountId &&
        !uniqueAccountIds.includes(accountId) &&
        !SubscriptionRepo.subscriptionArray.includes(accountId) &&
        !SubscriptionRepo.subscriptionInFlightSet.has(accountId)) {
        uniqueAccountIds.push(accountId);
      }
    });
    return uniqueAccountIds;
  }

  private static removeSubscribedAccount(accountId: string): void {
    const index = SubscriptionRepo.subscriptionArray.indexOf(accountId);
    if (index > -1) {
      SubscriptionRepo.subscriptionArray.splice(index, 1);
    }
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
    if (!SubscriptionRepo.hasAddedListener) {
      return;
    }
    ChatKitClient.nim.subscriptionService?.off('onUserStatusChanged', SubscriptionRepo.onUserStatusChangedFun);
    ChatKitClient.nim.loginService.off('onLoginStatus', SubscriptionRepo.onLoginStatusFun);
    SubscriptionRepo.hasAddedListener = false;
  }
}
