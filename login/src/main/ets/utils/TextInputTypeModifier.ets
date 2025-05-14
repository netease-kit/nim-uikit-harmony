/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

export class TextInputTypeModifier implements AttributeModifier<TextInputAttribute> {
  public toInputTypeNormal: boolean = false

  applyNormalAttribute(instance: TextInputAttribute): void {
    if (this.toInputTypeNormal) {
      instance.type(InputType.Normal)
    } else {
      instance.type(InputType.Number)
    }
  }
}