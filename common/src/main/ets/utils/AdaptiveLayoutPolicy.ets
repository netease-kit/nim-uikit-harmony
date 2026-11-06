/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import {
  AdaptiveHeightBreakpoint,
  AdaptiveLayoutDecision,
  AdaptiveLayoutMode,
  AdaptiveLayoutProfile,
  AdaptiveRegionLayout,
  AdaptiveRegionRole,
  AdaptiveRegionSpec,
  AdaptiveWidthBreakpoint
} from '../model/AdaptiveLayoutModel'

const COMPACT_PROFILE = new AdaptiveLayoutProfile('compact', AdaptiveLayoutMode.COMPACT, 0, Number.MAX_VALUE, [
  new AdaptiveRegionSpec('master', AdaptiveRegionRole.MASTER, 0, Number.MAX_VALUE, 1, 2),
  new AdaptiveRegionSpec('detail', AdaptiveRegionRole.DETAIL, 0, Number.MAX_VALUE, 1, 3)
])

const MEDIUM_PROFILE = new AdaptiveLayoutProfile('masterDetail', AdaptiveLayoutMode.MEDIUM, 600, 1.2, [
  new AdaptiveRegionSpec('master', AdaptiveRegionRole.MASTER, 280, 480, 1, 2),
  new AdaptiveRegionSpec('detail', AdaptiveRegionRole.DETAIL, 280, Number.MAX_VALUE, 1, 3)
])

const EXPANDED_PROFILE = new AdaptiveLayoutProfile('navigationMasterDetail', AdaptiveLayoutMode.EXPANDED, 840, 1.2, [
  new AdaptiveRegionSpec('primaryNavigation', AdaptiveRegionRole.PRIMARY_NAVIGATION, 56, 56, 0, 3),
  new AdaptiveRegionSpec('master', AdaptiveRegionRole.MASTER, 240, 432, 1, 2),
  new AdaptiveRegionSpec('detail', AdaptiveRegionRole.DETAIL, 360, Number.MAX_VALUE, 2, 4)
])

export function resolveWidthBreakpoint(widthVp: number): AdaptiveWidthBreakpoint {
  const safeWidth = Math.max(0, widthVp)
  if (safeWidth < 320) {
    return AdaptiveWidthBreakpoint.XS
  }
  if (safeWidth < 600) {
    return AdaptiveWidthBreakpoint.SM
  }
  if (safeWidth < 840) {
    return AdaptiveWidthBreakpoint.MD
  }
  if (safeWidth < 1440) {
    return AdaptiveWidthBreakpoint.LG
  }
  return AdaptiveWidthBreakpoint.XL
}

export function resolveHeightBreakpoint(widthVp: number, heightVp: number): AdaptiveHeightBreakpoint {
  if (widthVp <= 0 || heightVp < 0) {
    return AdaptiveHeightBreakpoint.LG
  }
  const ratio = heightVp / widthVp
  if (ratio < 0.8) {
    return AdaptiveHeightBreakpoint.SM
  }
  if (ratio < 1.2) {
    return AdaptiveHeightBreakpoint.MD
  }
  return AdaptiveHeightBreakpoint.LG
}

export function resolveAdaptiveLayout(widthVp: number, heightVp: number,
  activeRole: AdaptiveRegionRole = AdaptiveRegionRole.MASTER): AdaptiveLayoutDecision {
  const safeWidth = Math.max(0, widthVp)
  const safeHeight = Math.max(0, heightVp)
  if (safeWidth < 600 || safeWidth <= 0 || safeHeight / safeWidth >= 1.2) {
    return resolveAdaptiveProfile(COMPACT_PROFILE, safeWidth, activeRole)
  }
  if (safeWidth < 840) {
    return resolveAdaptiveProfile(MEDIUM_PROFILE, safeWidth, activeRole)
  }
  return resolveAdaptiveProfile(EXPANDED_PROFILE, safeWidth, activeRole)
}

export function resolveAdaptiveProfile(profile: AdaptiveLayoutProfile, windowWidthVp: number,
  activeRole: AdaptiveRegionRole): AdaptiveLayoutDecision {
  const safeWidth = Math.max(0, windowWidthVp)
  const visibleSpecs: AdaptiveRegionSpec[] = []
  const hiddenIds: string[] = []
  for (const region of profile.regions) {
    visibleSpecs.push(region)
  }

  if (profile.mode === AdaptiveLayoutMode.COMPACT) {
    const active = findActiveRegion(visibleSpecs, activeRole)
    for (const region of visibleSpecs) {
      if (region.id !== active.id) {
        hiddenIds.push(region.id)
      }
    }
    return new AdaptiveLayoutDecision(profile.mode, profile.id,
      [new AdaptiveRegionLayout(active.id, active.role, safeWidth)], hiddenIds)
  }

  let minimumWidth = sumMinimumWidth(visibleSpecs)
  while (minimumWidth > safeWidth && visibleSpecs.length > 1) {
    const removableIndex = findLowestPriorityRemovableIndex(visibleSpecs, activeRole)
    if (removableIndex < 0) {
      break
    }
    hiddenIds.push(visibleSpecs[removableIndex].id)
    visibleSpecs.splice(removableIndex, 1)
    minimumWidth = sumMinimumWidth(visibleSpecs)
  }

  if (minimumWidth > safeWidth) {
    const active = findActiveRegion(visibleSpecs, activeRole)
    for (const region of visibleSpecs) {
      if (region.id !== active.id) {
        hiddenIds.push(region.id)
      }
    }
    return new AdaptiveLayoutDecision(profile.mode, profile.id,
      [new AdaptiveRegionLayout(active.id, active.role, safeWidth)], hiddenIds)
  }

  const widths = distributeWidths(visibleSpecs, safeWidth)
  const layouts: AdaptiveRegionLayout[] = []
  for (let index = 0; index < visibleSpecs.length; index++) {
    const region = visibleSpecs[index]
    layouts.push(new AdaptiveRegionLayout(region.id, region.role, widths[index]))
  }
  return new AdaptiveLayoutDecision(profile.mode, profile.id, layouts, hiddenIds)
}

function distributeWidths(regions: AdaptiveRegionSpec[], totalWidth: number): number[] {
  const widths: number[] = []
  const flexibleIndexes: number[] = []
  let remainingWidth = totalWidth
  for (let index = 0; index < regions.length; index++) {
    const region = regions[index]
    widths.push(0)
    if (region.weight > 0) {
      flexibleIndexes.push(index)
    } else {
      widths[index] = region.minWidthVp
      remainingWidth -= region.minWidthVp
    }
  }

  while (flexibleIndexes.length > 0) {
    let totalWeight = 0
    for (const index of flexibleIndexes) {
      totalWeight += regions[index].weight
    }
    if (totalWeight <= 0) {
      break
    }

    let clamped = false
    for (let flexibleIndex = 0; flexibleIndex < flexibleIndexes.length; flexibleIndex++) {
      const index = flexibleIndexes[flexibleIndex]
      const region = regions[index]
      const weightedWidth = remainingWidth * region.weight / totalWeight
      if (weightedWidth < region.minWidthVp) {
        widths[index] = region.minWidthVp
        remainingWidth -= region.minWidthVp
        flexibleIndexes.splice(flexibleIndex, 1)
        clamped = true
        break
      }
      if (weightedWidth > region.maxWidthVp) {
        widths[index] = region.maxWidthVp
        remainingWidth -= region.maxWidthVp
        flexibleIndexes.splice(flexibleIndex, 1)
        clamped = true
        break
      }
    }
    if (clamped) {
      continue
    }

    for (const index of flexibleIndexes) {
      widths[index] = remainingWidth * regions[index].weight / totalWeight
    }
    break
  }
  return widths
}

function findActiveRegion(regions: AdaptiveRegionSpec[], activeRole: AdaptiveRegionRole): AdaptiveRegionSpec {
  for (const region of regions) {
    if (region.role === activeRole) {
      return region
    }
  }
  for (const region of regions) {
    if (region.role === AdaptiveRegionRole.MASTER) {
      return region
    }
  }
  return regions[0]
}

function sumMinimumWidth(regions: AdaptiveRegionSpec[]): number {
  let total = 0
  for (const region of regions) {
    total += Math.max(0, region.minWidthVp)
  }
  return total
}

function findLowestPriorityRemovableIndex(regions: AdaptiveRegionSpec[],
  activeRole: AdaptiveRegionRole): number {
  let result = -1
  let lowestPriority = Number.MAX_VALUE
  for (let index = 0; index < regions.length; index++) {
    const region = regions[index]
    if (region.role !== activeRole && region.priority < lowestPriority) {
      lowestPriority = region.priority
      result = index
    }
  }
  return result
}
