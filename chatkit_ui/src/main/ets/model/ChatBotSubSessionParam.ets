/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { V2NIMTopic } from '@nimsdk/base';

export class ChatBotSubSessionListParam {
  conversationId: string = ''
  botAccid: string = ''
  botName: string = ''

  constructor(conversationId: string, botAccid: string, botName: string) {
    this.conversationId = conversationId
    this.botAccid = botAccid
    this.botName = botName
  }
}

export class ChatBotSubSessionSettingParam {
  conversationId: string = ''
  fromBotSubSession: boolean = false

  constructor(conversationId: string, fromBotSubSession: boolean = false) {
    this.conversationId = conversationId
    this.fromBotSubSession = fromBotSubSession
  }
}

export class ChatBotSubSessionParam {
  conversationId: string = ''
  botAccid: string = ''
  botName: string = ''
  topic?: V2NIMTopic = undefined

  constructor(conversationId: string, botAccid: string, botName: string, topic?: V2NIMTopic) {
    this.conversationId = conversationId
    this.botAccid = botAccid
    this.botName = botName
    this.topic = topic
  }
}

export class ChatBotSubSessionResult {
  topic?: V2NIMTopic = undefined
  removed: boolean = false
  changed: boolean = false

  constructor(topic?: V2NIMTopic, removed: boolean = false, changed: boolean = false) {
    this.topic = topic
    this.removed = removed
    this.changed = changed
  }
}
