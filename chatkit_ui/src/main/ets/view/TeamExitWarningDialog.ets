/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */

import { ComponentContent } from '@kit.ArkUI'

export class TeamExitDialogParam {
  onConfirm: () => void

  constructor(onConfirm: () => void) {
    this.onConfirm = onConfirm
  }
}

@Builder
export function teamExitWarningDialogBuilder(params: TeamExitDialogParam) {
  Column() {
    Text($r('app.string.chat_team_error_tip_content'))
      .fontSize(20)
      .fontColor('#ff333333')
      .margin({ top: 40, bottom: 50 })
    Flex({ justifyContent: FlexAlign.SpaceAround }) {


      Button($r('app.string.common_sure'))
        .onClick(() => {
          params.onConfirm()
        }).backgroundColor(0xffffff).fontColor('#ff007AFF')
    }.margin({ bottom: 10 })
  }.backgroundColor(Color.White)
  .width('80%')
  .borderRadius(8)
}

export class TeamExitWarningDialog {
  static contentNode: ComponentContent<TeamExitDialogParam>;

  //显示弹窗
  static show(context: UIContext, dialogParam: TeamExitDialogParam) {
    //ComponentContent对象有三个参数
    //参数1:UI 上下文
    //参数2：使用 wrapBuilder 包装 buildGlobalDialogComponent 函数，这个函数用于构建对话框的实际内容
    //参数3:传递给对话框的参数，包含内容文本和按钮的回调函数
    TeamExitWarningDialog.contentNode =
      new ComponentContent(context, wrapBuilder(teamExitWarningDialogBuilder), dialogParam);

    const promptAction = context.getPromptAction() //通过 context 获取 promptAction，用于操作对话框显示

    //显示弹窗
    promptAction.openCustomDialog(TeamExitWarningDialog.contentNode, {
      alignment: DialogAlignment.Center, //对话框在屏幕中央显示
      autoCancel: true, //点击弹窗外区域是否取消弹窗
      onWillDismiss: () => {
        dialogParam.onConfirm()
      }
    });
  }

  //关闭弹窗
  static close(context: UIContext) {
    const promptAction = context.getPromptAction()
    promptAction.closeCustomDialog(TeamExitWarningDialog.contentNode)
  }
}
