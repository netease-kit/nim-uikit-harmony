/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 *
 */
import { EmojiDataModel, NEEmojiManager, NIMInputEmoticon } from '../manager/NEEmojiManager';
import { NEChatEmojiListItem } from './NEChatEmojiListItem';
import display from '@ohos.display';

@Entry
@Component
export struct NEChatEmojiView {
  @State data: EmojiDataModel = NEEmojiManager.instance.dataModel;
  @State page: number = 0;
  @State currentIndex: number = 0
  onDidClick?: (emoji: NIMInputEmoticon) => void;
  @State deviceWidth: number = 0;
  @State deviceHeight: number = 0;
  scroller: Scroller = new Scroller()
  onEmojiSendMessage?: () => void;
  private pageSize = 3 * 8 - 1;
  private pageData: Array<Array<NIMInputEmoticon>> = [];

  aboutToAppear(): void {
    if (this.data.sourceData.length == null) {
      this.data = NEEmojiManager.instance.dataModel;
    }
    console.log("net ease emoji view about to appear ", this.data.sourceData.length);
    this.page = this.data.sourceData.length / this.pageSize;
    let offset = this.data.sourceData.length % this.pageSize;
    console.log('net ease emoji view data page ', this.page);
    for (let index = 0; index < this.page; index++) {
      console.log('net ease emoji view data index ', index);
      let sliceData = this.data.sourceData.slice(index * this.pageSize, this.pageSize * (index + 1))
      let deleteData = NEEmojiManager.instance.deleteEmoji
      if (deleteData !== undefined) {
        console.log('net ease emoji view delete data ', deleteData);
        sliceData.push(deleteData);
      }
      this.pageData.push(sliceData);

    }
    if (offset > 0) {
      this.pageData.push(this.data.sourceData.slice(this.page * this.pageSize, offset));
    }
    console.log('net ease emoji view data page ', this.pageData.length);

    this.deviceWidth = display.getDefaultDisplaySync().width;
    this.deviceHeight = display.getDefaultDisplaySync().height;

    console.log('net ease emoji view device width ', this.deviceWidth);
    console.log('net ease emoji view device height ', this.deviceHeight);
  }

  // randomColor(): ResourceColor {
  //   const randomColor = Math.floor(Math.random() * 16777215).toString(16);
  //   return randomColor
  // }

  build() {

    RelativeContainer() {
      List() {
        ForEach(this.pageData, (items: Array<NIMInputEmoticon>, index) => {
          ListItem() {
            Grid() {
              ForEach(items, (item: NIMInputEmoticon, index) => {
                GridItem() {
                  NEChatEmojiListItem({
                    emoji: item, onDidClick: (emoji: NIMInputEmoticon) => {
                      if (this.onDidClick) {
                        this.onDidClick(emoji)
                      }
                    }
                  })
                }
              })
            }
            .width('100%')
            .height('100%')
            .rowsTemplate('1fr 1fr 1fr')
            .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
          }
        })
      }
      .chainAnimation(true)
      .edgeEffect(EdgeEffect.Spring)
      .listDirection(Axis.Horizontal)
      .height('80%')
      .width('100%')
      .scrollSnapAlign(ScrollSnapAlign.CENTER)
      .scrollBar(BarState.Off)

      Text($r("app.string.chat_send"))
        .alignRules({
          right: { anchor: "__container__", align: HorizontalAlign.End },
          bottom: { anchor: "__container__", align: VerticalAlign.Bottom },
        })
        .textAlign(TextAlign.Center)
        .width(70)
        .height(35)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.color_chat_send'))
        .onClick(() => {
          if (this.onEmojiSendMessage) {
            this.onEmojiSendMessage()
          }
        })
    }

  }
}