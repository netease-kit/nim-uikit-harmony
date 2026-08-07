# Android 消息已读未读开关功能调研文档

> 调研日期: 2026-03-25
> 调研工程: ~/code/xkit-android/
> 目标: 为鸿蒙端 (HarmonyOS) 实现消息已读未读开关功能提供技术参考

---

## 一、功能概述

「消息已读未读」开关控制聊天页面是否显示消息的已读/未读状态。该开关同时影响：
1. **发送时**：消息的 `readReceiptEnabled` 配置（是否请求已读回执）
2. **展示时**：消息气泡旁的已读/未读状态图标是否显示

### 核心特性

| 特性 | 说明 |
|------|------|
| 作用域 | P2P 单聊 + 群聊均支持 |
| 控制维度 | 全局开关（设置页 Toggle），不区分单个会话 |
| 持久化 | SharePreference（通过 `ConfigProvider`） |
| 运行时存储 | `ChatConfigManager.showReadStatus` 静态变量 |
| 默认值 | `true`（默认显示已读未读） |

---

## 二、架构设计

### 2.1 数据流

```
┌─────────────────┐
│  SettingActivity │  用户切换 Toggle
└────────┬────────┘
         │ setChecked
         ▼
┌─────────────────┐         ┌──────────────────────┐
│  SettingViewModel│────────▶│  SettingRepo          │
│                  │ set     │  (SharePreference)    │
└────────┬────────┘         └──────────────────────┘
         │
         ▼  同步写入
┌──────────────────────┐
│  ChatConfigManager   │
│  .showReadStatus     │  运行时内存标志
└──────┬───────────────┘
       │
       ├──────────────────────────┐
       ▼                          ▼
┌──────────────┐         ┌────────────────────┐
│ 发送消息时    │         │ 显示消息时          │
│ MessageCreator│         │ ChatBaseMessage     │
│ readReceipt   │         │ ViewHolder          │
│ Enabled=show  │         │ showReadStatus?     │
└──────────────┘         └────────────────────┘
```

### 2.2 关键类

| 类 | 模块 | 职责 |
|----|------|------|
| `ChatConfigManager` | chatkit-ui | **运行时标志**: `showReadStatus` 静态变量 |
| `SettingRepo` | chatkit | **持久化层**: `getShowReadStatus()` / `setShowReadStatus()` |
| `ConfigProvider` | corekit-im | **底层存储**: 读写 SharePreference |
| `SettingActivity` | imkit-sample | **设置页 UI**: Toggle 控制 + 启动时读取 |
| `SettingViewModel` | imkit-sample | **中间层**: 连接 UI 和 SettingRepo |
| `MessageCreator` | chatkit-ui | **发送时**: `configBuilder.withReadReceiptEnabled(showRead)` |
| `ChatBaseMessageViewHolder` | chatkit-ui | **显示时**: 根据 `showReadStatus` 决定是否显示状态图标 |

---

## 三、开关对消息发送的影响

### 3.1 MessageCreator.sendMessage

```java
// chatkit-ui/common/MessageCreator.java
public static void sendMessage(V2NIMMessage message, ..., boolean showRead) {
    V2NIMMessageConfig.V2NIMMessageConfigBuilder configBuilder =
        V2NIMMessageConfig.V2NIMMessageConfigBuilder.builder();
    // 关键：根据开关设置是否请求已读回执
    configBuilder.withReadReceiptEnabled(showRead);
    // ...
}
```

**影响**：
- `showRead = true` → 消息的 `messageConfig.readReceiptEnabled = true` → SDK 会自动收集已读回执
- `showRead = false` → 消息不请求已读回执 → 即使对方读了也不会收到回执

### 3.2 转发消息时同步开关状态

```java
// chatkit-ui/common/MessageHelper.java
public static void forwardMessageImpl(
    V2NIMMessage message, String conversationId, 
    boolean showToasts, boolean readReceiptEnabled) {
    configBuilder.withReadReceiptEnabled(readReceiptEnabled);
}
```

转发消息时也会根据当前开关状态设置已读回执。

---

## 四、开关对消息展示的影响

### 4.1 P2P 单聊

```java
// ChatBaseMessageViewHolder.java (line ~719)
if (!properties.getShowP2PMessageStatus() || !ChatConfigManager.showReadStatus) {
    // 隐藏已读/未读图标
    baseViewBinding.ivStatus.setVisibility(View.GONE);
} else {
    // 显示已读/未读图标
    baseViewBinding.ivStatus.setVisibility(View.VISIBLE);
    if (isPeerRead(message)) {
        ivStatus.setImageResource(R.drawable.ic_message_read);    // 已读 ✓✓
    } else {
        ivStatus.setImageResource(R.drawable.ic_message_unread);  // 未读 ✓
    }
}
```

### 4.2 群聊

```java
// ChatBaseMessageViewHolder.java (line ~752)
if (!properties.getShowTeamMessageStatus()
    || !message.getMessageConfig().isReadReceiptEnabled()
    || !ChatConfigManager.showReadStatus) {
    // 隐藏已读进度
    baseViewBinding.readProcess.setVisibility(View.GONE);
    return;
}
// 显示已读进度条（如 "3/10 已读"）
```

群聊的已读进度还有一个 **人数上限** 控制（`maxReadingNum`，默认 100）：超过此人数的群不展示已读进度。

### 4.3 MessageProperties 细粒度控制

```java
// ChatUIConfig.messageProperties
showP2PMessageStatus  // 单独控制 P2P 消息已读状态显示
showTeamMessageStatus // 单独控制群聊消息已读状态显示
```

这两个属性可以让开发者在全局 `showReadStatus` 之外，对 P2P 和群聊分别控制。

---

## 五、设置页实现

### 5.1 SettingActivity（设置页）

```java
// imkit-sample/setting/SettingActivity.java
private void initView() {
    // 启动时读取持久化值
    viewBinding.messageReadSc.setChecked(viewModel.getShowReadStatus());
    
    viewBinding.messageReadSc.setOnClickListener(v -> {
        boolean checked = viewBinding.messageReadSc.isChecked();
        // 持久化
        viewModel.setShowReadStatus(checked);
        // 同步到运行时标志
        ChatConfigManager.showReadStatus = checked;
    });
}
```

### 5.2 SettingViewModel

```java
public boolean getShowReadStatus() {
    return SettingRepo.getShowReadStatus();  // 读取 SharePreference
}

public void setShowReadStatus(boolean show) {
    SettingRepo.setShowReadStatus(show);     // 写入 SharePreference
}
```

### 5.3 SettingRepo（持久化）

```kotlin
object SettingRepo {
    @Deprecated("use IMKitConfigCenter.enableMessageReadReceipt instead")
    fun getShowReadStatus(): Boolean {
        return ConfigProvider.getShowReadStatus()  // SharePreference
    }
    
    fun setShowReadStatus(show: Boolean) {
        ConfigProvider.updateShowReadStatus(show)
    }
}
```

> 注意：`SettingRepo` 中已标记 `@Deprecated`，建议使用 `IMKitConfigCenter.enableMessageReadReceipt`。说明 Android 端也在向统一配置中心迁移。

---

## 六、已读回执发送逻辑

### 6.1 P2P 已读回执

```java
// ChatP2PViewModel.java
// 用户滑动消息列表 → 对可见消息发送已读回执
ChatRepo.markP2PMessageRead(message, null);
```

### 6.2 群聊已读回执

```java
// ChatTeamViewModel.java (line ~232)
if (message.isSelf()                              // 自己发的
    && message.getMessageConfig().isReadReceiptEnabled()  // 开启了已读回执
    && !message.getMessageStatus().getReadReceiptSent()) {  // 还没发过回执
    // 发送群消息已读回执
    ChatRepo.markTeamMessageRead(message);
}
```

### 6.3 已读回执回调

```java
// ChatBaseViewModel.java
messageListener = new MessageObserverImpl() {
    @Override
    public void onReceiveP2PMessageReadReceipts(List<V2NIMP2PMessageReadReceipt> readReceipts) {
        onP2PMessageReadReceipts(readReceipts);  // 更新 UI
    }
    
    @Override
    public void onReceiveTeamMessageReadReceipts(List<V2NIMTeamMessageReadReceipt> readReceipts) {
        onTeamMessageReadReceipts(readReceipts);  // 更新进度
    }
};
```

---

## 七、鸿蒙端对比与实现建议

### 7.1 当前鸿蒙端现状

| 功能 | Android | 鸿蒙 | 差距 |
|------|---------|------|------|
| 全局设置页开关 | ✅ SettingActivity Toggle | ❌ 缺失 | 需新增 |
| 运行时标志 | ✅ `ChatConfigManager.showReadStatus` | ❌ 缺失 | 需新增 |
| 持久化 | ✅ SharePreference | ❌ 缺失 | 需新增 |
| 发送时设置 readReceiptEnabled | ✅ MessageCreator | ❓ 需确认 | 可能已有 |
| P2P 已读/未读状态图标 | ✅ ViewHolder | ❓ 需确认 | 可能已有 |
| 群聊已读进度条 | ✅ ViewHolder | ❓ 需确认 | 可能已有 |
| 已读回执发送/接收 | ✅ ViewModel | ❓ 需确认 | 可能已有 |

### 7.2 实现方案

```
方案：在 IMKitConfigCenter 中新增 enableReadMessage 开关

IMKitConfigCenter
├── enableReadMessage: boolean = true  （新增）
│
├── 影响发送: 构建消息时 readReceiptEnabled = enableReadMessage
├── 影响展示: 消息气泡状态图标 visible = enableReadMessage
└── 影响回执: 是否主动发送已读回执 = enableReadMessage

GlobalConfigPage
└── 新增 Toggle "消息已读未读功能"
    ├── 持久化到 dataPreferences
    └── 同步到 IMKitConfigCenter.enableReadMessage
```

### 7.3 需要修改的文件（预估）

| 文件 | 修改 |
|------|------|
| `chatkit/IMKitConfigCenter.ets` | 新增 `enableReadMessage: boolean = true` |
| `imkit_sample/GlobalConfigPage.ets` | 新增 Toggle + 持久化 |
| `chatkit_ui/viewmodel/ChatBaseViewModel.ets` | 发送消息时根据开关设置 readReceiptEnabled |
| `chatkit_ui/view/MessageComponent.ets` | 展示消息时根据开关控制状态图标可见性 |
| `chatkit_ui/viewmodel/ChatP2PViewModel.ets` | P2P 已读回执发送受开关控制 |
| `chatkit_ui/viewmodel/ChatTeamViewModel.ets` | 群聊已读回执发送受开关控制 |
| string.json × 3 | 新增文案 |

### 7.4 关键注意点

1. **双重控制**: Android 有 `ChatConfigManager.showReadStatus`（全局静态）和 `messageConfig.readReceiptEnabled`（单消息级别）两层。鸿蒙端建议统一用 `IMKitConfigCenter.enableReadMessage`。

2. **发送 vs 展示分离**: 开关影响两个独立的行为——发送时是否请求回执，展示时是否显示状态。两者应同步控制。

3. **已发送消息不受影响**: 关闭开关后，已经发送且 `readReceiptEnabled = true` 的消息仍然会收到回执，只是 UI 不展示。

4. **群聊人数限制**: Android 有 `maxReadingNum` 控制超大群不展示已读进度，鸿蒙端也应考虑。

5. **持久化同步**: 和 `enableTeamJoinAgreeModelAuth` 一样，需要在 `aboutToAppear` 中同步到 `IMKitConfigCenter`，避免重启后开关状态丢失。
