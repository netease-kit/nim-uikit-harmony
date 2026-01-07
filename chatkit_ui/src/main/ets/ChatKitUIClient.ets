/*
 * Copyright (c) 2026 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { AbsCallKitClient } from "./AbsCallKitClient";

export class ChatKitUIClient {
  private static instance: AbsCallKitClient = new AbsCallKitClient();

  static setInstance(client: AbsCallKitClient) {
    if (ChatKitUIClient.instance.className() !== 'AbsCallKitClient') {
      // 已经设置过
      return;
    }
    ChatKitUIClient.instance = client;
  }

  static getInstance(): AbsCallKitClient {
    return ChatKitUIClient.instance;
  }
}