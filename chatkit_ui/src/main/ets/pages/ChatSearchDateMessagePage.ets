/*
 *  Copyright (c) 2022 NetEase, Inc. All rights reserved.
 *  Use of this source code is governed by a MIT license that can be
 *  found in the LICENSE file.
 */

import {
  AvatarColorUntil,
  AvatarItem,
  CommonAvatar,
  CommonEmptyResult,
  TailString
} from '@nimkit/common'
import {
  ChatSearchDateMessageParams,
  ChatSearchDateMessageViewModel,
  DateGroupedMessages
} from '../viewmodel/ChatSearchDateMessageViewModel'
import { SearchDateMessage } from '../model/SearchDateMessage'
import { NIMMessageInfo } from '../model/NIMMessageInfo'
import { ChatBaseViewModel } from '../viewmodel/ChatBaseViewModel'
import { V2NIMConversationType, V2NIMMessageType } from '@nimsdk/base'
import { DateUtil } from '@nimkit/common'
import {
  getMessageBackgroundColor,
  memberHistoryMessageContent
} from '../view/MessageComponentBuilder'
import { ChatKitClient } from '@nimkit/chatkit'

// 跳转页面入口函数
@Builder
export function ChatSearchDateMessagePageBuilder() {
  ChatSearchDateMessagePage()
}

/**
 * 快捷日期选项类型
 */
enum QuickDateType {
  NONE = 0,
  TODAY = 1,
  LAST_7_DAYS = 2,
  LAST_30_DAYS = 3
}

/**
 * 月份数据
 */
interface MonthData {
  year: number
  month: number
  days: (number | null)[]
}

/**
 * 年月选择器对话框（只选择年和月）
 */
@CustomDialog
struct YearMonthPickerDialog {
  controller?: CustomDialogController
  currentYear: number = new Date().getFullYear()
  currentMonth: number = new Date().getMonth() + 1
  onConfirm?: (year: number, month: number) => void
  // 选中的年月
  @State selectedYear: number = new Date().getFullYear()
  @State selectedMonth: number = new Date().getMonth() + 1
  // 年份列表（1970-2170）
  private yearList: string[] = []
  // 月份列表（1-12），需要通过 getContext 获取资源
  private monthList: string[] = []

  aboutToAppear(): void {
    // 初始化年份列表（最大到当前年份）
    const context = getContext(this)
    const maxYear = new Date().getFullYear()
    for (let year = 1970; year <= maxYear; year++) {
      const yearStr = context.resourceManager.getStringSync($r('app.string.search_date_year_format').id, year)
      this.yearList.push(yearStr)
    }
    // 初始化月份列表
    this.monthList = [
      context.resourceManager.getStringSync($r('app.string.search_date_month_1').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_2').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_3').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_4').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_5').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_6').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_7').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_8').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_9').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_10').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_11').id),
      context.resourceManager.getStringSync($r('app.string.search_date_month_12').id)
    ]
    // 设置初始值
    this.selectedYear = this.currentYear
    this.selectedMonth = this.currentMonth
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text($r('app.string.chat_msg_dialog_cancel'))
          .fontSize(16)
          .fontColor('#999999')
          .onClick(() => {
            this.controller?.close()
          })

        Text($r('app.string.search_date_select_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text($r('app.string.chat_msg_dialog_sure'))
          .fontSize(16)
          .fontColor('#337EFF')
          .onClick(() => {
            this.onConfirm?.(this.selectedYear, this.selectedMonth)
            this.controller?.close()
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // 分割线
      Divider()
        .width('100%')
        .height(0.5)
        .color('#E5E5E5')

      // 年月选择器
      Row() {
        // 年份选择（不循环）
        TextPicker({ range: this.yearList, selected: this.selectedYear - 1970 })
          .layoutWeight(1)
          .canLoop(false)
          .onChange((value: string | string[], index: number | number[]) => {
            if (typeof index === 'number') {
              this.selectedYear = 1970 + index
            }
          })

        // 月份选择（不循环）
        TextPicker({ range: this.monthList, selected: this.selectedMonth - 1 })
          .layoutWeight(1)
          .canLoop(false)
          .onChange((value: string | string[], index: number | number[]) => {
            if (typeof index === 'number') {
              this.selectedMonth = index + 1
            }
          })
      }
      .width('100%')
      .height(200)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}

/**
 * 日期消息操作对话框
 */
@CustomDialog
struct DateMessageActionDialog {
  message?: NIMMessageInfo
  controller?: CustomDialogController
  onMessageLocateChat?: () => void

  locateChat = () => {
    this.cancel()
    this.onMessageLocateChat?.()
  }

  cancel = () => {
    this.controller?.close()
  }

  build() {
    Column() {
      Column() {
        Text($r('app.string.chat_history_message_operation_locate'))
          .fontSize(14)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.locateChat)
      }
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ left: 12, right: 12 })

      Column() {
        Text($r('app.string.chat_msg_dialog_cancel'))
          .fontSize(14)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .height(42)
          .width('100%')
          .onClick(this.cancel)
      }
      .height(42)
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .margin({ top: 10, left: 12, right: 12 })
    }
    .height(42 * 2 + 10 + 2)
    .backgroundColor(Color.Transparent)
  }
}

/**
 * 消息列表项组件 - 使用 memberHistoryMessageContent 展示不同类型消息
 */
@ComponentV2
struct DateMessageItem {
  @Param item?: SearchDateMessage = undefined
  @Param showTime?: boolean = true // 是否显示时间（默认显示）
  @Param onClickHandler?: () => void = undefined
  @Param onLongClick?: () => void = undefined

  // 将 SearchDateMessage 转换为 NIMMessageInfo
  getMessageInfo(): NIMMessageInfo | undefined {
    if (!this.item) {
      return undefined
    }
    return new NIMMessageInfo(this.item.message)
  }

  // 判断是否是文本消息
  isTextMessage(): boolean {
    return this.item?.message.messageType === V2NIMMessageType.V2NIM_MESSAGE_TYPE_TEXT
  }

  build() {
    Column() {
      // 时间（单独一行，居中显示）
      if (this.showTime) {
        Text(DateUtil.formatTimestamp(this.item?.message.createTime ?? 0, true))
          .fontSize(12)
          .fontColor('#B3B3B3')
          .margin({ top: 6, bottom: 6 })
      }

      // 消息主体（头像 + 内容）
      Row() {
        // 头像（统一在左侧）
        CommonAvatar({
          item: new AvatarItem(
            this.item?.getAvatar(),
            TailString(this.item?.getAvatarName() ?? ''),
            AvatarColorUntil.getBackgroundColorById(this.item?.getAccId() ?? '')
          ),
          roundRadius: 21
        })
          .width(42)
          .height(42)
          .margin({ left: 16 })

        Column() {
          // 发送者昵称
          Text(this.item?.getNickname() ?? this.item?.message.senderId ?? '')
            .fontSize(12)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 消息内容（使用 memberHistoryMessageContent 展示不同类型）
          if (this.getMessageInfo()) {
            memberHistoryMessageContent({
              message: this.getMessageInfo()!,
              onMessageClick: undefined
            })
              .backgroundColor(getMessageBackgroundColor(this.getMessageInfo(),
                $r('app.color.color_chat_receive_message_bg')))
              .borderRadius({
                topLeft: 0,      // 左上角直角
                topRight: 8,     // 右上角圆角
                bottomLeft: 8,   // 左下角圆角
                bottomRight: 8   // 右下角圆角
              })
          }
        }
        .layoutWeight(1)
        .margin({ left: 10, right: 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding({ bottom: 6 })
    .backgroundColor(Color.White)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => this.onClickHandler?.())
    .gesture(LongPressGesture().onAction(() => {
      this.onLongClick?.()
    }))
  }
}

/**
 * 按日期搜索消息页面
 */
@ComponentV2
export struct ChatSearchDateMessagePage {
  pathStack: NavPathStack = new NavPathStack()
  // 会话Id
  conversationId?: string
  @Local viewModel?: ChatSearchDateMessageViewModel
  // 日期选择：单选日期（搜索范围为该日期到当前时间）
  @Local selectedDate: Date | undefined = undefined
  // 快捷选项状态
  @Local quickSelectType: QuickDateType = QuickDateType.NONE
  // 是否显示搜索结果
  @Local showSearchResult: boolean = false
  // 加载状态
  @Local isLoading: boolean = false
  @Local isLoadingMore: boolean = false
  // 当前点击的消息（用于跳转）
  @Local tapMessage?: SearchDateMessage
  // 月份列表（用于日历显示）
  @Local monthList: MonthData[] = []
  // 当前显示的年月（用于顶部年月显示器）
  @Local currentYear: number = new Date().getFullYear()
  @Local currentMonth: number = new Date().getMonth() + 1
  // 可选年份范围
  private minDate: Date = new Date('1970-1-1')
  private maxDate: Date = new Date() // 最新日期为当天
  // 滚动控制器
  private listScroller: Scroller = new Scroller()
  private calendarScroller: Scroller = new Scroller()
  // 星期标题（使用国际化资源）
  private weekDays: Resource[] = [
    $r('app.string.search_date_weekday_sun'),
    $r('app.string.search_date_weekday_mon'),
    $r('app.string.search_date_weekday_tue'),
    $r('app.string.search_date_weekday_wed'),
    $r('app.string.search_date_weekday_thu'),
    $r('app.string.search_date_weekday_fri'),
    $r('app.string.search_date_weekday_sat')
  ]
  private monthNames: Resource[] = [
    $r('app.string.search_date_month_1'),
    $r('app.string.search_date_month_2'),
    $r('app.string.search_date_month_3'),
    $r('app.string.search_date_month_4'),
    $r('app.string.search_date_month_5'),
    $r('app.string.search_date_month_6'),
    $r('app.string.search_date_month_7'),
    $r('app.string.search_date_month_8'),
    $r('app.string.search_date_month_9'),
    $r('app.string.search_date_month_10'),
    $r('app.string.search_date_month_11'),
    $r('app.string.search_date_month_12')
  ]

  // 长按操作对话框
  messageActionDialog?: CustomDialogController
  // 年月选择器对话框
  yearMonthPickerDialog?: CustomDialogController
  // 是否正在加载更早的月份（防止重复加载）
  private isLoadingEarlierMonths: boolean = false

  // 定位到聊天
  locateChat = () => {
    if (ChatBaseViewModel.currentViewModel && this.tapMessage) {
      const msgInfo = new NIMMessageInfo(this.tapMessage.message)
      ChatBaseViewModel.currentViewModel.setAnchorMessage(msgInfo)
    }
    // 等待 200ms，等待 anchor 计算完毕后再回页面
    setTimeout(() => {
      const conversationType: V2NIMConversationType = ChatKitClient.nim.conversationIdUtil.parseConversationType(this.conversationId)
      if (conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_P2P) {
        this.pathStack.popToName('ChatP2PPage')
      } else if (conversationType == V2NIMConversationType.V2NIM_CONVERSATION_TYPE_TEAM) {
        this.pathStack.popToName('ChatTeamPage')
      } else {
        // Unknown. 直接往回弹一个页面，不管是什么页面
        this.pathStack.pop()
      }
    }, 200)
  }

  private getCurrentYearMonthLabel(): string {
    return getContext(this).resourceManager.getStringSync($r('app.string.search_date_year_month_format').id,
      this.currentYear, getContext(this).resourceManager.getStringSync(this.monthNames[this.currentMonth - 1].id))
  }

  // 初始化数据
  async initData() {
    let params = this.pathStack.getParamByName('ChatSearchDateMessagePage') as ChatSearchDateMessageParams[]
    if (params.length > 0) {
      let param = params[params.length - 1]
      this.conversationId = param.conversationId
      if (this.conversationId) {
        this.viewModel = new ChatSearchDateMessageViewModel(this.conversationId)
      }
    } else {
      this.pathStack.removeByName('ChatSearchDateMessagePage')
    }
    // 初始化月份列表
    this.initMonthList()
    // 默认选中"今天"
    this.onQuickSelectClick(QuickDateType.TODAY) // default
  }

  // 初始化月份列表（加载当前月及之前12个月，不加载未来月份）
  initMonthList() {
    const now = new Date()
    const todayYear = now.getFullYear()
    const todayMonth = now.getMonth() + 1

    this.monthList = []

    // 加载往前12个月
    for (let i = 12; i >= 1; i--) {
      let year = todayYear
      let month = todayMonth - i
      while (month <= 0) {
        month += 12
        year -= 1
      }
      // 确保不低于1970年
      if (year >= 1970) {
        this.monthList.push(this.generateMonthData(year, month))
      }
    }

    // 加载当前月（最新月份为当前月，不加载未来月份）
    this.monthList.push(this.generateMonthData(todayYear, todayMonth))

    // 设置按钮显示为今天的年月
    this.currentYear = todayYear
    this.currentMonth = todayMonth

    // 延迟滚动到当前月份（需要等待列表渲染完成）
    // 使用较长延迟确保滚动完成后 onScrollIndex 回调能正确更新
    setTimeout(() => {
      this.scrollToTodayMonth()
      // 滚动后再次确保显示今天的年月
      this.currentYear = todayYear
      this.currentMonth = todayMonth
    }, 150)
  }
  
  // 滚动到今天所在的月份
  scrollToTodayMonth() {
    const now = new Date()
    const currentYear = now.getFullYear()
    const currentMonth = now.getMonth() + 1
    
    // 查找当前月份在列表中的索引
    for (let i = 0; i < this.monthList.length; i++) {
      const m = this.monthList[i]
      if (m.year === currentYear && m.month === currentMonth) {
        this.calendarScroller.scrollToIndex(i)
        break
      }
    }
  }

  // 加载更早的月份
  loadEarlierMonths() {
    // 防止重复加载
    if (this.isLoadingEarlierMonths) return
    if (this.monthList.length === 0) return

    const firstMonth = this.monthList[0]
    // 已经到达1970年1月，不再加载
    if (firstMonth.year === 1970 && firstMonth.month === 1) return

    this.isLoadingEarlierMonths = true

    const newMonths: MonthData[] = []
    for (let i = 1; i <= 6; i++) {
      let year = firstMonth.year
      let month = firstMonth.month - i
      if (month <= 0) {
        month += 12
        year -= 1
      }
      // 不加载1970年之前的月份
      if (year < 1970) break
      newMonths.unshift(this.generateMonthData(year, month))
    }

    if (newMonths.length > 0) {
      const addedCount = newMonths.length
      this.monthList = [...newMonths, ...this.monthList]

      // 加载完成后，调整滚动位置以保持当前查看的内容不变
      // 由于在列表前面插入了元素，需要将滚动位置向后调整
      setTimeout(() => {
        this.calendarScroller.scrollToIndex(addedCount)
        this.isLoadingEarlierMonths = false
      }, 50)
    } else {
      this.isLoadingEarlierMonths = false
    }
  }

  // 加载更晚的月份（最大到当前月份，不加载未来月份）
  loadLaterMonths() {
    // 最新日期为当天，不需要加载更晚的月份
    // 此方法保留但不执行任何操作
  }

  // 生成月份数据
  generateMonthData(year: number, month: number): MonthData {
    const firstDay = new Date(year, month - 1, 1)
    const lastDay = new Date(year, month, 0)
    const daysInMonth = lastDay.getDate()
    const startDayOfWeek = firstDay.getDay()

    const days: (number | null)[] = []
    // 填充月初空白
    for (let i = 0; i < startDayOfWeek; i++) {
      days.push(null)
    }
    // 填充日期
    for (let i = 1; i <= daysInMonth; i++) {
      days.push(i)
    }

    return { year, month, days }
  }

  // 处理快捷选项点击（单选模式：选择特定日期，搜索范围为该日期到当前时间）
  onQuickSelectClick(type: QuickDateType) {
    // 单选模式下不支持反选，只切换选择
    this.quickSelectType = type

    let date = new Date()
    date.setHours(0, 0, 0, 0)

    switch (type) {
      case QuickDateType.TODAY:
        // 今天
        this.selectedDate = date
        break
      case QuickDateType.LAST_7_DAYS:
        // 7天前（不含今日）
        date.setDate(date.getDate() - 7)
        this.selectedDate = date
        break
      case QuickDateType.LAST_30_DAYS:
        // 30天前（不含今日）
        date.setDate(date.getDate() - 30)
        this.selectedDate = date
        break
    }

    // 跳转日历到选中日期所在月份
    if (this.selectedDate) {
      this.scrollToMonth(this.selectedDate.getFullYear(), this.selectedDate.getMonth() + 1)
    }
  }

  // 处理日历日期点击（单选模式）
  onDateClick(year: number, month: number, day: number) {
    const clickedDate = new Date(year, month - 1, day)
    clickedDate.setHours(0, 0, 0, 0)

    // 单选模式：直接设置选中日期，不支持反选
    this.selectedDate = clickedDate

    // 检查点击的日期是否对应快捷选项
    const now = new Date()
    now.setHours(0, 0, 0, 0)

    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    today.setHours(0, 0, 0, 0)
    const sevenDaysAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000) // 7 天前（不含今日）
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000) // 30 天前（不含今日）

    if (clickedDate.getTime() === today.getTime()) {
      this.quickSelectType = QuickDateType.TODAY
    } else if (clickedDate.getTime() === sevenDaysAgo.getTime()) {
      this.quickSelectType = QuickDateType.LAST_7_DAYS
    } else if (clickedDate.getTime() === thirtyDaysAgo.getTime()) {
      this.quickSelectType = QuickDateType.LAST_30_DAYS
    } else {
      this.quickSelectType = QuickDateType.NONE
    }
  }

  // 判断日期是否是选中日期（用于显示深蓝圆形）
  isSelectedDate(year: number, month: number, day: number): boolean {
    if (!this.selectedDate) return false

    const date = new Date(year, month - 1, day)
    date.setHours(0, 0, 0, 0)

    const selectedTime = new Date(this.selectedDate)
    selectedTime.setHours(0, 0, 0, 0)

    return date.getTime() === selectedTime.getTime()
  }

  // 判断是否是今天
  isToday(year: number, month: number, day: number): boolean {
    const today = new Date()
    return today.getFullYear() === year &&
      today.getMonth() + 1 === month &&
      today.getDate() === day
  }

  // 判断是否是未来日期（超过今天）
  isFutureDate(year: number, month: number, day: number): boolean {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const date = new Date(year, month - 1, day)
    date.setHours(0, 0, 0, 0)
    return date.getTime() > today.getTime()
  }

  // 判断是否有选择日期（用于完成按钮状态）
  hasDateSelected(): boolean {
    return this.selectedDate !== undefined
  }

  // 点击完成按钮（搜索范围：选中日期到当前时间）
  // 直接跳转到聊天页面，定位到搜索结果的第一条消息（最老的）
  async onConfirmClick() {
    if (!this.selectedDate || !this.viewModel) {
      return
    }

    // 开始时间：选中日期的 00:00:00
    const start = new Date(this.selectedDate)
    start.setHours(0, 0, 0, 0)
    let startTime = start.getTime()

    // 结束时间：当前时间
    let endTime = new Date().getTime()

    this.viewModel.setDateRange(startTime, endTime)
    this.isLoading = true
    try {
      await this.viewModel.searchMessagesByDate(true)

      // groupedMessageList 按日期降序排列（最新在前，最老在后）
      // 每个 group 内部消息按 FORWARD 方向返回顺序（从老到新）
      // 所以最老的消息是：最后一个 group 的最后一条消息
      const groups: DateGroupedMessages[] = this.viewModel.groupedMessageList
      for (let i = groups.length - 1; i >= 0; i--) {
        const group = groups[i]
        if (group.messages && group.messages.length > 0) {
          const lastMessage = group.messages[group.messages.length - 1]
          // 设置要跳转的消息并直接跳转到聊天页面
          this.tapMessage = lastMessage
          break; // 只返回第一个找到的结果，后续不再查找（减少网络请求）
        } else {
          continue;
        }
      }
      this.locateChat()

      // 如果没有搜索结果，显示结果页面（空状态）
      this.showSearchResult = false // 不再在当前页面展示结果了，所以不需要去设置为 true
    } finally {
      this.isLoading = false
    }
  }

  // 返回日期选择
  backToDateSelect() {
    this.showSearchResult = false
    this.viewModel?.clearMessages()
  }

  // 加载更多消息
  async loadMoreMessages() {
    if (!this.viewModel || this.isLoadingMore || !this.viewModel.hasMore) {
      return
    }
    this.isLoadingMore = true
    try {
      await this.viewModel.searchMessagesByDate(false)
    } finally {
      this.isLoadingMore = false
    }
  }

  // 显示消息操作对话框
  showMessageActionDialog(msg: SearchDateMessage) {
    this.tapMessage = msg
    const msgInfo = new NIMMessageInfo(msg.message)
    this.messageActionDialog = new CustomDialogController({
      builder: DateMessageActionDialog({
        message: msgInfo,
        onMessageLocateChat: this.locateChat
      }),
      cornerRadius: 0,
      alignment: DialogAlignment.Bottom,
      backgroundColor: Color.Transparent,
      backgroundBlurStyle: BlurStyle.NONE,
    })
    this.messageActionDialog.open()
  }

  // 打开年月选择器（使用自定义对话框，只选择年月）
  openYearMonthPicker() {
    // 使用当前显示的年月作为默认选中值（与按钮显示保持一致）
    this.yearMonthPickerDialog = new CustomDialogController({
      builder: YearMonthPickerDialog({
        currentYear: this.currentYear,
        currentMonth: this.currentMonth,
        onConfirm: (year: number, month: number) => {
          // 跳转到选择的月份
          this.scrollToMonth(year, month)
        }
      }),
      cornerRadius: { topLeft: 16, topRight: 16 },
      alignment: DialogAlignment.Bottom,
      backgroundColor: Color.White,
      customStyle: true
    })
    this.yearMonthPickerDialog.open()
  }

  // 滚动到指定月份
  scrollToMonth(year: number, month: number) {
    // 边界检查：最小1970年，最大为当前年月
    const now = new Date()
    const maxYear = now.getFullYear()
    const maxMonth = now.getMonth() + 1

    if (year < 1970) return
    // 不允许跳转到未来月份
    if (year > maxYear || (year === maxYear && month > maxMonth)) {
      year = maxYear
      month = maxMonth
    }
    
    // 查找目标月份在列表中的索引
    let targetIndex = -1
    for (let i = 0; i < this.monthList.length; i++) {
      const m = this.monthList[i]
      if (m.year === year && m.month === month) {
        targetIndex = i
        break
      }
    }

    if (targetIndex === -1) {
      // 目标月份不在列表中，需要扩展列表
      // 判断是需要加载更早还是更晚的月份
      const firstMonth = this.monthList[0]
      const lastMonth = this.monthList[this.monthList.length - 1]
      
      const targetDate = new Date(year, month - 1, 1)
      const firstDate = new Date(firstMonth.year, firstMonth.month - 1, 1)
      const lastDate = new Date(lastMonth.year, lastMonth.month - 1, 1)

      if (targetDate < firstDate) {
        // 需要加载更早的月份
        const newMonths: MonthData[] = []
        let y = firstMonth.year
        let m = firstMonth.month - 1
        while (y > year || (y === year && m >= month)) {
          if (m <= 0) {
            m = 12
            y -= 1
          }
          // 不加载1970年之前的月份
          if (y < 1970) break
          newMonths.unshift(this.generateMonthData(y, m))
          m -= 1
        }
        if (newMonths.length > 0) {
          this.monthList = [...newMonths, ...this.monthList]
          // 重新查找目标索引
          for (let i = 0; i < this.monthList.length; i++) {
            const item = this.monthList[i]
            if (item.year === year && item.month === month) {
              targetIndex = i
              break
            }
          }
        }
      } else if (targetDate > lastDate) {
        // 需要加载更晚的月份
        const newMonths: MonthData[] = []
        let y = lastMonth.year
        let m = lastMonth.month + 1
        while (y < year || (y === year && m <= month)) {
          if (m > 12) {
            m = 1
            y += 1
          }
          // 不加载2170年之后的月份
          if (y > 2170) break
          newMonths.push(this.generateMonthData(y, m))
          m += 1
        }
        if (newMonths.length > 0) {
          this.monthList = [...this.monthList, ...newMonths]
          // 重新查找目标索引
          for (let i = 0; i < this.monthList.length; i++) {
            const item = this.monthList[i]
            if (item.year === year && item.month === month) {
              targetIndex = i
              break
            }
          }
        }
      }
    }

    if (targetIndex >= 0) {
      this.calendarScroller.scrollToIndex(targetIndex)
      this.currentYear = year
      this.currentMonth = month
    }
  }

  // 获取月份标题文本
  getMonthTitle(monthData: MonthData): string {
    if (monthData.month === 1) {
      return `${monthData.year}年1月`
    }
    return `${monthData.month}月`
  }

  // 构建快捷选项按钮
  @Builder
  QuickSelectButton(type: QuickDateType, text: Resource) {
    Text(text)
      .fontSize(14)
      .fontColor(this.quickSelectType === type ? Color.White : '#333333')
      .backgroundColor(this.quickSelectType === type ? '#337EFF' : Color.White)
      .borderRadius(4)
      .border({ width: 1, color: this.quickSelectType === type ? '#337EFF' : '#D9D9D9' })
      .height(32)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .onClick(() => this.onQuickSelectClick(type))
  }

  // 判断是否是月份的第一天
  isFirstDayOfMonth(day: number): boolean {
    return day === 1
  }

  // 判断是否是月份的最后一天
  isLastDayOfMonth(year: number, month: number, day: number): boolean {
    const lastDay = new Date(year, month, 0).getDate()
    return day === lastDay
  }

  // 构建日历日期单元格（单选模式）
  @Builder
  CalendarDayCell(day: number | null, year: number, month: number, isFirstInRow: boolean, isLastInRow: boolean) {
    if (day !== null) {
      Column() {
        Stack() {
          // 日期圆形（选中日期用深蓝色圆形）
          // 未来日期显示置灰
          Column() {
            Text(day.toString())
              .fontSize(16)
              .fontColor(
                this.isFutureDate(year, month, day) ? '#CCCCCC' :
                (this.isSelectedDate(year, month, day) ? Color.White :
                (this.isToday(year, month, day) ? '#337EFF' : '#333333'))
              )
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(
            this.isFutureDate(year, month, day) ? Color.Transparent :
            (this.isSelectedDate(year, month, day) ? '#337EFF' : Color.Transparent)
          )
          .borderRadius(18)
        }
        .width('100%')
        .height(36)

        // "今天"标注（在圆圈下方）
        if (this.isToday(year, month, day)) {
          Text($r('app.string.search_date_today'))
            .fontSize(10)
            .fontColor('#337EFF')
            .margin({ top: 2 })
        }
      }
      .width('100%')
      .height(52)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        // 未来日期不可点击
        if (!this.isFutureDate(year, month, day)) {
          this.onDateClick(year, month, day)
        }
      })
    } else {
      Column()
        .width('100%')
        .height(52)
    }
  }

  // 构建月份日历
  @Builder
  MonthCalendar(monthData: MonthData) {
    Column() {
      // 月份标题
      Text(this.getMonthTitle(monthData))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#999999')
        .width('100%')
        .padding({ left: 16, top: 16, bottom: 8 })

      // 日期网格
      Grid() {
        ForEach(monthData.days, (day: number | null, index: number) => {
          GridItem() {
            this.CalendarDayCell(
              day, 
              monthData.year, 
              monthData.month,
              index % 7 === 0,
              index % 7 === 6
            )
          }
        }, (day: number | null, index: number) => `${monthData.year}-${monthData.month}-${index}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(4)
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 8 })
    }
    .width('100%')
    .backgroundColor(Color.White)
  }

  // 构建日期选择视图
  @Builder
  DateSelectView() {
    Column() {
      // 快捷选项栏
      Row({ space: 12 }) {
        this.QuickSelectButton(QuickDateType.TODAY, $r('app.string.search_date_today'))
        this.QuickSelectButton(QuickDateType.LAST_7_DAYS, $r('app.string.search_date_last_7_days'))
        this.QuickSelectButton(QuickDateType.LAST_30_DAYS, $r('app.string.search_date_last_30_days'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Color.White)

      // 年月显示器
      Row() {
        Text(this.getCurrentYearMonthLabel())
          .fontSize(14)
          .fontColor('#999999')
        Image($r('sys.media.ohos_ic_public_arrow_down'))
          .width(12)
          .height(12)
          .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 16, top: 8, bottom: 8 })
      .backgroundColor(Color.White)
      .onClick(() => this.openYearMonthPicker())

      // 星期标题行
      Row() {
        ForEach(this.weekDays, (day: Resource, index: number) => {
          Text(day)
            .fontSize(12)
            .fontColor('#999999')
            .width('14.28%')
            .textAlign(TextAlign.Center)
        }, (day: Resource, index: number) => index.toString())
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 8 })
      .backgroundColor(Color.White)

      // 星期标题行下方分割线
      Divider()
        .width('100%')
        .height(0.5)
        .color('#E5E5E5')

      // 月历列表
      List({ scroller: this.calendarScroller }) {
        ForEach(this.monthList, (monthData: MonthData) => {
          ListItem() {
            this.MonthCalendar(monthData)
          }
        }, (monthData: MonthData) => `${monthData.year}-${monthData.month}`)

        // 底部留白
        ListItem() {
          Column()
            .width('100%')
            .height('30%')
            .backgroundColor(Color.White)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
      .onScrollIndex((start: number, end: number) => {
        // 更新当前显示的年月
        if (start >= 0 && start < this.monthList.length) {
          const monthData = this.monthList[start]
          this.currentYear = monthData.year
          this.currentMonth = monthData.month
        }
        // 检查是否需要加载更多月份
        if (start <= 1) {
          this.loadEarlierMonths()
        }
        if (end >= this.monthList.length - 2) {
          this.loadLaterMonths()
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  // 构建搜索结果视图
  @Builder
  SearchResultView() {
    Column() {
      if ((this.viewModel?.groupedMessageList.length ?? 0) === 0 && !this.isLoading) {
        // 空状态展示
        CommonEmptyResult({
          emptyImage: $r('app.media.no_history'),
          tips: $r('app.string.team_history_record_empty_tip')
        })
          .margin({ top: 74 })
      } else {
        // 消息列表
        List({ scroller: this.listScroller }) {
          // 遍历每个日期分组
          ForEach(this.viewModel?.groupedMessageList ?? [], (group: DateGroupedMessages) => {
            // 日期标题
            ListItem() {
              Text(group.dateString)
                .fontSize(14)
                .fontColor('#333333')
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .padding({ left: 16, top: 16, bottom: 8 })
                .backgroundColor('#F5F5F5')
            }

            // 该日期下的消息
            ForEach(group.messages, (item: SearchDateMessage) => {
              ListItem() {
                DateMessageItem({
                  item: item,
                  onClickHandler: () => {
                    this.tapMessage = item
                    this.locateChat()
                  },
                  onLongClick: () => {
                    this.showMessageActionDialog(item)
                  }
                })
              }
            }, (item: SearchDateMessage) => item.message.messageClientId)
          }, (group: DateGroupedMessages) => group.dateString)

          // 首页 loading 动作
          if (this.isLoading) {
            ListItem() {
              Row() {
                Row() {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .margin({ right: 8 })
                    .color('#666666')
                  Text($r('app.string.search_message_loading'))
                    .fontSize(14)
                    .fontColor('#666666')
                }
                .height(40)
                .padding({ left: 20, right: 20 })
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#F5F5F5')
                .borderRadius(20)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ top: 10, bottom: 10 })
            }
            .backgroundColor(Color.Transparent)
          }

          // 加载更多
          if (this.viewModel?.hasMore) {
            ListItem() {
              Row() {
                Row() {
                  if (this.isLoadingMore) {
                    LoadingProgress()
                      .width(20)
                      .height(20)
                      .margin({ right: 8 })
                      .color('#666666')
                    Text($r('app.string.search_message_loading'))
                      .fontSize(14)
                      .fontColor('#666666')
                  } else {
                    Text($r('app.string.search_message_load_more'))
                      .fontSize(14)
                      .fontColor('#666666')
                  }
                }
                .height(40)
                .padding({ left: 20, right: 20 })
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#F5F5F5')
                .borderRadius(20)
                .onClick(() => {
                  if (!this.isLoadingMore) {
                    this.loadMoreMessages()
                  }
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ top: 10, bottom: 10 })
            }
            .backgroundColor(Color.Transparent)
          } else if ((this.viewModel?.groupedMessageList?.length ?? 0) > 0) {
            // 没有更多数据时显示提示
            ListItem() {
              Row() {
                Text($r('app.string.chat_message_no_more_data'))
                  .fontSize(14)
                  .fontColor('#999999')
              }
              .width('100%')
              .height(50)
              .justifyContent(FlexAlign.Center)
            }
            .backgroundColor(Color.Transparent)
          }

          // 底部安全区留白
          ListItem() {
            Column()
              .width('100%')
              .height('30%')
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F5F5F5')
        .onReachEnd(() => {
          // 滚动到底部时自动加载更多
          if (this.viewModel?.hasMore && !this.isLoadingMore) {
            this.loadMoreMessages()
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          // 导航栏
          Row() {
            // 返回按钮
            Image($r('app.media.ic_public_back'))
              .width(24)
              .height(24)
              .margin({ left: 16 })
              .onClick(() => {
                if (this.showSearchResult) {
                  this.backToDateSelect()
                } else {
                  this.pathStack.pop()
                }
              })

            // 标题
            Text($r('app.string.search_by_date_title'))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            // 完成按钮（仅在日期选择视图显示）
            if (!this.showSearchResult) {
              Text($r('app.string.search_date_confirm'))
                .fontSize(16)
                .fontColor(this.hasDateSelected() ? '#337EFF' : '#CCCCCC')
                .margin({ right: 16 })
                .onClick(() => {
                  if (this.hasDateSelected()) {
                    this.onConfirmClick()
                  }
                })
            } else {
              Text('')
                .width(48)
                .margin({ right: 16 })
            }
          }
          .width('100%')
          .height(56)
          .backgroundColor(Color.White)

          // 主内容区域
          if (this.showSearchResult) {
            this.SearchResultView()
          } else {
            this.DateSelectView()
          }
        }
        .width('100%')
        .height('100%')

      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor('#F5F5F5')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      this.initData()
    })
  }

  @Monitor("viewModel.revokeAndeDeleteMission")
  onRevokeAndeDeleteMissionChanged() {
    this.viewModel?.resetRevokeAndeDeleteMission()
  }
}
