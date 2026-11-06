/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { AdaptiveLayoutMode } from '@nimkit/common'

export enum ShellNavigationMode {
  STACK = 'stack',
  SPLIT = 'split'
}

export enum ShellOrientationPolicy {
  PORTRAIT_ONLY = 'portraitOnly',
  FOLLOW_SYSTEM_ROTATION = 'followSystemRotation'
}

export class AdaptiveShellPresentation {
  navigationMode: ShellNavigationMode
  verticalTabs: boolean
  primaryNavigationWidthVp: number
  primaryNavigationItemHeightVp: number
  navBarWidthVp: number
  detailWidthVp: number

  constructor(navigationMode: ShellNavigationMode, verticalTabs: boolean, primaryNavigationWidthVp: number,
    primaryNavigationItemHeightVp: number, navBarWidthVp: number, detailWidthVp: number) {
    this.navigationMode = navigationMode
    this.verticalTabs = verticalTabs
    this.primaryNavigationWidthVp = primaryNavigationWidthVp
    this.primaryNavigationItemHeightVp = primaryNavigationItemHeightVp
    this.navBarWidthVp = navBarWidthVp
    this.detailWidthVp = detailWidthVp
  }
}

export function resolveShellPresentation(mode: AdaptiveLayoutMode, windowWidthVp: number,
  masterWidthVp: number, detailWidthVp: number): AdaptiveShellPresentation {
  if (mode === AdaptiveLayoutMode.COMPACT) {
    return new AdaptiveShellPresentation(ShellNavigationMode.STACK, false, 0, 0, windowWidthVp, 0)
  }
  if (mode === AdaptiveLayoutMode.EXPANDED) {
    const primaryWidth = 56
    return new AdaptiveShellPresentation(
      ShellNavigationMode.SPLIT,
      true,
      primaryWidth,
      108,
      primaryWidth + masterWidthVp,
      detailWidthVp
    )
  }
  return new AdaptiveShellPresentation(
    ShellNavigationMode.SPLIT,
    false,
    0,
    0,
    masterWidthVp,
    detailWidthVp
  )
}

export function resolveShellOrientationPolicy(mode: AdaptiveLayoutMode,
  isFoldedScreen: boolean = false, isFoldableDevice: boolean = false): ShellOrientationPolicy {
  if (isFoldedScreen || (!isFoldableDevice && mode === AdaptiveLayoutMode.COMPACT)) {
    return ShellOrientationPolicy.PORTRAIT_ONLY
  }
  return ShellOrientationPolicy.FOLLOW_SYSTEM_ROTATION
}
