/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import ConversationGroupModelTest from './ConversationGroupModel.test'
import ConversationOpenIntentTest from './ConversationOpenIntent.test'

export default function testsuite() {
  ConversationGroupModelTest()
  ConversationOpenIntentTest()
}
