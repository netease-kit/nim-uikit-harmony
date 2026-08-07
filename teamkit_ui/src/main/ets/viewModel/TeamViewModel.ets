/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import {
  ChatKitClient,
  CloudConversationStrategy,
  ContactRepo,
  ConversationIdUtilRepo,
  ConversationItem,
  ConversationStrategy,
  DisposableBag,
  FriendEventRepo,
  IMKitConfigCenter,
  LocalConversationStrategy,
  SettingRepo,
  TeamEventRepo,
  TeamRepo,
  UserEventRepo
} from '@nimkit/chatkit';
import {
  V2NIMConversationType,
  V2NIMError,
  V2NIMFriend,
  V2NIMQueryDirection,
  V2NIMTeam,
  V2NIMTeamChatBannedMode,
  V2NIMTeamMember,
  V2NIMTeamMessageMuteMode,
  V2NIMTeamType,
  V2NIMUpdateSelfMemberInfoParams,
  V2NIMUser
} from '@nimsdk/base';
import { TeamMemberWithUser } from '@nimkit/chatkit';

@ObservedV2
export class TeamSettingViewModel {
  @Trace team?: V2NIMTeam
  @Trace displayAvatar: string = ''
  @Trace teamMemberList: TeamMemberWithUser[] = []
  teamId: string
  teamType: V2NIMTeamType = V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL
  @Trace mineTeamMember?: V2NIMTeamMember
  //是否消息通知
  @Trace isMessageNotify: boolean = true
  //是否置顶
  @Trace isStickTop: boolean = false
  limit: number = 100
  isSyncing: boolean = false
  private disposableBag: DisposableBag = new DisposableBag()
  private readonly cloudConversationStrategy: CloudConversationStrategy = new CloudConversationStrategy()
  private readonly localConversationStrategy: LocalConversationStrategy = new LocalConversationStrategy()
  private teamInfoRequestVersion: number = 0
  private displayAvatarVersion: number = 0

  constructor(teamId: string) {
    this.teamId = teamId
  }

  /**
   * 获取群成员，附带用户信息
   * @returns
   */
  async getTeamMember(nextToken?: string) {
    const firstPage: boolean = !nextToken
    if (firstPage) {
      if (this.isSyncing) {
        return // first page, and is syncing, ignore
      }
      this.isSyncing = true
    }

    let teamMemberResult = await TeamRepo.getTeamMembers(
      this.teamId,
      this.teamType,
      {
        limit: this.limit,
        nextToken,
        direction: V2NIMQueryDirection.V2NIM_QUERY_DIRECTION_ASC
      }
    )

    let mine =
      teamMemberResult?.memberList?.find(member => member.getAccId() === ChatKitClient.getLoginUserId())?.teamMember

    if (mine) {
      this.mineTeamMember = mine
    } else {
      this.getMineTeamMember()
    }

    if (teamMemberResult) {
      if (firstPage) {
        this.teamMemberList.splice(0, this.teamMemberList.length)
      }
      this.teamMemberList.push(...teamMemberResult.memberList)
      // 检查是否有 nextToken，如果有则继续请求下一页
      if (!teamMemberResult.finished) {
        await this.getTeamMember(teamMemberResult.nextToken)
      }
    }
    if (firstPage) {
      this.isSyncing = false // 标记所有成员已加载完成
    }
  }

  //获取自己的群成员信息
  getMineTeamMember() {
    TeamRepo.getTeamMemberListByIds(this.teamId,
      this.teamType, [ChatKitClient.getLoginUserId()]).then((members) => {
      if (members.length > 0) {
        this.mineTeamMember = members[0]
      }
    })
  }

  onSyncFinished() {
    this.getTeamMember()
    this.getTeamInfo()
  }

  onTeamInfoUpdated(team: V2NIMTeam) {
    if (team.teamId === this.teamId) {
      this.getTeamInfo(team)
    }
  }

  async onTeamMemberJoined(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let userList = await ContactRepo.getUserWithFriendByIds(members.map(member => member.accountId))
      let memberList: TeamMemberWithUser[] = members.map(e => {
        let user = userList.find((user) => user.user?.accountId === e.accountId)
        return new TeamMemberWithUser(e, user?.friend, user?.user)
      })

      this.teamMemberList.push(...memberList)
    }
  }

  onTeamMemberInfoUpdated(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let mineMember = members.find(member => member.accountId === ChatKitClient.getLoginUserId())
      if (mineMember) {
        this.mineTeamMember = mineMember
      }
    }
  }

  onTeamMemberKicked(accId: string, members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.teamMemberList = this.teamMemberList.filter(m => !removeIds.includes(m.getAccId()))
    }
  }

  onTeamMemberLeft(members: V2NIMTeamMember[]) {
    if (members[0].teamId === this.teamId) {
      let removeIds: string[] = members.map(member => member.accountId)
      this.teamMemberList = this.teamMemberList.filter(m => !removeIds.includes(m.getAccId()))
    }
  }

  onConversationChanged(updateList: ConversationItem[]) {
    updateList.forEach((conversation) => {
      if (conversation.type === V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM &&
        conversation.conversationId === ConversationIdUtilRepo.teamConversationId(this.teamId)) {
        this.isMessageNotify = !(conversation.mute ?? false)
        this.isStickTop = conversation.stickTop
      }
    })
  }

  /**
   * 好友信息变化回调 - 更新群成员列表中的好友信息
   * @param friend 变化的好友信息
   */
  onFriendInfoChanged(friend: V2NIMFriend) {
    let index = this.teamMemberList.findIndex((member) => {
      return member.getAccId() === friend.accountId
    })
    if (index >= 0) {
      let memberInfo = this.teamMemberList[index]
      this.teamMemberList.splice(index, 1)
      memberInfo.friendInfo = friend
      this.teamMemberList.splice(index, 0, memberInfo)
    }
  }

  /**
   * 用户信息变化回调 - 更新群成员列表中的用户信息（如头像、昵称等）
   * @param users 变化的用户信息列表
   */
  onUserProfileChanged(users: V2NIMUser[]) {
    users.forEach((user) => {
      let index = this.teamMemberList.findIndex((member) => {
        return member.getAccId() === user.accountId
      })
      if (index >= 0) {
        let memberInfo = this.teamMemberList[index]
        this.teamMemberList.splice(index, 1)
        memberInfo.userInfo = user
        this.teamMemberList.splice(index, 0, memberInfo)
      }
    })
  }

  initTeamInfo() {
    this.destroy()
    this.getTeamInfo();
    this.getConversationInfo();
    this.getTeamMember();
    this.disposableBag.addAll([
      TeamEventRepo.onTeamSyncFinished((): void => {
        this.onSyncFinished()
      }),
      TeamEventRepo.onTeamInfoUpdated((team: V2NIMTeam): void => {
        this.onTeamInfoUpdated(team)
      }),
      TeamEventRepo.onTeamMemberJoined((members: V2NIMTeamMember[]): void => {
        this.onTeamMemberJoined(members)
      }),
      TeamEventRepo.onTeamMemberInfoUpdated((members: V2NIMTeamMember[]): void => {
        this.onTeamMemberInfoUpdated(members)
      }),
      TeamEventRepo.onTeamMemberKicked((accId: string, members: V2NIMTeamMember[]): void => {
        this.onTeamMemberKicked(accId, members)
      }),
      TeamEventRepo.onTeamMemberLeft((members: V2NIMTeamMember[]): void => {
        this.onTeamMemberLeft(members)
      }),
      this.registerConversationChanged((updateList: ConversationItem[]): void => {
        this.onConversationChanged(updateList)
      }),
      FriendEventRepo.onFriendInfoChanged((friend: V2NIMFriend): void => {
        this.onFriendInfoChanged(friend)
      }),
      UserEventRepo.onUserProfileChanged((users: V2NIMUser[]): void => {
        this.onUserProfileChanged(users)
      })
    ])
  }

  /**
   * 获取群组信息
   * @param teamId
   * @returns
   */
  async getTeamInfo(callbackTeam?: V2NIMTeam) {
    const requestVersion = ++this.teamInfoRequestVersion
    const avatarVersion = this.displayAvatarVersion
    TeamRepo.getTeamInfo(this.teamId, this.teamType).then((team) => {
      if (requestVersion !== this.teamInfoRequestVersion) {
        return
      }
      const finalTeam = team ?? callbackTeam
      if (!finalTeam) {
        return
      }
      this.team = finalTeam
      if (avatarVersion === this.displayAvatarVersion) {
        this.displayAvatar = finalTeam.avatar ?? callbackTeam?.avatar ?? this.displayAvatar
      }
    })
  }

  applyLocalTeamAvatar(avatar: string) {
    this.displayAvatarVersion += 1
    this.displayAvatar = avatar
  }

  /**
   * 获取是否置顶和通知
   */
  getConversationInfo() {
    this.getConversationStrategy().getConversation(ConversationIdUtilRepo.teamConversationId(this.teamId))
      .then((conversation) => {
        this.isStickTop = conversation?.stickTop ?? false
      })
      .catch((e: Error) => {
        ChatKitClient.logger?.debug(`TeamSettingViewModel getConversationInfo error = ${e.message}`)
      })
    this.getTeamMessageNotify()
  }

  private async getTeamMessageNotify() {
    try {
      const muteMode = await SettingRepo.getTeamMessageMuteMode(this.teamId, this.teamType)
      this.isMessageNotify = muteMode === undefined ||
        muteMode === V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_OFF
    } catch (e) {
      ChatKitClient.logger?.debug(`TeamSettingViewModel getTeamMessageNotify error = ${e}`)
      this.isMessageNotify = true
    }
  }

  /**
   * 置顶或者取消置顶会话
   * @param stickTop 是否置顶
   */
  stickTopConversation(stickTop: boolean) {
    try {
      this.getConversationStrategy().stickTopConversation(ConversationIdUtilRepo.teamConversationId(this.teamId),
        stickTop)
      this.isStickTop = stickTop
    } catch (error) {
      this.isStickTop = !stickTop
    }
  }

  /**
   * 设置群消息是否通知
   * @param isOn
   */
  setTeamNotify(isOn: boolean) {
    try {
      SettingRepo.setTeamMessageMuteMode(this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
        isOn ? V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_OFF :
        V2NIMTeamMessageMuteMode.V2NIM_TEAM_MESSAGE_MUTE_MODE_ON)
      this.isMessageNotify = isOn
    } catch (e) {
      this.isMessageNotify = !isOn
    }

  }

  /**
   * 设置群禁言
   * @param banned
   */
  bannedTeam(banned: boolean) {
    TeamRepo.setTeamChatBannedMode(
      this.teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
      banned ? V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_NORMAL :
      V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_UNBAN
    ).catch((e: V2NIMError) => {
      ChatKitClient.logger?.debug(e.desc)
      // 禁言失败，重新请求群信息以回滚 Toggle 状态
      this.getTeamInfo()
    })
  }


  /**
   * 更新群昵称
   * @param teamNick
   */
  updateTeamNick(teamNick: string) {
    const params: V2NIMUpdateSelfMemberInfoParams = {
      teamNick: teamNick
    }
    TeamRepo.updateSelfTeamMemberInfo(this.teamId,
      V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL,
      params).then(() => {

    }).catch((e: V2NIMError) => {
      ChatKitClient.logger?.debug(`TeamSettingViewModel updateTeamNick error = ${e.message} `)
    })
  }

  destroy() {
    this.teamInfoRequestVersion += 1
    this.disposableBag.dispose()
  }

  private registerConversationChanged(callback: (updateList: ConversationItem[]) => void): () => void {
    const strategy = this.getConversationStrategy()
    strategy.onConversationChanged(callback)
    return (): void => {
      strategy.offConversationChanged(callback)
    }
  }

  private getConversationStrategy(): ConversationStrategy {
    return IMKitConfigCenter.enableLocalConversation ? this.localConversationStrategy : this.cloudConversationStrategy
  }
}
