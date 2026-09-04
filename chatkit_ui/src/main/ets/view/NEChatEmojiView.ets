/*
 * Copyright (c) 2022 NetEase, Inc. All rights reserved.
 * Use of this source code is governed by a MIT license that can be
 * found in the LICENSE file.
 */

import { NEEmojiManager, NIMInputEmoticon } from '../manager/NEEmojiManager'
import { NEStickerItem, NEStickerPackage } from '../model/NEStickerPackage'
import {
  buildEmoticonPages,
  clampEmoticonPageIndex,
  getPackageStartPage,
  NEEmoticonPage,
  NEEmoticonPageType
} from '../utils/EmoticonPaginationUtils'
import { NEChatEmojiListItem } from './NEChatEmojiListItem'
import { NEChatStickerListItem } from './NEChatStickerListItem'

const EMOTICON_CONTENT_HEIGHT: number = 125
const PAGE_INDICATOR_HEIGHT: number = 10
const EMOTICON_BOTTOM_HEIGHT: number = 35
const EMOTICON_TAB_WIDTH: number = 44
const EMOTICON_TAB_SELECTED_RADIUS: number = 6

@ComponentV2
export struct NEChatEmojiView {
  @Local manager: NEEmojiManager = NEEmojiManager.instance
  @Local currentGlobalIndex: number = 0
  @Param @Require onDidClick?: (emoji: NIMInputEmoticon) => void
  @Param @Require onStickerClick?: (sticker: NEStickerItem) => void
  @Param @Require onEmojiSendMessage?: () => void
  private swiperController: SwiperController = new SwiperController()
  private tabScroller: Scroller = new Scroller()

  @Computed
  get pages(): NEEmoticonPage[] {
    return buildEmoticonPages(this.manager.dataModel.sourceData, this.manager.stickerPackages,
      this.manager.deleteEmoji, this.manager.stickerPackageRevision)
  }

  @Computed
  get currentPage(): NEEmoticonPage | undefined {
    if (this.pages.length === 0) {
      return undefined
    }
    return this.pages[clampEmoticonPageIndex(this.currentGlobalIndex, this.pages.length)]
  }

  @Computed
  get currentPackageIndex(): number {
    return this.currentPage?.packageIndex ?? 0
  }

  private handlePageChanged(index: number): void {
    this.currentGlobalIndex = clampEmoticonPageIndex(index, this.pages.length)
    this.tabScroller.scrollToIndex(this.currentPackageIndex, true, ScrollAlign.CENTER)
  }

  private selectPackage(packageIndex: number): void {
    const targetPage = getPackageStartPage(this.pages, packageIndex)
    if (targetPage < 0) {
      return
    }
    this.currentGlobalIndex = targetPage
    this.swiperController.changeIndex(targetPage, true)
    this.tabScroller.scrollToIndex(packageIndex, true, ScrollAlign.CENTER)
  }

  private getIndicatorIndexes(): number[] {
    const indexes: number[] = []
    const pageCount = this.currentPage?.packagePageCount ?? 0
    for (let index = 0; index < pageCount; index++) {
      indexes.push(index)
    }
    return indexes
  }

  @Builder
  private EmojiPage(page: NEEmoticonPage) {
    Grid() {
      ForEach(page.emojis, (item: NIMInputEmoticon) => {
        GridItem() {
          NEChatEmojiListItem({
            emoji: item,
            onDidClick: (emoji: NIMInputEmoticon): void => {
              this.onDidClick?.(emoji)
            }
          })
        }
      }, (item: NIMInputEmoticon, index: number): string => item.id ?? `delete-${page.key}-${index}`)
    }
    .width('100%')
    .height('100%')
    .rowsTemplate('1fr 1fr 1fr')
    .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
  }

  @Builder
  private StickerPage(page: NEEmoticonPage) {
    Grid() {
      ForEach(page.stickers, (item: NEStickerItem) => {
        GridItem() {
          NEChatStickerListItem({
            sticker: item,
            onDidClick: (sticker: NEStickerItem): void => {
              this.onStickerClick?.(sticker)
            }
          })
        }
      }, (item: NEStickerItem): string => item.id)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 10, right: 10 })
    .rowsTemplate('1fr 1fr')
    .columnsTemplate('1fr 1fr 1fr 1fr')
  }

  @Builder
  private PageIndicator() {
    Row({ space: 4 }) {
      ForEach(this.getIndicatorIndexes(), (pageIndex: number) => {
        Circle()
          .width(5)
          .height(5)
          .fill(pageIndex === this.currentPage?.pageIndexInPackage ?
            $r('app.color.color_chat_send') : Color.White)
          .stroke(pageIndex === this.currentPage?.pageIndexInPackage ?
            $r('app.color.color_chat_send') : $r('app.color.color_chat_emoticon_indicator_border'))
          .strokeWidth(pageIndex === this.currentPage?.pageIndexInPackage ? 0 : 0.5)
      }, (pageIndex: number): string =>
        `${this.currentPackageIndex}-${this.currentPage?.pageIndexInPackage ?? 0}-${pageIndex}`)
    }
    .width('100%')
    .height(PAGE_INDICATOR_HEIGHT)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private EmojiTab() {
    ListItem() {
      Stack() {
        Image($rawfile('emoji/nim_emoji_icon.png'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
      }
      .width(EMOTICON_TAB_WIDTH)
      .height(EMOTICON_BOTTOM_HEIGHT)
      .backgroundColor(this.currentPackageIndex === 0 ?
        $r('app.color.color_chat_emoticon_tab_selected_bg') : Color.Transparent)
      .borderRadius({ bottomLeft: EMOTICON_TAB_SELECTED_RADIUS, bottomRight: EMOTICON_TAB_SELECTED_RADIUS })
      .onClick((): void => this.selectPackage(0))
    }
  }

  @Builder
  private StickerTab(stickerPackage: NEStickerPackage, packageIndex: number) {
    ListItem() {
      Stack() {
        Image(stickerPackage.selectedTabIcon)
          .width(28)
          .height(28)
          .objectFit(ImageFit.Contain)
      }
      .width(EMOTICON_TAB_WIDTH)
      .height(EMOTICON_BOTTOM_HEIGHT)
      .backgroundColor(this.currentPackageIndex === packageIndex ?
        $r('app.color.color_chat_emoticon_tab_selected_bg') : Color.Transparent)
      .borderRadius({ bottomLeft: EMOTICON_TAB_SELECTED_RADIUS, bottomRight: EMOTICON_TAB_SELECTED_RADIUS })
      .onClick((): void => this.selectPackage(packageIndex))
    }
  }

  @Builder
  private BottomBar() {
    Row() {
      List({ scroller: this.tabScroller, space: 0 }) {
        this.EmojiTab()
        ForEach(this.manager.stickerPackages, (stickerPackage: NEStickerPackage, index: number) => {
          this.StickerTab(stickerPackage, index + 1)
        }, (stickerPackage: NEStickerPackage): string =>
          `${stickerPackage.id}-${this.manager.stickerPackageRevision}`)
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .height(EMOTICON_BOTTOM_HEIGHT)

      if (this.currentPackageIndex === 0) {
        Text($r('app.string.chat_send'))
          .textAlign(TextAlign.Center)
          .width(70)
          .height(EMOTICON_BOTTOM_HEIGHT)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.color_chat_send'))
          .onClick((): void => {
            this.onEmojiSendMessage?.()
          })
      }
    }
    .width('100%')
    .height(EMOTICON_BOTTOM_HEIGHT)
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        ForEach(this.pages, (page: NEEmoticonPage) => {
          if (page.type === NEEmoticonPageType.EMOJI) {
            this.EmojiPage(page)
          } else {
            this.StickerPage(page)
          }
        }, (page: NEEmoticonPage): string => page.key)
      }
      .width('100%')
      .height(EMOTICON_CONTENT_HEIGHT)
      .autoPlay(false)
      .loop(false)
      .indicator(false)
      .effectMode(EdgeEffect.Fade)
      .index(clampEmoticonPageIndex(this.currentGlobalIndex, this.pages.length))
      .onChange((index: number): void => this.handlePageChanged(index))

      this.PageIndicator()
      this.BottomBar()
    }
    .width('100%')
    .height(EMOTICON_CONTENT_HEIGHT + PAGE_INDICATOR_HEIGHT + EMOTICON_BOTTOM_HEIGHT)
  }
}
