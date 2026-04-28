# Android 消息置顶功能调研文档

> 调研日期: 2026-03-25
> 调研工程: ~/code/xkit-android/
> 目标: 为鸿蒙端 (HarmonyOS) 实现消息置顶功能提供技术参考

---

## 一、功能概述

消息置顶（Top Sticky Message）允许群聊中**有权限的成员**将某条消息"置顶"到聊天页面顶部，所有群成员打开聊天页面后可以看到一条横幅，显示被置顶消息的摘要。

### 核心特性

| 特性 | 说明 |
|------|------|
| 作用域 | **仅群聊**（Team），P2P 单聊不支持 |
| 置顶数量 | 每个群同时只有 **1 条** 置顶消息 |
| 存储方式 | 写入群的 `serverExtension` JSON 字段 |
| 权限控制 | 通过 `serverExtension.yxAllowTop` 控制谁可以操作 |
| 全局开关 | 受 `IMKitConfigCenter.enableTopMessage` 控制 |
| 操作入口 | 消息长按弹出菜单中的「置顶」/「取消置顶」 |
| 通知能力 | 群内发送系统通知提示「置顶了一条消息」/「移除了置顶消息」 |

---

## 二、数据结构

### 2.1 常量定义

**文件**: `chatkit/src/main/java/.../ChatConstants.kt`

```kotlin
// 置顶消息在 serverExtension 中的 KEY
const val KEY_EXTENSION_STICKY = "yxMessageTop"

// 置顶消息权限在 serverExtension 中的 KEY
const val KEY_EXTENSION_STICKY_PERMISSION = "yxAllowTop"

// 最后一次操作类型
const val KEY_EXTENSION_LAST_OPT_TYPE = "lastOpt"

// 置顶消息子字段
const val KEY_STICKY_MESSAGE_CLIENT_ID = "idClient"
const val KEY_STICKY_MESSAGE_SCENE = "scene"        // 会话类型
const val KEY_STICKY_MESSAGE_FROM = "from"           // 发送者
const val KEY_STICKY_MESSAGE_TO = "to"               // conversationId
const val KEY_STICKY_MESSAGE_SERVER_ID = "idServer"
const val KEY_STICKY_MESSAGE_TIME = "time"           // 消息创建时间
const val KEY_STICKY_MESSAGE_OPERATOR = "operator"   // 操作者 accountId
const val KEY_STICKY_MESSAGE_OPERATION = "operation"  // 0=add, 1=remove
const val KEY_STICKY_MESSAGE_RECEIVER_ID = "receiverId" // 兼容 Web

// 操作类型常量
const val TYPE_EXTENSION_STICKY_ADD = 0
const val TYPE_EXTENSION_STICKY_REMOVE = 1
```

### 2.2 serverExtension JSON 结构

置顶消息后，群的 `serverExtension` 结构示例：

```json
{
  "yxAllowAt": "all",
  "yxAllowTop": "all",
  "lastOpt": "yxMessageTop",
  "yxMessageTop": {
    "idClient": "msg_client_id_xxx",
    "scene": 1,
    "from": "sender_account_id",
    "to": "team|12345|0",
    "idServer": "msg_server_id_xxx",
    "time": 1711326000000,
    "operator": "operator_account_id",
    "operation": 0,
    "receiverId": "12345"
  }
}
```

取消置顶时：
```json
{
  "yxMessageTop": {
    "idClient": "msg_client_id_xxx",
    "operator": "operator_account_id",
    "operation": 1
  },
  "lastOpt": "yxMessageTop"
}
```

### 2.3 TopStickyMessage 数据模型

**文件**: `chatkit-ui/src/main/java/.../model/TopStickyMessage.java`

```java
public class TopStickyMessage {
    String idClient;                        // 消息客户端 ID
    V2NIMConversationType conversationType; // 会话类型
    String from;                            // 发送者
    String to;                              // conversationId
    String idServer;                        // 消息服务端 ID
    long time;                              // 消息创建时间
    String operator;                        // 操作者（谁置顶的）
    int operation;                          // 0=add, 1=remove
    String receiverId;                      // 接收者（兼容 Web）
    
    // 从 JSON 反序列化
    public static TopStickyMessage fromJson(JSONObject jsonObject);
}
```

---

## 三、核心流程

### 3.1 添加置顶消息

**触发**: 用户在群聊中长按消息 → 弹出菜单 → 点击「置顶」

**流程图**:
```
ChatBaseFragment.onTopSticky(message, isAdd=true)
    ├── 1. 检查网络连接
    ├── 2. 检查置顶权限 ChatUtils.havePermissionForTopSticky()
    └── 3. ChatTeamViewModel.addStickyMessage(message)
            ├── 构建 JSON: { idClient, scene, from, to, idServer, time, operator, operation=0, receiverId }
            ├── 读取当前群 serverExtension
            ├── 写入 yxMessageTop = jsonMessage
            ├── 写入 lastOpt = "yxMessageTop"
            └── TeamRepo.updateTeamExtension(teamId, NORMAL, newExtension)
                    └── 成功后触发 teamInfoListener (群信息变更回调)
                            ├── handleTopMessage(serverExtension)
                            │    ├── 解析 yxMessageTop JSON
                            │    ├── TopStickyMessage.fromJson(json)
                            │    └── getTopStickyMessage(topStickyMessage)
                            │         ├── 构建 V2NIMMessageRefer
                            │         ├── ChatRepo.getMessageListByRefers(refers)
                            │         ├── 成功: ChatUserCache.setTopMessage(msg)
                            │         └── topMessageLiveData.postValue(msg)
                            └── UI 层收到 LiveData 更新 → 显示置顶横幅
```

### 3.2 移除置顶消息

**触发方式 1**: 长按已置顶消息 → 弹出菜单 → 点击「取消置顶」
**触发方式 2**: 点击置顶横幅右侧的关闭按钮 ✕

**流程**:
```
ChatTeamViewModel.removeStickyMessage()
    ├── 构建 JSON: { idClient, operator, operation=1 }
    ├── 写入 yxMessageTop = jsonMessage
    ├── 写入 lastOpt = "yxMessageTop"
    └── TeamRepo.updateTeamExtension(teamId, NORMAL, newExtension)
            └── 成功后触发 teamInfoListener
                    └── handleTopMessage(serverExtension)
                            ├── operation == REMOVE
                            ├── topMessageLiveData.postValue(null)
                            └── ChatUserCache.removeTopMessage()
                                    └── UI 层收到 null → 隐藏置顶横幅
```

### 3.3 进入群聊时加载置顶

**流程**:
```
ChatTeamViewModel.getTeamInfo()
    ├── TeamUserManager.getInstance().getCurrentTeam()
    └── handleTopMessage(team.serverExtension)
            ├── 解析 yxMessageTop
            ├── operation == ADD → getTopStickyMessage()
            │    ├── getMessageListByRefers → 获取完整消息
            │    ├── ChatUserCache.setTopMessage(msg)
            │    └── topMessageLiveData.postValue(msg)
            └── operation == REMOVE → topMessageLiveData.postValue(null)
```

### 3.4 群信息实时更新（其他人操作置顶）

**流程**:
```
teamInfoListener (V2NIM SDK 群变更回调)
    ├── 群信息变更 → teamLiveData.setValue(team)
    ├── handleTopMessage(team.serverExtension) → 更新置顶消息
    └── 检查 lastOpt == "yxAllowTop" → handleTopMessagePermission() → 更新权限 UI
```

---

## 四、权限控制

### 4.1 权限判断逻辑

**文件**: `chatkit-ui/src/main/java/.../ChatUtils.java`

```java
public static boolean havePermissionForTopSticky() {
    V2NIMTeam team = TeamUserManager.getInstance().getCurrentTeam();
    boolean isAllAllow = false;
    
    if (team != null && team.getServerExtension() != null) {
        String ext = team.getServerExtension();
        
        // 讨论组直接有权限
        if (ext.contains(TEAM_GROUP_TAG) || team.getTeamType() == INVALID) {
            isAllAllow = true;
        } else {
            // 高级群: 检查 yxAllowTop 值
            JSONObject json = new JSONObject(ext);
            if (json.has("yxAllowTop")) {
                isAllAllow = "all".equals(json.getString("yxAllowTop"));
            }
        }
        if (isAllAllow) return true;
    }
    
    // 非 "all" 时，仅群主和管理员有权限
    V2NIMTeamMember member = TeamUserManager.getInstance().getCurTeamMember();
    return member != null && (member.role == OWNER || member.role == MANAGER);
}
```

### 4.2 权限影响范围

| 场景 | yxAllowTop="all" | yxAllowTop="manager" 或未设置 |
|------|------------------|-------------------------------|
| 消息长按菜单显示「置顶」 | ✅ 所有人可见 | ✅ 所有人可见（权限在点击时判断） |
| 点击「置顶」执行 | ✅ 成功 | ❌ 非管理员提示无权限 |
| 置顶横幅的 ✕ 关闭按钮 | ✅ 所有人可见 | 仅群主/管理员可见 |

### 4.3 权限变更处理

当群管理页修改了 `yxAllowTop` 权限时：
1. `serverExtension` 更新，`lastOpt = "yxAllowTop"`
2. `teamInfoListener` 触发 → 检测到 `lastOpt == "yxAllowTop"`
3. 调用 `handleTopMessagePermission()` → 更新 `topMessagePermissionLiveData`
4. UI 层收到通知 → 更新关闭按钮的可见性

---

## 五、UI 层

### 5.1 置顶横幅 (Top Message Bar)

**布局文件**: `res/layout/chat_top_message_layout.xml`

```
┌─────────────────────────────────────────────────────┐
│ 📌 [缩略图] 昵称: 消息内容摘要...                  ✕ │
└─────────────────────────────────────────────────────┘
```

**布局结构**:
```
LinearLayout (40dp高, 水平, margin 12dp, 圆角背景)
├── ImageView (18dp 📌 置顶图标)
├── RelativeLayout (28dp 缩略图, 仅图片/视频消息时可见)
│   ├── ImageView (缩略图)
│   └── ImageView (视频播放图标, 仅视频时可见)
├── TextView (昵称, 12sp, #333333)
├── TextView (消息内容, 12sp, #333333, weight=1, 单行省略)
└── ImageView (18dp ✕ 关闭按钮, 权限控制可见性)
```

### 5.2 消息长按弹出菜单

**文件**: `ChatPopActionFactory.java`

```java
// 显示条件
if (IMKitConfigCenter.getEnableTopMessage()
    && message.conversationType == V2NIM_CONVERSATION_TYPE_TEAM) {
    actions.add(getTopStickyAction(context, message));
}
```

**菜单项逻辑**:
- 当前消息 == 已置顶消息 → 显示「取消置顶」 + untop 图标
- 当前消息 != 已置顶消息（或无置顶） → 显示「置顶」 + top 图标
- 判断依据: `ChatUserCache.getInstance().getTopMessage()` 与当前消息比较

### 5.3 置顶横幅交互

| 操作 | 行为 |
|------|------|
| 点击横幅 | 滚动到被置顶的消息位置 `scrollToMessage(topMessage)` |
| 点击 ✕ 按钮 | 调用 `removeStickyMessage()` 移除置顶 |
| ✕ 按钮可见性 | 受 `havePermissionForTopSticky()` 控制 |

### 5.4 群通知消息文案

| 操作 | 文案 |
|------|------|
| 添加置顶 | `"{操作者} 置顶了一条消息"` |
| 移除置顶 | `"{操作者} 移除了置顶消息"` |
| 权限改为所有人 | `"置顶消息权限更新为所有人"` |
| 权限改为管理员 | `"置顶消息权限更新为群主和管理员"` |

---

## 六、关键类一览

| 类 | 模块 | 职责 |
|----|------|------|
| `ChatConstants.kt` | chatkit | 所有置顶相关常量定义 |
| `TopStickyMessage.java` | chatkit-ui | 置顶消息数据模型（JSON ↔ Object） |
| `ChatTeamViewModel.java` | chatkit-ui | 核心逻辑：添加/移除置顶、解析群扩展、获取消息详情 |
| `ChatBaseFragment.java` | chatkit-ui | UI 层：置顶横幅展示、长按菜单回调、滚动定位 |
| `ChatPopActionFactory.java` | chatkit-ui | 构建长按弹出菜单中的「置顶/取消置顶」选项 |
| `ChatUtils.java` | chatkit-ui | `havePermissionForTopSticky()` 权限判断 |
| `ChatUserCache.java` | chatkit-ui | 缓存当前置顶消息（内存级） |
| `TeamNotificationHelper.java` | chatkit-ui | 解析群通知，生成置顶/取消置顶文案 |
| `BaseTeamManagerActivity.java` | teamkit-ui | 群管理页的置顶权限设置 UI |
| `TeamManagerViewModel.java` | teamkit-ui | 更新群扩展中的 `yxAllowTop` 权限值 |

---

## 七、鸿蒙端实现建议

### 7.1 已完成部分

- ✅ `keyExtensionTopSticky = "yxAllowTop"` 常量（已在 `align-team-manage-features` 中添加）
- ✅ `getTopStickyPermission()` 方法（已在 `TeamManageViewModel` 中实现）
- ✅ 群管理页「消息置顶权限」UI + Dialog（已实现）

### 7.2 待实现部分

| 优先级 | 功能 | 对应 Android 类 | 建议鸿蒙实现位置 |
|--------|------|----------------|-----------------|
| P0 | TopStickyMessage 数据模型 | `TopStickyMessage.java` | `chatkit/src/main/ets/model/TopStickyMessage.ets` |
| P0 | 添加/移除置顶消息逻辑 | `ChatTeamViewModel.addStickyMessage / removeStickyMessage` | `chatkit_ui/.../viewModel/ChatTeamViewModel.ets` 或现有群聊 ViewModel |
| P0 | 置顶横幅 UI | `chat_top_message_layout.xml` | `chatkit_ui/.../view/TopMessageBar.ets` (自定义组件) |
| P0 | 长按菜单「置顶/取消置顶」选项 | `ChatPopActionFactory.getTopStickyAction` | 消息长按弹出菜单配置 |
| P1 | 权限判断 `havePermissionForTopSticky()` | `ChatUtils.java` | `chatkit_ui/.../helper/ChatUtils.ets` |
| P1 | 置顶消息缓存 | `ChatUserCache.topMessage` | 群聊 ViewModel 中用 `@Trace` 响应式变量 |
| P1 | 群信息变更监听 → 实时更新置顶 | `teamInfoListener` | SDK 回调 → ViewModel 更新 |
| P2 | 群通知文案（置顶/取消置顶） | `TeamNotificationHelper` | 群通知解析逻辑 |
| P2 | 点击横幅滚动到消息 | `scrollToMessage(topMessage)` | `ChatView` 中 `List.scrollTo` |

### 7.3 核心常量映射 (Android → 鸿蒙)

```typescript
// chatkit/Constant.ets 需要新增
export let keyExtensionSticky = "yxMessageTop"                // KEY_EXTENSION_STICKY
// export let keyExtensionTopSticky = "yxAllowTop"            // 已有
export let keyStickyMessageClientId = "idClient"
export let keyStickyMessageScene = "scene"
export let keyStickyMessageFrom = "from"
export let keyStickyMessageTo = "to"
export let keyStickyMessageServerId = "idServer"
export let keyStickyMessageTime = "time"
export let keyStickyMessageOperator = "operator"
export let keyStickyMessageOperation = "operation"
export let keyStickyMessageReceiverId = "receiverId"
export let typeExtensionStickyAdd = 0
export let typeExtensionStickyRemove = 1
```

### 7.4 关键技术点

1. **存储机制**: 置顶消息信息存在群的 `serverExtension` 中，不依赖额外服务端接口。通过 `TeamRepo.updateTeamInfo(serverExtension)` 写入，通过群信息变更回调被动接收。

2. **消息获取**: `serverExtension` 中只存了消息引用（clientId/serverId），需要通过 `getMessageListByRefers` API 获取完整消息内容用于展示。

3. **权限判断**:
   - `yxAllowTop = "all"` → 所有人可操作
   - `yxAllowTop = "manager"` 或未设置 → 仅群主和管理员可操作
   - 讨论组（非高级群）→ 默认所有人可操作

4. **缓存策略**: Android 使用 `ChatUserCache` 内存缓存当前置顶消息。鸿蒙端建议在群聊 ViewModel 中用 `@Trace topMessage?: IMMessageInfo` 实现响应式缓存。

5. **UI 状态联动**: 置顶横幅的 ✕ 按钮可见性需要同时响应:
   - 置顶权限变更 (`topMessagePermissionLiveData`)
   - 群成员角色变更 (`updateMyTeamMember`)

6. **跨平台兼容**: `receiverId` 字段是为了兼容 Web 端。鸿蒙端构建 JSON 时也应包含此字段。
