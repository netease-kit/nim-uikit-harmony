/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export interface RevokeMessageExtension {
  revoke_message_local: boolean,
  revoke_message_local_time: number,
  revoke_message_local_edit: boolean,
  revoke_message_local_content: string,
  revoke_message_client_id: string,
}
