/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

export enum AdaptiveWidthBreakpoint {
  XS = 'xs',
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
  XL = 'xl'
}

export enum AdaptiveHeightBreakpoint {
  SM = 'sm',
  MD = 'md',
  LG = 'lg'
}

export enum AdaptiveLayoutMode {
  COMPACT = 'compact',
  MEDIUM = 'medium',
  EXPANDED = 'expanded'
}

export enum AdaptiveRegionRole {
  PRIMARY_NAVIGATION = 'primaryNavigation',
  MASTER = 'master',
  DETAIL = 'detail',
  AUXILIARY = 'auxiliary'
}

export class AdaptiveRegionSpec {
  id: string
  role: AdaptiveRegionRole
  minWidthVp: number
  maxWidthVp: number
  weight: number
  priority: number

  constructor(id: string, role: AdaptiveRegionRole, minWidthVp: number, maxWidthVp: number,
    weight: number, priority: number) {
    this.id = id
    this.role = role
    this.minWidthVp = minWidthVp
    this.maxWidthVp = maxWidthVp
    this.weight = weight
    this.priority = priority
  }
}

export class AdaptiveLayoutProfile {
  id: string
  mode: AdaptiveLayoutMode
  minWindowWidthVp: number
  maxWindowRatio: number
  regions: AdaptiveRegionSpec[]

  constructor(id: string, mode: AdaptiveLayoutMode, minWindowWidthVp: number, maxWindowRatio: number,
    regions: AdaptiveRegionSpec[]) {
    this.id = id
    this.mode = mode
    this.minWindowWidthVp = minWindowWidthVp
    this.maxWindowRatio = maxWindowRatio
    this.regions = regions
  }
}

export class AdaptiveRegionLayout {
  id: string
  role: AdaptiveRegionRole
  widthVp: number

  constructor(id: string, role: AdaptiveRegionRole, widthVp: number) {
    this.id = id
    this.role = role
    this.widthVp = widthVp
  }
}

export class AdaptiveLayoutDecision {
  mode: AdaptiveLayoutMode
  profileId: string
  visibleRegions: AdaptiveRegionLayout[]
  hiddenRegionIds: string[]

  constructor(mode: AdaptiveLayoutMode, profileId: string, visibleRegions: AdaptiveRegionLayout[],
    hiddenRegionIds: string[]) {
    this.mode = mode
    this.profileId = profileId
    this.visibleRegions = visibleRegions
    this.hiddenRegionIds = hiddenRegionIds
  }

  widthFor(role: AdaptiveRegionRole): number {
    for (const region of this.visibleRegions) {
      if (region.role === role) {
        return region.widthVp
      }
    }
    return 0
  }
}

export class AdaptiveAvoidAreaSnapshot {
  topVp: number
  bottomVp: number
  leftVp: number
  rightVp: number
  keyboardVp: number

  constructor(topVp: number = 0, bottomVp: number = 0, leftVp: number = 0, rightVp: number = 0,
    keyboardVp: number = 0) {
    this.topVp = topVp
    this.bottomVp = bottomVp
    this.leftVp = leftVp
    this.rightVp = rightVp
    this.keyboardVp = keyboardVp
  }
}

export class AdaptiveWindowSnapshot {
  widthVp: number
  heightVp: number
  widthBreakpoint: AdaptiveWidthBreakpoint
  heightBreakpoint: AdaptiveHeightBreakpoint
  avoidAreas: AdaptiveAvoidAreaSnapshot

  constructor(widthVp: number, heightVp: number, widthBreakpoint: AdaptiveWidthBreakpoint,
    heightBreakpoint: AdaptiveHeightBreakpoint, avoidAreas: AdaptiveAvoidAreaSnapshot = new AdaptiveAvoidAreaSnapshot()) {
    this.widthVp = widthVp
    this.heightVp = heightVp
    this.widthBreakpoint = widthBreakpoint
    this.heightBreakpoint = heightBreakpoint
    this.avoidAreas = avoidAreas
  }
}
