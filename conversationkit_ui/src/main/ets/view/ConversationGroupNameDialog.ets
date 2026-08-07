/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ErrorUtils } from '@nimkit/chatkit'
import { NECommonUtils } from '@nimkit/common'
import {
  CONVERSATION_GROUP_NAME_MAX_LENGTH,
  normalizeConversationGroupName
} from '../model/ConversationGroupModel'

const PAGE_BACKGROUND_COLOR: string = '#EFF1F4'
const DIALOG_CONTAINER_HEIGHT: Dimension = '100%'
const DIALOG_HEIGHT: Dimension = '90%'
const DIALOG_MASK_OPACITY: number = 0.4
const DIALOG_RADIUS: number = 16
const DIALOG_NAV_HEIGHT: number = 56
const DIALOG_ANIMATION_DURATION: number = 240
const DIALOG_INITIAL_OFFSET_Y: number = 1000

@CustomDialog
export struct ConversationGroupNameDialog {
  controller?: CustomDialogController
  title: ResourceStr = $r('app.string.conversation_group_create_title')
  initialName: string = ''
  onSubmitName?: (name: string) => Promise<void>
  onSubmitSuccess?: (name: string) => void
  onSubmitError?: (error: Error) => void
  onDialogClose?: () => void
  @State groupName: string = ''
  @State isSaving: boolean = false
  @State isClosing: boolean = false
  @State panelOffsetY: number = DIALOG_INITIAL_OFFSET_Y
  @State panelOpacity: number = 0
  @State maskOpacity: number = 0

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.maskOpacity)
        .onClick(() => {
          this.closeDialog()
        })

      Column() {
        Row() {
          Text($r('app.string.conversation_group_cancel'))
            .fontSize(16)
            .fontColor('#666666')
            .height(DIALOG_NAV_HEIGHT)
            .width(70)
            .textAlign(TextAlign.Start)
            .align(Alignment.Center)
            .onClick(() => {
              this.closeDialog()
            })

          Text(this.title)
            .fontSize(17)
            .fontColor('#1F2329')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Text($r('app.string.conversation_group_confirm'))
            .fontSize(16)
            .fontColor(this.canSubmit() ? '#337EFF' : '#B3B7BC')
            .height(DIALOG_NAV_HEIGHT)
            .width(70)
            .textAlign(TextAlign.End)
            .align(Alignment.Center)
            .onClick(() => {
              if (this.canSubmit()) {
                this.saveGroupName()
              }
            })
        }
        .height(DIALOG_NAV_HEIGHT)
        .width('100%')
        .padding({ left: 20, right: 20 })
        .alignItems(VerticalAlign.Center)

        TextInput({
          text: this.groupName,
          placeholder: $r('app.string.conversation_group_name_placeholder')
        })
          .fontSize(16)
          .fontColor('#1F2329')
          .height(60)
          .margin({ left: 19, right: 21, top: 50 })
          .padding({ left: 16, right: 16 })
          .backgroundColor(Color.White)
          .borderRadius(8)
          .cancelButton({
            style: CancelButtonStyle.INPUT,
            icon: {
              src: $r('app.media.input_clean'),
              size: 16,
              color: '#B3B7BC'
            }
          })
          .maxLength(CONVERSATION_GROUP_NAME_MAX_LENGTH)
          .showCounter(true, {
            thresholdPercentage: 1
          })
          .onChange((value: string) => {
            this.groupName = value
          })
      }
      .width('100%')
      .height(DIALOG_HEIGHT)
      .backgroundColor(PAGE_BACKGROUND_COLOR)
      .borderRadius({
        topLeft: DIALOG_RADIUS,
        topRight: DIALOG_RADIUS
      })
      .clip(true)
      .opacity(this.panelOpacity)
      .translate({ y: this.panelOffsetY })
    }
    .width('100%')
    .height(DIALOG_CONTAINER_HEIGHT)
  }

  aboutToAppear(): void {
    this.groupName = this.initialName
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: DIALOG_ANIMATION_DURATION,
        curve: Curve.EaseOut
      }, () => {
        this.panelOffsetY = 0
        this.panelOpacity = 1
        this.maskOpacity = DIALOG_MASK_OPACITY
      })
    }, 0)
  }

  private async saveGroupName(): Promise<void> {
    if (this.isSaving) {
      return
    }
    const name = normalizeConversationGroupName(this.groupName)
    if (name.length <= 0) {
      NECommonUtils.showToast($r('app.string.conversation_group_name_empty_tips'))
      this.groupName = ''
      return
    }
    if (!ErrorUtils.checkNetworkAndToast()) {
      return
    }
    this.isSaving = true
    try {
      await this.onSubmitName?.(name)
      this.onSubmitSuccess?.(name)
      this.closeDialog()
    } catch (e) {
      this.onSubmitError?.(e as Error)
    }
    this.isSaving = false
  }

  private canSubmit(): boolean {
    return !this.isSaving && !this.isClosing && normalizeConversationGroupName(this.groupName).length > 0
  }

  private closeDialog(): void {
    if (this.isClosing) {
      return
    }
    this.isClosing = true
    this.getUIContext().animateTo({
      duration: DIALOG_ANIMATION_DURATION,
      curve: Curve.EaseIn
    }, () => {
      this.panelOffsetY = DIALOG_INITIAL_OFFSET_Y
      this.maskOpacity = 0
    })
    setTimeout(() => {
      if (this.onDialogClose) {
        this.onDialogClose()
        return
      }
      this.controller?.close()
    }, DIALOG_ANIMATION_DURATION)
  }
}

export const CONVERSATION_GROUP_NAME_DIALOG_CONTAINER_HEIGHT: Dimension = DIALOG_CONTAINER_HEIGHT
