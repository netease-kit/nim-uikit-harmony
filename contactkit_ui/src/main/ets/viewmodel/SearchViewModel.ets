/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { Logger } from '@nimkit/common';
import {
  ContactRepo,
  containsSearchKeyword,
  IsDiscussion,
  matchesContactSearchKeyword,
  NEFriendUserCache,
  normalizeSearchKeyword,
  TeamRepo
} from '@nimkit/chatkit'
import { V2NIMFriend, V2NIMUser } from '@nimsdk/base'
import { SearchListModel } from '../model/SearchListModel'

@ObservedV2
export class SearchViewModel {
  /*
   *  好友数据缓存
   */
  friendDic: Map<string, SearchListModel> = new Map<string, SearchListModel>()
  /*
   *  群数据缓存
   */
  teamDic: Map<string, SearchListModel> = new Map<string, SearchListModel>()
  /*
   *  好友搜索结果
   */
  @Trace friendData: SearchListModel[] = []
  /*
   *  讨论组搜索结果
   */
  @Trace discussData: SearchListModel[] = []
  /*
   *  高级群搜索结果
   */
  @Trace seniorData: SearchListModel[] = []
  private searchKeyword: string = ''
  private destroyed: boolean = false

  updateUserInfoFun = (_users: V2NIMUser[]): void => {
    this.refreshFriendSearchResults()
  }

  updateFriendInfoFun = (_friend: V2NIMFriend): void => {
    this.refreshFriendSearchResults()
  }

  removeFriendInfoFun = (_accountId: string): void => {
    this.refreshFriendSearchResults()
  }

  blockListChangedFun = (_accountId: string): void => {
    this.refreshFriendSearchResults()
  }

  loadFriendCacheFun = (): void => {
    this.refreshFriendSearchResults()
  }

  constructor() {
    this.addListener()
    this.loadSearchData()
  }

  // 加载本地搜索需要的数据
  async loadSearchData(reloadTeamData = false) {
    this.reloadFriendData()

    // 加载群聊数据
    try {
      const teams = await TeamRepo.getJoinedTeamList()
      if (this.destroyed) {
        return
      }
      if (reloadTeamData) {
        this.teamDic.clear()
      }

      for (const item of teams) {
        let model = new SearchListModel({
          team: item
        })
        this.teamDic.set(item.teamId, model)
      }
      this.doSearch(this.searchKeyword)
    } catch (err) {
      Logger.info('ContactKit', err)
    }
  }

  // 搜索（本地）
  doSearch(text?: string) {
    // 清除上一次搜索结果
    this.friendData = []
    this.discussData = []
    this.seniorData = []

    const keyword = normalizeSearchKeyword(text)
    this.searchKeyword = keyword
    if (keyword.length > 0) {
      // 搜索好友
      this.friendDic.forEach((value, key) => {
        if (value.userInfo) {
          if (matchesContactSearchKeyword(value.userInfo, keyword)) {
            this.friendData.push(value)
          }
        }
      })

      // 搜索群组
      this.teamDic.forEach((value, key) => {
        const teamName = value.team?.name
        if (containsSearchKeyword(teamName, keyword)) {
          if (IsDiscussion(value.team)) {
            this.discussData.push(value)
          } else {
            this.seniorData.push(value)
          }
        }
      })
    }

    this.friendData.sort((s1: SearchListModel, s2: SearchListModel) => {
      if ((s1.userInfo?.showName() ?? "") < (s2.userInfo?.showName() ?? "")) {
        return -1
      }
      if ((s1.userInfo?.showName() ?? "") > (s2.userInfo?.showName() ?? "")) {
        return 1
      }
      return 0
    })

    this.discussData.sort((s1: SearchListModel, s2: SearchListModel) => {
      if ((s1.team?.name ?? "") < (s2.team?.name ?? "")) {
        return -1
      }
      if ((s1.team?.name ?? "") > (s2.team?.name ?? "")) {
        return 1
      }
      return 0
    })

    this.seniorData.sort((s1: SearchListModel, s2: SearchListModel) => {
      if ((s1.team?.name ?? "") < (s2.team?.name ?? "")) {
        return -1
      }
      if ((s1.team?.name ?? "") > (s2.team?.name ?? "")) {
        return 1
      }
      return 0
    })
  }

  matchSearchText(allText?: string, searchText?: string) {
    if (searchText) {
      allText?.indexOf(searchText)
    }
  }

  onDestroy(): void {
    this.destroyed = true
    ContactRepo.listener.off('updateUserInfo', this.updateUserInfoFun)
    ContactRepo.listener.off('updateFriendInfo', this.updateFriendInfoFun)
    ContactRepo.listener.off('removeFriendInfo', this.removeFriendInfoFun)
    ContactRepo.listener.off('addBlockAccount', this.blockListChangedFun)
    ContactRepo.listener.off('removeBlockAccount', this.blockListChangedFun)
    ContactRepo.listener.off('loadFriendCache', this.loadFriendCacheFun)
  }

  private addListener(): void {
    ContactRepo.listener.on('updateUserInfo', this.updateUserInfoFun)
    ContactRepo.listener.on('updateFriendInfo', this.updateFriendInfoFun)
    ContactRepo.listener.on('removeFriendInfo', this.removeFriendInfoFun)
    ContactRepo.listener.on('addBlockAccount', this.blockListChangedFun)
    ContactRepo.listener.on('removeBlockAccount', this.blockListChangedFun)
    ContactRepo.listener.on('loadFriendCache', this.loadFriendCacheFun)
  }

  private reloadFriendData(): void {
    this.friendDic.clear()
    const userFriends = NEFriendUserCache.getInstance().getFriendListNotInBlocklist()
    userFriends.forEach((item): void => {
      if (item.user?.accountId) {
        this.friendDic.set(item.user.accountId, new SearchListModel({
          userInfo: item
        }))
      }
    })
  }

  private refreshFriendSearchResults(): void {
    if (this.destroyed) {
      return
    }
    this.reloadFriendData()
    this.doSearch(this.searchKeyword)
  }
}
