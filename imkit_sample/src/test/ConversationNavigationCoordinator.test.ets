/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { describe, expect, it } from '@ohos/hypium'
import {
  ConversationOpenIntent,
  ConversationOpenSource,
  ConversationRouteKey,
  ConversationRouteKind
} from '@nimkit/conversationkit_ui'
import {
  ConversationNavigationAction,
  ConversationNavigationState,
  ConversationNavigationStack,
  ensureAdaptiveDetailPlaceholder,
  executeConversationNavigation,
  openPrimaryDetail,
  reconcileConversationNavigationState,
  reduceConversationNavigation,
  resolveSelectedConversationId,
  resolveAdaptiveDetailPlaceholderTarget
} from '../main/ets/manager/ConversationNavigationCoordinator'
import { AdaptiveLayoutMode, AdaptiveRegionRole, resolveAdaptiveLayout } from '@nimkit/common'
import {
  resolveShellOrientationPolicy,
  resolveShellPresentation,
  ShellNavigationMode,
  ShellOrientationPolicy
} from '../main/ets/manager/AdaptiveShellPolicy'

class FakeNavigationStack extends ConversationNavigationStack {
  names: string[] = []
  animations: boolean[] = []

  getAllPathName(): string[] {
    return this.names.slice()
  }

  pushPath(info: NavPathInfo, animated: boolean = true): void {
    this.names.push(info.name)
    this.animations.push(animated)
  }

  popToName(name: string, animated: boolean = true): void {
    const index = this.names.lastIndexOf(name)
    if (index >= 0) {
      this.names.splice(index + 1)
      this.animations.splice(index + 1)
    }
  }

  removeByIndexes(indexes: number[]): void {
    const descending = indexes.slice().sort((left: number, right: number) => right - left)
    for (const index of descending) {
      this.names.splice(index, 1)
      this.animations.splice(index, 1)
    }
  }

  moveIndexToTop(index: number, animated: boolean = true): void {
    if (index < 0 || index >= this.names.length) {
      return
    }
    const name = this.names[index]
    const originalAnimation = this.animations[index]
    this.names.splice(index, 1)
    this.animations.splice(index, 1)
    this.names.push(name)
    this.animations.push(originalAnimation ?? animated)
  }

  clear(animated: boolean = true): void {
    this.names = []
    this.animations = []
  }
}

function buildIntent(kind: ConversationRouteKind, conversationId: string): ConversationOpenIntent {
  return new ConversationOpenIntent(
    new ConversationRouteKey(kind, conversationId),
    ConversationOpenSource.CONVERSATION_LIST
  )
}

export default function ConversationNavigationCoordinatorTest() {
  describe('ConversationNavigationCoordinator', () => {
    it('pushes the first chat root and ignores repeated opens', 0, () => {
      const initialState = new ConversationNavigationState()
      const intent = buildIntent(ConversationRouteKind.P2P, 'conversation-a')
      const first = reduceConversationNavigation(initialState, intent)
      expect(first.action).assertEqual(ConversationNavigationAction.PUSH_CHAT_ROOT)

      let state = first.state
      for (let index = 0; index < 10; index++) {
        const repeated = reduceConversationNavigation(state, intent)
        expect(repeated.action).assertEqual(ConversationNavigationAction.NO_OP)
        state = repeated.state
      }
      expect(state.activeKey).assertEqual('p2p|conversation-a|')
    })

    it('replaces the chat root when another conversation is opened', 0, () => {
      const first = reduceConversationNavigation(
        new ConversationNavigationState(),
        buildIntent(ConversationRouteKind.P2P, 'conversation-a')
      )
      const second = reduceConversationNavigation(first.state, buildIntent(ConversationRouteKind.TEAM, 'conversation-b'))
      expect(second.action).assertEqual(ConversationNavigationAction.REPLACE_CHAT_ROOT)
      expect(second.state.activeKey).assertEqual('team|conversation-b|')
    })

    it('returns to the active chat root when an extension is visible', 0, () => {
      const state = new ConversationNavigationState('p2p|conversation-a|', 'ChatP2PPage', true)
      const decision = reduceConversationNavigation(state, buildIntent(ConversationRouteKind.P2P, 'conversation-a'))
      expect(decision.action).assertEqual(ConversationNavigationAction.POP_TO_CHAT_ROOT)
      expect(decision.state.hasExtensionRoute).assertFalse()
    })

    it('rejects an invalid conversation without changing state', 0, () => {
      const state = new ConversationNavigationState('p2p|conversation-a|', 'ChatP2PPage', false)
      const decision = reduceConversationNavigation(state, buildIntent(ConversationRouteKind.P2P, ''))
      expect(decision.action).assertEqual(ConversationNavigationAction.REJECT)
      expect(decision.state.activeKey).assertEqual(state.activeKey)
    })

    it('executes repeated opens without stacking duplicate chat roots', 0, () => {
      const stack = new FakeNavigationStack()
      let state = new ConversationNavigationState()
      const intent = buildIntent(ConversationRouteKind.P2P, 'conversation-a')

      state = executeConversationNavigation(stack, state, intent)
      for (let index = 0; index < 10; index++) {
        state = executeConversationNavigation(stack, state, intent)
      }

      expect(stack.names.length).assertEqual(1)
      expect(stack.names[0]).assertEqual('ChatP2PPage')
      expect(state.activeKey).assertEqual('p2p|conversation-a|')
    })

    it('removes the previous chat subtree before opening another conversation', 0, () => {
      const stack = new FakeNavigationStack()
      stack.names = ['SearchPage', 'ChatP2PPage', 'UserSettingPage']
      const state = new ConversationNavigationState('p2p|conversation-a|', 'ChatP2PPage', true)

      const next = executeConversationNavigation(
        stack,
        state,
        buildIntent(ConversationRouteKind.TEAM, 'conversation-b')
      )

      expect(stack.names.join(',')).assertEqual('SearchPage,ChatTeamPage')
      expect(next.activeKey).assertEqual('team|conversation-b|')
    })

    it('switches conversations without a lateral transition in split mode', 0, () => {
      const stack = new FakeNavigationStack()
      let state = executeConversationNavigation(
        stack,
        new ConversationNavigationState(),
        buildIntent(ConversationRouteKind.P2P, 'conversation-a'),
        false
      )
      state = executeConversationNavigation(
        stack,
        state,
        buildIntent(ConversationRouteKind.TEAM, 'conversation-b'),
        false
      )
      expect(stack.names.join(',')).assertEqual('ChatTeamPage')
      expect(stack.animations.length).assertEqual(1)
      expect(stack.animations[0]).assertFalse()
    })

    it('uses one primary detail slot in split mode and keeps compact navigation animation', 0, () => {
      const splitStack = new FakeNavigationStack()
      ensureAdaptiveDetailPlaceholder(splitStack, true)
      openPrimaryDetail(splitStack, { name: 'SearchPage' }, true)
      openPrimaryDetail(splitStack, { name: 'SettingPage' }, true)
      expect(splitStack.names.join(',')).assertEqual('AdaptiveEmptyDetailPage,SettingPage')
      expect(splitStack.animations[0]).assertFalse()

      const compactStack = new FakeNavigationStack()
      openPrimaryDetail(compactStack, { name: 'SearchPage' }, false)
      openPrimaryDetail(compactStack, { name: 'SettingPage' }, false)
      expect(compactStack.names.join(',')).assertEqual('SearchPage,SettingPage')
      expect(compactStack.animations[0]).assertTrue()
      expect(compactStack.animations[1]).assertTrue()
    })

    it('keeps a split detail placeholder and removes it when returning to compact mode', 0, () => {
      const stack = new FakeNavigationStack()
      ensureAdaptiveDetailPlaceholder(stack, true)
      ensureAdaptiveDetailPlaceholder(stack, true)
      expect(stack.names.join(',')).assertEqual('AdaptiveEmptyDetailPage')
      expect(stack.animations[0]).assertFalse()

      ensureAdaptiveDetailPlaceholder(stack, false)
      expect(stack.names.length).assertEqual(0)
    })

    it('places the split placeholder below an existing chat after expanding', 0, () => {
      const stack = new FakeNavigationStack()
      stack.names = ['ChatP2PPage']

      ensureAdaptiveDetailPlaceholder(stack, true)

      expect(stack.names.join(',')).assertEqual('AdaptiveEmptyDetailPage,ChatP2PPage')
    })

    it('exposes the selected conversation only while the master and detail are both visible', 0, () => {
      const intent = buildIntent(ConversationRouteKind.P2P, 'conversation-a')
      const state = reduceConversationNavigation(new ConversationNavigationState(), intent).state
      expect(resolveSelectedConversationId(state, true, ['AdaptiveEmptyDetailPage', 'ChatP2PPage']))
        .assertEqual('conversation-a')
      expect(resolveSelectedConversationId(state, true, ['AdaptiveEmptyDetailPage'])).assertEqual('')
      expect(resolveSelectedConversationId(state, false, ['ChatP2PPage'])).assertEqual('')
    })

    it('clears the selected conversation after the navigation stack pops its chat root', 0, () => {
      const stack = new FakeNavigationStack()
      stack.names = ['AdaptiveEmptyDetailPage']
      const state = new ConversationNavigationState(
        'p2p|conversation-a|',
        'ChatP2PPage',
        false,
        'conversation-a'
      )

      const next = reconcileConversationNavigationState(stack, state)

      expect(next.activeKey).assertEqual('')
      expect(next.selectedConversationId).assertEqual('')
    })

    it('maps adaptive layout modes to stable shell presentation', 0, () => {
      const compact = resolveShellPresentation(AdaptiveLayoutMode.COMPACT, 400, 0, 0)
      const medium = resolveShellPresentation(AdaptiveLayoutMode.MEDIUM, 600, 300, 300)
      const expandedDecision = resolveAdaptiveLayout(840, 600)
      const expanded = resolveShellPresentation(
        expandedDecision.mode,
        840,
        expandedDecision.widthFor(AdaptiveRegionRole.MASTER),
        expandedDecision.widthFor(AdaptiveRegionRole.DETAIL)
      )
      expect(compact.navigationMode).assertEqual(ShellNavigationMode.STACK)
      expect(compact.verticalTabs).assertFalse()
      expect(medium.navigationMode).assertEqual(ShellNavigationMode.SPLIT)
      expect(medium.navBarWidthVp).assertEqual(300)
      expect(expanded.verticalTabs).assertTrue()
      expect(expanded.primaryNavigationWidthVp).assertEqual(56)
      expect(expanded.primaryNavigationItemHeightVp).assertEqual(72)
      expect(Math.abs(expanded.detailWidthVp /
        (expanded.navBarWidthVp - expanded.primaryNavigationWidthVp) - 2) < 0.01).assertTrue()
    })

    it('locks compact mode to portrait and enables system rotation for multi-pane modes', 0, () => {
      expect(resolveShellOrientationPolicy(AdaptiveLayoutMode.COMPACT))
        .assertEqual(ShellOrientationPolicy.PORTRAIT_ONLY)
      expect(resolveShellOrientationPolicy(AdaptiveLayoutMode.MEDIUM))
        .assertEqual(ShellOrientationPolicy.FOLLOW_SYSTEM_ROTATION)
      expect(resolveShellOrientationPolicy(AdaptiveLayoutMode.EXPANDED))
        .assertEqual(ShellOrientationPolicy.FOLLOW_SYSTEM_ROTATION)
      expect(resolveShellOrientationPolicy(AdaptiveLayoutMode.COMPACT, false, true))
        .assertEqual(ShellOrientationPolicy.FOLLOW_SYSTEM_ROTATION)
      expect(resolveShellOrientationPolicy(AdaptiveLayoutMode.COMPACT, true, true))
        .assertEqual(ShellOrientationPolicy.PORTRAIT_ONLY)
    })

    it('uses a tab-specific empty detail target', 0, () => {
      expect(resolveAdaptiveDetailPlaceholderTarget(0)).assertEqual('conversation')
      expect(resolveAdaptiveDetailPlaceholderTarget(1)).assertEqual('contact')
      expect(resolveAdaptiveDetailPlaceholderTarget(2)).assertEqual('mine')
      expect(resolveAdaptiveDetailPlaceholderTarget(99)).assertEqual('conversation')
    })
  })
}
