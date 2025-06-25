import {
  V2NIMAIModelCallResult,
  V2NIMAIModelStreamCallResult,
  V2NIMAIModelStreamCallStopParams, V2NIMAIUser,
  V2NIMLoginStatus,
  V2NIMProxyAIModelCallParams,
  V2NIMUser} from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';
import { NEAIUserCache } from '../NEAIUserCache'

export class AIRepo {
  public static listener = getContext(this).eventHub

  /**
   * 数字人拉取接口
   *
   * 注: 返回全量的本 Appkey 相关的数字人用户
   *
   * @returns 数字人用户列表
   */
  static async getAIUserList(): Promise<V2NIMAIUser[]> {
    const aiUserList: V2NIMAIUser[] | undefined = await ChatKitClient.nim.aiService?.getAIUserList()
    return aiUserList ?? [];
  }

  /**
   * AI 数字人请求代理接口
   *
   * @param params 接口入参
   */
  static async proxyAIModelCall(params: V2NIMProxyAIModelCallParams): Promise<void> {
    return await ChatKitClient.nim.aiService?.proxyAIModelCall(params)
  }

  /**
   * 停止流式输出
   *
   * @param params
   * @returns
   */
  static async stopAIModelStreamCall(params: V2NIMAIModelStreamCallStopParams): Promise<void> {
    return await ChatKitClient.nim.aiService?.stopAIModelStreamCall(params)
  }

  /**
   * AI 透传接口的响应的回调，开
   *
   * 注: 接口 proxyAIModelCall 调用完毕后, 接下来服务器响应以通知的形式下发, 端测需要触发回调提供
   *
   * @param response 本次响应的结构体
   */
  static onProxyAIModelCall(onProxyAIModelCallFn: (response: V2NIMAIModelCallResult) => void) {
    ChatKitClient.nim.messageService?.on('onProxyAIModelCall', onProxyAIModelCallFn);
  }

  /**
   * AI 透传接口的响应的回调，关
   *
   * 注: 接口 proxyAIModelCall 调用完毕后, 接下来服务器响应以通知的形式下发, 端测需要触发回调提供
   *
   * @param response 本次响应的结构体
   */
  static offProxyAIModelCall(onProxyAIModelCallFn: (response: V2NIMAIModelCallResult) => void) {
    ChatKitClient.nim.messageService?.off('onProxyAIModelCall', onProxyAIModelCallFn);
  }


  /**
   * AI 透传接口的流式响应的回调，开
   *
   * 流式过程中回调此方法，流式结束后还是会统一调用 onProxyAIModelCall 方法
   */
  static onProxyAIModelStreamCall(onProxyAIModelStreamCallFn: (data: V2NIMAIModelStreamCallResult) => void) {
    ChatKitClient.nim.messageService?.on('onProxyAIModelStreamCall', onProxyAIModelStreamCallFn);
  }

  /**
   * AI 透传接口的流式响应的回调，关
   *
   * 流式过程中回调此方法，流式结束后还是会统一调用 onProxyAIModelCall 方法
   */
  static offProxyAIModelStreamCall(onProxyAIModelStreamCallFn: (data: V2NIMAIModelStreamCallResult) => void) {
    ChatKitClient.nim.messageService?.off('onProxyAIModelStreamCall', onProxyAIModelStreamCallFn);
  }


  static async onLoginStatusFun(status: V2NIMLoginStatus): Promise<void> {
    switch (status) {
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGOUT:
        // clear ai user cache when logout
        NEAIUserCache.clear()
        NEAIUserCache.removeInstance()
        break;
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED:
        // save to cache
        NEAIUserCache.clear()
        NEAIUserCache.load()
        break;
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINING:
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_UNLOGIN:
      default:
      // doing nothing
        break;
    }
  }

  static onUserProfileChangedFun(users: V2NIMUser[]): void {
    // focus on self.serverExtension
    for (let i = 0; i < users.length; i++) {
      const user = users[i];
      if (user.accountId === ChatKitClient.getLoginUserId()) {
        NEAIUserCache.setMineUser(user)
        break;
      }
    }
    return;
  }

  static addListener() {
    // 同步监听，同步完成后获取 AI 用户列表 & 自己的用户信息
    // 用户信息变更监听，监听到自己用户信息变更后，更新 AI 用户列表的置顶情况
    // 登录监听，如果登出了则要清空 AI 用户列表
    ChatKitClient.nim.loginService.on('onLoginStatus', AIRepo.onLoginStatusFun)
    ChatKitClient.nim.userService?.on('onUserProfileChanged', AIRepo.onUserProfileChangedFun)
  }

  static removeListener() {
    ChatKitClient.nim.loginService.off('onLoginStatus', AIRepo.onLoginStatusFun)
    ChatKitClient.nim.userService?.off('onUserProfileChanged', AIRepo.onUserProfileChangedFun)
  }
}
