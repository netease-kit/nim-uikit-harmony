export interface SearchFTSHistoryAbs {
  /**
   * 获取头像链接
   * @returns
   */
  getAvatar(): string | undefined

  /**
   * 如果没头像链接的情况下，获取能生成头像图片的名字缩写
   * @returns
   */
  getAvatarName(): string

  /**
   * 获取账号
   * @returns
   */
  getAccId(): string

  /**
   * 获取显示昵称
   * @returns
   */
  getNickname(): string
}
