/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export enum EditType {
  common,
  nick,
  accountId,
  alias,
  avatar,
  gender,
  birthday,
  mobile,
  email,
  sign
}

@ObservedV2
export class PersonInfoItem {
  @Trace title?: ResourceStr;
  @Trace subTitle?: ResourceStr;
  itemHeight?: number;

  constructor(title?: ResourceStr,
    subTitle?: ResourceStr,
    itemHeight?: number) {
    this.title = title
    this.subTitle = subTitle
    this.itemHeight = itemHeight ?? 46
  }
}

@ObservedV2
export class PersonInfoArrowItem extends PersonInfoItem {
  routerUrl?: string;
  rightIcon?: ResourceStr;

  constructor(title?: ResourceStr,
    subTitle?: ResourceStr,
    itemHeight?: number,
    routerUrl?: string,
    rightIcon?: ResourceStr) {
    super(title, subTitle, itemHeight);
    this.routerUrl = routerUrl ?? "EditInfoPage"
    this.rightIcon = rightIcon ?? $r('app.media.arrow_right')
  }
}

@ObservedV2
export class PersonInfoSwitchItem extends PersonInfoItem {
  isOpen?: boolean = false;
  switchChange?: (isOpen: boolean) => void;

  constructor(title?: ResourceStr,
    isOpen?: boolean,
    switchChange?: (isOpen: boolean) => void,
    itemHeight?: number,
    subTitle?: ResourceStr) {
    super(title, subTitle, itemHeight);
    this.isOpen = isOpen
    this.switchChange = switchChange
  }
}

@ObservedV2
export class MineInfoItem extends PersonInfoArrowItem {
  @Trace subIcon?: ResourceStr;
  editType?: EditType

  constructor(title?: ResourceStr,
    subIcon?: ResourceStr,
    subTitle?: ResourceStr,
    editType?: EditType,
    routerUrl?: string,
    rightIcon?: ResourceStr,
    itemHeight?: number) {
    super(title, subTitle, itemHeight, routerUrl, rightIcon);
    this.subIcon = subIcon
    this.editType = editType
    this.routerUrl = routerUrl
  }
}