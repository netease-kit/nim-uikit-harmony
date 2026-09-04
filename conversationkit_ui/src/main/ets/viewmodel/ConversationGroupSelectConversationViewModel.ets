/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationResult } from '@nimkit/chatkit'
import { V2NIMConversation, V2NIMConversationOption } from '@nimsdk/base'
import {
  CONVERSATION_GROUP_SELECT_CONVERSATION_LIMIT,
  ConversationSelectionResult,
  filterAddConversationCandidatesForGroup,
  filterConversationsByKeyword,
  mergeConversationGroupMemberConversations,
  toggleConversationSelection
} from '../model/ConversationGroupModel'
import { ConversationModel } from '../model/ConversationModel'
import { CloudConversationStrategy } from '../strategy/ConversationStrategy'

@ObservedV2
export class ConversationGroupSelectConversationViewModel {
  @Trace memberConversations: V2NIMConversation[] = []
  @Trace candidateConversations: V2NIMConversation[] = []
  @Trace displayCandidates: V2NIMConversation[] = []
  @Trace selectedConversationIds: string[] = []
  @Trace keyword: string = ''
  @Trace isLoadingMembers: boolean = false
  @Trace isLoadingCandidates: boolean = false
  @Trace isMemberFinished: boolean = false
  @Trace isCandidateFinished: boolean = false
  private readonly model: ConversationModel = new ConversationModel(new CloudConversationStrategy())
  private readonly PAGE_SIZE: number = 100
  private groupId: string = ''
  private memberOffset: number = 0
  private candidateOffset: number = 0
  private currentGroupConversationIds: Set<string> = new Set()

  async initMembers(groupId: string): Promise<void> {
    this.groupId = groupId
    this.memberOffset = 0
    this.memberConversations = []
    this.currentGroupConversationIds.clear()
    this.isMemberFinished = false
    await this.loadMoreMembers()
  }

  async refreshMembers(): Promise<void> {
    if (this.groupId.length <= 0) {
      return
    }
    await this.initMembers(this.groupId)
  }

  async loadMoreMembers(): Promise<void> {
    if (this.groupId.length <= 0 || this.isLoadingMembers || this.isMemberFinished) {
      return
    }
    this.isLoadingMembers = true
    try {
      const result: ConversationResult | undefined = await this.model.getConversationListByOption(this.memberOffset, this.PAGE_SIZE,
        this.groupConversationOption())
      if (!result) {
        this.isMemberFinished = true
        return
      }
      this.memberOffset = result.offset
      this.isMemberFinished = true
      const conversations = result.conversationList as V2NIMConversation[]
      conversations.forEach((conversation: V2NIMConversation) => {
        this.currentGroupConversationIds.add(conversation.conversationId)
      })
      this.memberConversations = mergeConversationGroupMemberConversations(this.memberConversations, conversations)
    } finally {
      this.isLoadingMembers = false
    }
  }

  async initCandidates(groupId: string): Promise<void> {
    this.groupId = groupId
    this.candidateOffset = 0
    this.candidateConversations = []
    this.displayCandidates = []
    this.selectedConversationIds = []
    this.keyword = ''
    this.isCandidateFinished = false
    this.currentGroupConversationIds.clear()
    await this.loadAllCurrentGroupConversationIds()
    await this.loadMoreCandidates()
  }

  async loadMoreCandidates(): Promise<void> {
    if (this.isLoadingCandidates || this.isCandidateFinished) {
      return
    }
    this.isLoadingCandidates = true
    try {
      let shouldContinue = true
      while (shouldContinue && !this.isCandidateFinished) {
        const beforeCount = this.candidateConversations.length
        const result: ConversationResult | null = await this.model.getConversationList(this.candidateOffset, this.PAGE_SIZE)
        if (result === null) {
          this.isCandidateFinished = true
          return
        }
        this.candidateOffset = result.offset
        this.isCandidateFinished = result.finished
        const conversations = filterAddConversationCandidatesForGroup(
          result.conversationList as V2NIMConversation[],
          this.currentGroupConversationIds,
          this.groupId
        )
        this.candidateConversations = this.appendUniqueConversations(this.candidateConversations, conversations)
        this.refreshDisplayCandidates()
        shouldContinue = this.shouldContinueLoadingCandidatePage(beforeCount)
      }
    } finally {
      this.isLoadingCandidates = false
    }
  }

  search(keyword: string): void {
    this.keyword = keyword
    this.refreshDisplayCandidates()
  }

  toggleSelection(conversationId: string): boolean {
    return this.setSelection(conversationId, !this.isSelected(conversationId))
  }

  setSelection(conversationId: string, selected: boolean): boolean {
    if (this.isSelected(conversationId) === selected) {
      return false
    }
    const result: ConversationSelectionResult = toggleConversationSelection(
      this.selectedConversationIds,
      conversationId,
      CONVERSATION_GROUP_SELECT_CONVERSATION_LIMIT
    )
    this.selectedConversationIds = result.selectedIds
    return result.reachedLimit
  }

  isSelected(conversationId: string): boolean {
    return this.selectedConversationIds.includes(conversationId)
  }

  selectedCount(): number {
    return this.selectedConversationIds.length
  }

  clearSelection(): void {
    this.selectedConversationIds = []
  }

  markMembersAdded(conversationIds: string[]): void {
    conversationIds.forEach((conversationId: string) => {
      this.currentGroupConversationIds.add(conversationId)
    })
    this.candidateConversations = this.candidateConversations.filter((conversation: V2NIMConversation): boolean =>
    !this.currentGroupConversationIds.has(conversation.conversationId))
    const addedConversationIds: Set<string> = new Set(conversationIds)
    this.selectedConversationIds = this.selectedConversationIds.filter((conversationId: string): boolean =>
    !addedConversationIds.has(conversationId))
    this.refreshDisplayCandidates()
  }

  appendMemberConversations(conversations: V2NIMConversation[]): void {
    if (conversations.length <= 0) {
      return
    }
    conversations.forEach((conversation: V2NIMConversation) => {
      this.currentGroupConversationIds.add(conversation.conversationId)
    })
    this.memberConversations = mergeConversationGroupMemberConversations(this.memberConversations, conversations)
  }

  removeMemberConversations(conversationIds: string[]): void {
    if (conversationIds.length <= 0) {
      return
    }
    const removedIds: Set<string> = new Set(conversationIds)
    conversationIds.forEach((conversationId: string) => {
      this.currentGroupConversationIds.delete(conversationId)
    })
    this.memberConversations = this.memberConversations.filter((conversation: V2NIMConversation): boolean =>
    !removedIds.has(conversation.conversationId))
  }

  removeCandidateConversations(conversationIds: string[]): void {
    if (conversationIds.length <= 0) {
      return
    }
    const removedIds: Set<string> = new Set(conversationIds)
    this.candidateConversations = this.candidateConversations.filter((conversation: V2NIMConversation): boolean =>
    !removedIds.has(conversation.conversationId))
    this.selectedConversationIds = this.selectedConversationIds.filter((conversationId: string): boolean =>
    !removedIds.has(conversationId))
    this.refreshDisplayCandidates()
  }

  async refreshCandidates(preservedSelectedConversationIds: string[] = this.selectedConversationIds,
    preservedKeyword: string = this.keyword): Promise<void> {
    if (this.groupId.length <= 0) {
      return
    }
    await this.initCandidates(this.groupId)
    const candidateConversationIds: Set<string> = new Set()
    this.candidateConversations.forEach((conversation: V2NIMConversation) => {
      candidateConversationIds.add(conversation.conversationId)
    })
    this.selectedConversationIds = preservedSelectedConversationIds.filter((conversationId: string): boolean =>
    candidateConversationIds.has(conversationId))
    this.keyword = preservedKeyword
    this.refreshDisplayCandidates()
  }

  private async loadAllCurrentGroupConversationIds(): Promise<void> {
    if (this.groupId.length <= 0) {
      return
    }
    let offset = 0
    let finished = false
    while (!finished) {
      const result: ConversationResult | undefined = await this.model.getConversationListByOption(offset, this.PAGE_SIZE, this.groupConversationOption())
      if (result === undefined) {
        break
      }
      const conversations = result.conversationList as V2NIMConversation[]
      conversations.forEach((conversation: V2NIMConversation) => {
        this.currentGroupConversationIds.add(conversation.conversationId)
      })
      offset = result.offset
      finished = result.finished || result.conversationList.length <= 0
    }
  }

  private groupConversationOption(): V2NIMConversationOption {
    return {
      conversationGroupIds: [this.groupId]
    }
  }

  private refreshDisplayCandidates(): void {
    this.displayCandidates = filterConversationsByKeyword(this.candidateConversations, this.keyword)
  }

  private shouldContinueLoadingCandidatePage(beforeCount: number): boolean {
    return this.keyword.trim().length <= 0 && !this.isCandidateFinished &&
      this.candidateConversations.length === beforeCount
  }

  private appendUniqueConversations(source: V2NIMConversation[],
    incoming: V2NIMConversation[]): V2NIMConversation[] {
    const result = source.slice()
    const conversationIds: Set<string> = new Set()
    result.forEach((conversation: V2NIMConversation) => {
      conversationIds.add(conversation.conversationId)
    })
    incoming.forEach((conversation: V2NIMConversation) => {
      if (!conversationIds.has(conversation.conversationId)) {
        result.push(conversation)
        conversationIds.add(conversation.conversationId)
      }
    })
    return result
  }
}
