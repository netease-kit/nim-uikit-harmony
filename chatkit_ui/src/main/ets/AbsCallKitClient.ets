/*
 * Copyright (c) 2026 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { Logger } from '@nimkit/common';
import { common } from "@kit.AbilityKit";
import { NIMInterface } from "@nimsdk/base";

export class AbsCallKitClient {
  // call kit init
  init(context: common.Context, nim: NIMInterface, appKey: string, accountId: string, token: string): void {
    Logger.info('ChatKitUI', "init AbsCallKitClient");
  }
  // call kit call
  call(target: string, callType: number): void {
     Logger.info('ChatKitUI', "call AbsCallKitClient");
  }
  className():  string {
    return "AbsCallKitClient";
  }
}