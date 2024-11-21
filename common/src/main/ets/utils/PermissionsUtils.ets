/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

// found in the LICENSE file.

import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class PermissionsRequestResult {
  // 错误信息
  public error?: BusinessError;
  // 是否授权
  public grantStatus?: boolean;
}

export class PermissionsUtils {
  static async reqPermissionsFromUser(permissions: Array<Permissions>,
    context: common.UIAbilityContext): Promise<PermissionsRequestResult> {

    const result: PermissionsRequestResult = await new Promise((resolve: Function) => {
      console.log("net ease reqPermissionsFromUser")
      let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      // requestPermissionsFromUser会判断权限的授权状态来决定是否唤起弹窗
      atManager.requestPermissionsFromUser(context, permissions).then((data) => {
        let grantStatus: Array<number> = data.authResults;
        let length: number = grantStatus.length;
        let permissionsRequestResult = new PermissionsRequestResult();
        if (grantStatus.length > 0) {
          const grant = grantStatus[0];
          if (grant === 0) {
            // 用户授权，可以继续访问目标操作
            permissionsRequestResult.grantStatus = true;
          } else {
            // 用户拒绝授权，提示用户必须授权才能访问当前页面的功能，并引导用户到系统设置中打开相应的权限
            permissionsRequestResult.grantStatus = false;
          }
        }
        resolve(permissionsRequestResult);

      }).catch((err: BusinessError) => {
        console.error(`netease Failed to request permissions from user. Code is ${err.code}, message is ${err.message}`);
        let permissionsRequestResult = new PermissionsRequestResult();
        permissionsRequestResult.error = err;
        resolve(permissionsRequestResult);
      })
    });
    return result
  }
}