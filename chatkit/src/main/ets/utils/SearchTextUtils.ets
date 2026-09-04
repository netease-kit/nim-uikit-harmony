/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { NEUserWithFriend } from '../model/NEUserWithFriend'
import { TeamMemberWithUser } from '../model/TeamMemberWithUser'

export class SearchTextPresentation {
  primaryMatched: boolean = false
  secondaryText: string = ''
}

export function normalizeSearchKeyword(keyword: string | undefined): string {
  return keyword?.trim() ?? ''
}

export function resolveContactSearchTextPresentation(
  userWithFriend: NEUserWithFriend,
  keyword: string
): SearchTextPresentation {
  return resolveSearchTextPresentation(
    userWithFriend.showName(),
    [
      userWithFriend.friend?.alias ?? '',
      userWithFriend.user?.name ?? '',
      userWithFriend.getAccId()
    ],
    keyword
  )
}

export function matchesContactSearchKeyword(userWithFriend: NEUserWithFriend, keyword: string): boolean {
  return matchesSearchKeyword([
    userWithFriend.friend?.alias ?? '',
    userWithFriend.user?.name ?? '',
    userWithFriend.getAccId()
  ], keyword)
}

export function getContactSearchRenderKey(userWithFriend: NEUserWithFriend, keyword: string): string {
  return [
    userWithFriend.getAccId(),
    normalizeSearchKeyword(keyword),
    userWithFriend.friend?.alias ?? '',
    userWithFriend.user?.name ?? ''
  ].join('::')
}

export function resolveTeamMemberSearchTextPresentation(
  member: TeamMemberWithUser,
  keyword: string
): SearchTextPresentation {
  return resolveSearchTextPresentation(
    member.getNickname(),
    [
      member.friendInfo?.alias ?? '',
      member.teamMember.teamNick ?? '',
      member.userInfo?.name ?? '',
      member.getAccId()
    ],
    keyword
  )
}

export function matchesTeamMemberSearchKeyword(member: TeamMemberWithUser, keyword: string): boolean {
  return matchesSearchKeyword([
    member.friendInfo?.alias ?? '',
    member.teamMember.teamNick ?? '',
    member.userInfo?.name ?? '',
    member.getAccId()
  ], keyword)
}

export function getTeamMemberSearchRenderKey(member: TeamMemberWithUser, keyword: string): string {
  return [
    member.getAccId(),
    normalizeSearchKeyword(keyword),
    member.friendInfo?.alias ?? '',
    member.teamMember.teamNick ?? '',
    member.userInfo?.name ?? ''
  ].join('::')
}

export function matchesSearchKeyword(candidateTexts: string[], keyword: string): boolean {
  return candidateTexts.some((candidateText: string): boolean => containsSearchKeyword(candidateText, keyword))
}

export function containsSearchKeyword(value: string | undefined, keyword: string): boolean {
  const normalizedKeyword = normalizeSearchKeyword(keyword).toLowerCase()
  return normalizedKeyword.length > 0 && (value?.toLowerCase().includes(normalizedKeyword) ?? false)
}

export function resolveSearchTextPresentation(
  primaryText: string,
  candidateTexts: string[],
  keyword: string
): SearchTextPresentation {
  const result = new SearchTextPresentation()
  const normalizedKeyword = normalizeSearchKeyword(keyword)
  if (normalizedKeyword.length === 0) {
    return result
  }

  result.primaryMatched = containsSearchKeyword(primaryText, normalizedKeyword)
  if (result.primaryMatched) {
    return result
  }

  for (const candidateText of candidateTexts) {
    if (candidateText !== primaryText && containsSearchKeyword(candidateText, normalizedKeyword)) {
      result.secondaryText = candidateText
      return result
    }
  }
  return result
}
