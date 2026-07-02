import {
  V2NIMAIModelCallResult,
  V2NIMAIModelStreamCallResult,
  V2NIMAIModelStreamCallStopParams, V2NIMAIUser,
  V2NIMBindUserAIBotToQrCodeParams,
  V2NIMCreateUserAIBotParams,
  V2NIMCreateUserAIBotResult,
  V2NIMDeleteUserAIBotParams,
  V2NIMGetUserAIBotListParams,
  V2NIMGetUserAIBotListResult,
  V2NIMGetUserAIBotParams,
  V2NIMLoginStatus,
  V2NIMProxyAIModelCallParams,
  V2NIMRefreshUserAIBotTokenParams,
  V2NIMRefreshUserAIBotTokenResult,
  V2NIMUpdateUserAIBotParams,
  V2NIMUserAIBot,
  V2NIMUser} from '@nimsdk/base';
import { ChatKitClient } from '../ChatKitClient';
import { NEAIUserCache } from '../NEAIUserCache'
import common from '@ohos.app.ability.common';

export class AIRepo {
  private static _listener: common.EventHub | undefined = undefined;

  public static get listener(): common.EventHub {
    if (!AIRepo._listener) {
      AIRepo._listener = getContext().eventHub;
    }
    return AIRepo._listener;
  }

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
   * 创建一个用户级 AI Bot 账号
   *
   * @param params 创建参数
   * @returns 创建结果，包含 Bot 的登录密钥
   */
  static async createUserAIBot(params: V2NIMCreateUserAIBotParams): Promise<V2NIMCreateUserAIBotResult> {
    return await ChatKitClient.nim.aiService!!.createUserAIBot(params)
  }

  /**
   * 分页查询当前用户名下的所有用户级 AI Bot 账号列表
   *
   * @param params 查询参数，可选
   * @returns 查询结果，包含 Bot 列表和分页信息
   */
  static async getUserAIBotList(params?: V2NIMGetUserAIBotListParams): Promise<V2NIMGetUserAIBotListResult> {
    return await ChatKitClient.nim.aiService!!.getUserAIBotList(params)
  }

  /**
   * 更新当前用户名下的指定用户级 AI Bot 账号信息
   *
   * @param params 更新参数
   */
  static async updateUserAIBot(params: V2NIMUpdateUserAIBotParams): Promise<void> {
    return await ChatKitClient.nim.aiService!!.updateUserAIBot(params)
  }

  /**
   * 删除当前用户名下的指定用户级 AI Bot 账号
   *
   * @param params 删除参数
   */
  static async deleteUserAIBot(params: V2NIMDeleteUserAIBotParams): Promise<void> {
    return await ChatKitClient.nim.aiService!!.deleteUserAIBot(params)
  }

  /**
   * 查询指定用户级 AI Bot 账号的完整信息
   *
   * @param params 查询参数
   * @returns 完整的 Bot 账号信息
   */
  static async getUserAIBot(params: V2NIMGetUserAIBotParams): Promise<V2NIMUserAIBot> {
    return await ChatKitClient.nim.aiService!!.getUserAIBot(params)
  }

  /**
   * 通过二维码绑定用户级 AI Bot
   *
   * @param params 绑定参数
   */
  static async bindUserAIBotToQrCode(params: V2NIMBindUserAIBotToQrCodeParams): Promise<void> {
    return await ChatKitClient.nim.aiService!!.bindUserAIBotToQrCode(params)
  }

  /**
   * 刷新指定用户级 AI Bot 账号的登录密钥
   *
   * @param params 刷新参数
   * @returns 刷新结果，包含新的登录密钥
   */
  static async refreshUserAIBotToken(params: V2NIMRefreshUserAIBotTokenParams): Promise<V2NIMRefreshUserAIBotTokenResult> {
    return await ChatKitClient.nim.aiService!!.refreshUserAIBotToken(params)
  }

  /**
   * AI 透传接口的响应的回调，开
   *
   * 注: 接口 proxyAIModelCall 调用完毕后, 接下来服务器响应以通知的形式下发, 端测需要触发回调提供
   *
   * @param response 本次响应的结构体
   */
  static onProxyAIModelCall(onProxyAIModelCallFn: (response: V2NIMAIModelCallResult) => void) {
    ChatKitClient.nim.aiService?.on('onProxyAIModelCall', onProxyAIModelCallFn);
  }

  /**
   * AI 透传接口的响应的回调，关
   *
   * 注: 接口 proxyAIModelCall 调用完毕后, 接下来服务器响应以通知的形式下发, 端测需要触发回调提供
   *
   * @param response 本次响应的结构体
   */
  static offProxyAIModelCall(onProxyAIModelCallFn: (response: V2NIMAIModelCallResult) => void) {
    ChatKitClient.nim.aiService?.off('onProxyAIModelCall', onProxyAIModelCallFn);
  }


  /**
   * AI 透传接口的流式响应的回调，开
   *
   * 流式过程中回调此方法，流式结束后还是会统一调用 onProxyAIModelCall 方法
   */
  static onProxyAIModelStreamCall(onProxyAIModelStreamCallFn: (data: V2NIMAIModelStreamCallResult) => void) {
    ChatKitClient.nim.aiService?.on('onProxyAIModelStreamCall', onProxyAIModelStreamCallFn);
  }

  /**
   * AI 透传接口的流式响应的回调，关
   *
   * 流式过程中回调此方法，流式结束后还是会统一调用 onProxyAIModelCall 方法
   */
  static offProxyAIModelStreamCall(onProxyAIModelStreamCallFn: (data: V2NIMAIModelStreamCallResult) => void) {
    ChatKitClient.nim.aiService?.off('onProxyAIModelStreamCall', onProxyAIModelStreamCallFn);
  }


  static async onLoginStatusFun(status: V2NIMLoginStatus): Promise<void> {
    switch (status) {
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGOUT:
        // clear ai user cache when logout
        NEAIUserCache.clear()
        NEAIUserCache.removeInstance()
        break;
      case V2NIMLoginStatus.V2NIM_LOGIN_STATUS_LOGINED:
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
