/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { NimRepository } from '../ability/NimRepository';
import { promptAction, router } from '@kit.ArkUI';
import { V2NIMDataSyncState, V2NIMDataSyncType, V2NIMError, V2NIMUser } from '@nimsdk/base';
import { NEFriendUserCache } from '@nimkit/chatkit';

export class LoginComponent {
  public static myUser?: V2NIMUser;

  constructor() {
    NimRepository.getNIM().loginService.on('onDataSync',
      (type: V2NIMDataSyncType, state: V2NIMDataSyncState, error?: V2NIMError) => {
        if (state === V2NIMDataSyncState.V2NIM_DATA_SYNC_STATE_COMPLETED) {
          NEFriendUserCache.getInstance()
          promptAction.showToast({
            message: "数据同步完成",
            alignment: Alignment.Center
          })
        }
      })
  }

  async login(accountId: string, token: string) {
    try {
      await NimRepository.getNIM().loginService.login(accountId, token);
      promptAction.showToast({
        message: "登录成功",
        alignment: Alignment.Center
      })

      router.replaceUrl({
        url: 'pages/TabIndex'
      });
    } catch (error) {
      console.log('----------- 登录失败 -----------', error)
      AlertDialog.show(
        {
          title: '登录失败',
          message: '登录失败',
          autoCancel: true,
          alignment: DialogAlignment.Bottom,
          offset: { dx: 0, dy: -20 },
          gridCount: 3,
          confirm: {
            value: 'OK',
            action: () => {
              console.info('Button-clicking callback')
            }
          },
          cancel: () => {
            console.info('Closed callbacks')
          }
        }
      )
    }
  }
}