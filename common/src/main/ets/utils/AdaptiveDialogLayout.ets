/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { AdaptiveRegionRole } from '../model/AdaptiveLayoutModel'
import { resolveAdaptiveLayout } from './AdaptiveLayoutPolicy'
import { adaptiveWindowManager } from './AdaptiveWindowManager'

/** 返回当前详情区域可用宽度，窄屏时回退为整窗宽度。 */
export function resolveAdaptiveDetailDialogWidth(): Dimension {
  const snapshot = adaptiveWindowManager.state.getSnapshot()
  if (snapshot.widthVp <= 0 || snapshot.heightVp <= 0) {
    return '100%'
  }
  const detailWidth = resolveAdaptiveLayout(snapshot.widthVp, snapshot.heightVp,
    AdaptiveRegionRole.DETAIL).widthFor(AdaptiveRegionRole.DETAIL)
  return detailWidth > 0 ? detailWidth : snapshot.widthVp
}
