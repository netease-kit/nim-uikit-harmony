/*
 * Copyright (c) 2026 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { NECommonUtils } from '@nimkit/common';
import { ReportWebParams } from '../pages/ReportWebPage';

@ComponentV2
export struct FraudTipView {
  @Require
  @Param
  public pathStack: NavPathStack;
  @Require
  @Param
  public canReport: boolean;
  @Require
  @Param
  public canCancel: boolean;
  @Local
  private showFraudTip: boolean = true;

  build() {
    // 外层容器：改用Flex布局实现垂直居中+自适应，替换原Row更适配换行场景
    Flex({
      alignItems: ItemAlign.Center, // 所有元素垂直居中
      justifyContent: FlexAlign.Start // 水平靠左排列
    }) {
      // 1. 左侧警告图标（固定尺寸，不受分辨率影响）
      Image($r('app.media.ic_chat_fraud_tip'))
        .width(20) // 固定宽度
        .height(20) // 固定高度
        .fillColor('#ED0E0E')
        .margin({ right: 8 })
        .flexShrink(0) // 禁止图标被压缩

      // 2. 中间文本区域（自适应剩余空间，包含提示文字+点击举报）
      Flex({
        direction: FlexDirection.Row,
        // flexGrow: 1, // 占满左右图标之间的所有空间
        wrap: FlexWrap.Wrap, // 文字超出自动换行
        alignItems: ItemAlign.Center // 换行后仍垂直居中
      }) {
        Text() {
          Span('仅用于体验云信IM产品功能，请勿轻信汇款，中奖等涉及钱款的信息，勿轻易拨打陌生电话，谨防上当受骗。')
            .fontSize(12)
            .fontColor('#101010')
            .lineHeight(17) // 保证换行后行高均匀
          if (this.canReport) {
            Span('点击举报')
              .fontSize(12)
              .fontColor('#7AA2DB')
              .lineHeight(17) // 保证换行后行高均匀
              .onClick(() => {
                NECommonUtils.showToast('举报成功');

                let params: ReportWebParams = {
                  src: 'https://yunxin.163.com/survey/report',
                  // title: getContext(this).resourceManager.getStringSync($r('app.string.privacy_title_tips').id)
                  title: '点击举报'
                }
                this.pathStack.pushPath({
                  name: 'ReportWebPage',
                  param: params
                })

              })
          }
        }
      }

      // 3. 关闭按钮（X，固定尺寸）
      Image($r('app.media.ic_chat_close')) // 注意替换为正确的关闭图标资源
        .width(16) // 固定宽度
        .height(16) // 固定高度
        .fillColor('#101010')
        .margin({ left: 12 }) // 与文本区域保持间距
        .flexShrink(0) // 禁止关闭图标被压缩
        .onClick(() => {
          this.showFraudTip = false;
        })
        .visibility(this.canCancel ? Visibility.Visible : Visibility.None)
    }
    .width('100%') // 占满父容器宽度，适配任意分辨率
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 12
    })
    .backgroundColor('#F4ECA6')
    .borderRadius(1)
    .borderColor('#BBBBBB')
    .visibility(this.showFraudTip ? Visibility.Visible : Visibility.None)
  }
}