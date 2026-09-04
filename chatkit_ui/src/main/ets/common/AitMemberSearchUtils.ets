/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import {
  matchesTeamMemberSearchKeyword,
  resolveSearchTextPresentation,
  SearchTextPresentation,
  TeamMemberWithUser
} from '@nimkit/chatkit'
import { V2NIMAIUser } from '@nimsdk/base'

export class AitSearchViewState {
  showLoading: boolean = false
  showEmpty: boolean = false

  constructor(showLoading: boolean, showEmpty: boolean) {
    this.showLoading = showLoading
    this.showEmpty = showEmpty
  }
}

export function filterAitTeamMembers(members: TeamMemberWithUser[], keyword: string): TeamMemberWithUser[] {
  if (keyword.trim().length === 0) {
    return members
  }

  return members.filter((member: TeamMemberWithUser): boolean => {
    return matchesTeamMemberSearchKeyword(member, keyword)
  })
}

export function shouldShowAitSpecialItems(keyword: string): boolean {
  return keyword.trim().length === 0
}

export function shouldLoadAllAitTeamMembers(
  keyword: string,
  showTeamMember: boolean,
  loadedAll: boolean
): boolean {
  return keyword.trim().length > 0 && showTeamMember && !loadedAll
}

export function resolveAitSearchViewState(
  keyword: string,
  isSearching: boolean,
  searchFinished: boolean,
  resultCount: number
): AitSearchViewState {
  const hasKeyword = keyword.trim().length > 0
  return new AitSearchViewState(
    hasKeyword && isSearching,
    hasKeyword && !isSearching && searchFinished && resultCount === 0
  )
}

export function isCurrentAitSearchRequest(
  requestGeneration: number,
  currentGeneration: number,
  requestKeyword: string,
  currentKeyword: string,
  requestTeamId?: string,
  currentTeamId?: string
): boolean {
  return requestGeneration === currentGeneration &&
    requestKeyword.trim().toLowerCase() === currentKeyword.trim().toLowerCase() &&
    requestTeamId === currentTeamId
}

export function getAitAIUserShowName(aiUser: V2NIMAIUser): string {
  return aiUser.name && aiUser.name.length > 0 ? aiUser.name : aiUser.accountId
}

export function resolveAitAIUserSearchTextPresentation(
  aiUser: V2NIMAIUser,
  keyword: string
): SearchTextPresentation {
  return resolveSearchTextPresentation(
    getAitAIUserShowName(aiUser),
    [aiUser.name ?? '', aiUser.accountId],
    keyword
  )
}

export function getAitAIUserRenderKey(aiUser: V2NIMAIUser): string {
  return [
    aiUser.accountId,
    aiUser.name ?? ''
  ].join('::')
}
