/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { IsDiscussion, NEFriendUserCache, TeamRepo } from '@nimkit/chatkit'
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

  constructor() {
    this.loadSearchData()
  }

  // 加载本地搜索需要的数据
  async loadSearchData(reloadTeamData = false) {
    // 加载好友数据
    const userFriends = NEFriendUserCache.getInstance().getFriendListNotInBlocklist()
    for (const item of userFriends) {
      if (item.user?.accountId) {
        let model = new SearchListModel({
          userInfo: item
        })
        this.friendDic.set(item.user?.accountId, model)
      }
    }

    // 加载群聊数据
    try {
      const teams = await TeamRepo.getJoinedTeamList()
      if (reloadTeamData) {
        this.teamDic.clear()
      }

      for (const item of teams) {
        let model = new SearchListModel({
          team: item
        })
        this.teamDic.set(item.teamId, model)
      }
    } catch (err) {
      console.log(err)
    }
  }

  // 搜索（本地）
  doSearch(text?: string) {
    // 清除上一次搜索结果
    this.friendData = []
    this.discussData = []
    this.seniorData = []

    if (text) {
      // 搜索好友
      this.friendDic.forEach((value, key) => {
        if (value.userInfo) {
          if (value.userInfo.showName().includes(text)) {
            this.friendData.push(value)
          } else if (value.userInfo.user?.accountId.includes(text)) {
            this.friendData.push(value)
          }
        }
      })

      // 搜索群组
      this.teamDic.forEach((value, key) => {
        const teamName = value.team?.name
        if (teamName?.includes(text)) {
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
}