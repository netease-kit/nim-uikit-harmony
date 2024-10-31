/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { AvatarItem } from '../view/CommonAvatar';

export interface ViewItem {
  avatarItem?: AvatarItem;
  title?: ResourceStr;
  subTitle?: ResourceStr;
  titleIconSize?: number;
  titleIconRadius?: number;
  titleFontSize?: number;
  titleFontColor?: ResourceColor;
  backgroundColor?: ResourceColor;
  showDivideLine?: boolean;
  routerUrl?: string;
  routerParams?: Object;
  itemHeight?: number;
}