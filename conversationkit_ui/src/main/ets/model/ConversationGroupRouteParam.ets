/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ConversationGroupInfo } from './ConversationGroupModel'
import { ConversationGroupViewModel } from '../viewmodel/ConversationGroupViewModel'

export enum ConversationGroupNameEditMode {
  CREATE = 'create',
  RENAME = 'rename'
}

export class ConversationGroupRouteParam {
  groupViewModel?: ConversationGroupViewModel
  group?: ConversationGroupInfo
  editMode?: ConversationGroupNameEditMode

  constructor(groupViewModel?: ConversationGroupViewModel, group?: ConversationGroupInfo,
    editMode?: ConversationGroupNameEditMode) {
    this.groupViewModel = groupViewModel
    this.group = group
    this.editMode = editMode
  }
}
