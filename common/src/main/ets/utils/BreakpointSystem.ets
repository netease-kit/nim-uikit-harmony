/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { mediaquery } from '@kit.ArkUI';
import { CommonConstants } from '../constants/CommonConstants';

declare interface BreakPointTypeOption<T> extends Record<string, T | undefined> {
  sm?: T;
  md?: T;
  lg?: T;
  xl?: T;
  xxl?: T;
}

export class BreakPointType<T> {
  options: BreakPointTypeOption<T>;

  constructor(option: BreakPointTypeOption<T>) {
    this.options = option;
  }

  getValue(currentBreakPoint: string): T {
    return this.options[currentBreakPoint] as T;
  }
}

class Breakpoint {
  name: string = '';
  size: number = 0;
  mediaQueryListener?: mediaquery.MediaQueryListener;
}

export class BreakpointSystem {
  private currentBreakpoint: string = CommonConstants.BREAKPOINTS_INITIALIZE_NAME;
  private breakpointId: string = CommonConstants.BREAKPOINT_ID_INITIALIZE_NAME;
  private breakpoints: Breakpoint[] = [
    { name: CommonConstants.BREAKPOINTS_SM_NAME, size: CommonConstants.BREAKPOINTS_SM_SIZE },
    { name: CommonConstants.BREAKPOINTS_MD_NAME, size: CommonConstants.BREAKPOINTS_MD_SIZE },
    { name: CommonConstants.BREAKPOINTS_LG_NAME, size: CommonConstants.BREAKPOINTS_LG_SIZE },
    { name: CommonConstants.BREAKPOINTS_XL_NAME, size: CommonConstants.BREAKPOINTS_XL_SIZE }
  ];

  constructor(breakpointId: string) {
    this.breakpointId = breakpointId;
  }

  public register(): void {
    this.breakpoints.forEach((breakpoint: Breakpoint, index: number) => {
      let condition: string;
      if (index === this.breakpoints.length - 1) {
        condition = `(${breakpoint.size}vp<=width)`;
      } else {
        condition = `(${breakpoint.size}vp<=width<${this.breakpoints[index + 1].size}vp)`;
      }

      breakpoint.mediaQueryListener = mediaquery.matchMediaSync(condition);
      breakpoint.mediaQueryListener.on('change', (mediaQueryResult: mediaquery.MediaQueryResult) => {
        if (mediaQueryResult.matches) {
          this.updateCurrentBreakpoint(breakpoint.name);
        }
      })
    })
  }

  public unregister(): void {
    this.breakpoints.forEach((breakpoint: Breakpoint) => {
      breakpoint.mediaQueryListener?.off('change');
    })
  }

  private updateCurrentBreakpoint(breakpoint: string): void {
    if (this.currentBreakpoint !== breakpoint) {
      this.currentBreakpoint = breakpoint;
      AppStorage.set<string>(this.breakpointId, this.currentBreakpoint);
    }
  }
}