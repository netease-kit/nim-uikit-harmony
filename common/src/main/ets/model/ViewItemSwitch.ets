/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ViewItem } from './ViewItem';

export interface ViewItemSwitch extends ViewItem {
  isOpen?: boolean;
  switchChange?: (isOpen: boolean) => void;
  enableChange?: boolean;
}