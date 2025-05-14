/**
 * BreakpointConstants
 * NIM-WS-TS
 *
 * @author hongru
 * @since 2025−04-17
 *
 * Copyright © 2025 Netease. All rights reserved.
 */
export class BreakpointConstants {
  /**
   * Breakpoints that represent smaller device types.
   */
  static readonly BREAKPOINT_XS: string = 'xs';
  /**
   * Breakpoints that represent small device types.
   */
  static readonly BREAKPOINT_SM: string = 'sm';
  /**
   * Breakpoints that represent middle device types.
   */
  static readonly BREAKPOINT_MD: string = 'md';
  /**
   * Breakpoints that represent large device types.
   */
  static readonly BREAKPOINT_LG: string = 'lg';
  /**
   * Breakpoints that represent large device types.
   */
  static readonly BREAKPOINT_SCOPE: number[] = [0, 320, 600, 840];
  /**
   * Grid row column list.
   */
  static readonly GRID_ROW_COLUMNS: number[] = [12, 15, 4];
  /**
   * Grid column span list.
   */
  static readonly GRID_COLUMN_SPANS: number[] = [12, 6, 7, 5, 3, 4, 2];
}