# Android 群禁言 & 群管理功能调研

> 调研对象：`~/code/xkit-android/imkit/teamkit-ui`
> 目标：为鸿蒙端 `nimkit/teamkit_ui` 群设置功能提供实现参考

---

## 1. 功能概览

Android 端的群设置页面（`BaseTeamSettingActivity`）中，**群禁言** 和 **群管理** 是两个独立但关联的功能模块。

### 功能矩阵

| 功能 | 群主可见 | 管理员可见 | 普通成员可见 | 讨论组可见 |
|------|---------|-----------|------------|-----------|
| **群禁言开关** (teamMute) | ✅ | ❌ | ❌ | ❌ |
| **群管理入口** (teamManager) | ✅ | ✅ | ❌ | ❌ |

```
┌────────────────────────────────────────────────────────────┐
│  群设置页 (TeamSettingPage)                                 │
├────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐  │
│  │  群信息 / 群成员列表 / 基础设置                        │  │
│  │  (消息通知 / 置顶 / 群昵称)                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  🔇 群禁言         [Toggle]    ← 仅群主可见           │  │
│  │  ──────────────────────────                          │  │
│  │  ⚙️  群管理          ▶          ← 群主+管理员可见      │  │
│  └──────────────────────────────────────────────────────┘  │
│                        ↓ 点击群管理                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  群管理页 (TeamManagePage)                             │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │  管理员管理  N人     ▶   ← 仅群主可见          │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │  编辑群信息权限    所有人/管理员  ▶             │    │  │
│  │  │  @所有人权限      所有人/管理员  ▶             │    │  │
│  │  │  邀请他人权限     所有人/管理员  ▶             │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │  申请入群是否需要审批     [Toggle]              │    │  │
│  │  │  被邀请人是否需要同意     [Toggle]              │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
│                        ↓ 点击管理员管理                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  管理员列表页 (TeamManagerListPage)                    │  │
│  │  [+ 添加管理员]  ← 仅群主可见                         │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │  管理员A    [移除]  ← 仅群主可见               │    │  │
│  │  │  管理员B    [移除]                             │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

---

## 2. 群禁言（Team Chat Banned / Team Mute）

### 2.1 UI 位置与权限

- **位置**: 群设置页 → 第三组（仅高级群，非讨论组）
- **可见性**: 仅**群主** (`V2NIM_TEAM_MEMBER_ROLE_OWNER`) 可见
- **控件**: `SwitchCompat` (Toggle 开关)

### 2.2 Android 实现分析

#### UI 层 (`BaseTeamSettingActivity.java`)

```java
// 讨论组隐藏禁言
private void initForNormal() {
    teamMuteGroup.setVisibility(View.GONE);  // 讨论组不显示禁言
}

// 群主UI
private void initForOwner() {
    teamMuteGroup.setVisibility(View.VISIBLE);  // 群主可见
    swTeamMute.setOnClickListener(
        v -> settingViewModel.muteTeamAllMember(teamId, swTeamMute.isChecked()));
}

// 管理员UI
private void initForManager() {
    teamMuteGroup.setVisibility(View.GONE);  // 管理员不可见
}

// 普通成员UI
private void initForAllUser() {
    teamMuteGroup.setVisibility(View.GONE);  // 普通成员不可见
}
```

#### 状态读取

```java
// 初始化时读取群信息中的禁言状态
swTeamMute.setChecked(
    teamInfo.getChatBannedMode() != V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_UNBAN
);
```

#### ViewModel 层 (`TeamSettingViewModel.java`)

```java
public void muteTeamAllMember(String teamId, boolean mute) {
    V2NIMTeamChatBannedMode bannedMode = mute
        ? V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_NORMAL
        : V2NIMTeamChatBannedMode.V2NIM_TEAM_CHAT_BANNED_MODE_UNBAN;
    TeamRepo.setTeamChatBannedMode(teamId, V2NIMTeamType.V2NIM_TEAM_TYPE_NORMAL, bannedMode, ...);
}
```

#### Repo 层 (`TeamRepo.kt`)

```kotlin
fun setTeamChatBannedMode(
    teamId: String,
    teamType: V2NIMTeamType,
    bannedMode: V2NIMTeamChatBannedMode,
    callback: FetchCallback<Void>?
) {
    TeamProvider.setTeamChatBannedMode(teamId, teamType, bannedMode, callback)
}
```

### 2.3 禁言模式枚举

```
V2NIMTeamChatBannedMode:
├── V2NIM_TEAM_CHAT_BANNED_MODE_UNBAN          = 0  // 不禁言
├── V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_NORMAL  = 1  // 禁言普通成员（群主+管理员可发言）
└── V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_ALL     = 3  // 全员禁言（仅群主可发言）
```

Android 端仅使用了 `UNBAN` 和 `BANNED_NORMAL` 两种模式（Toggle 开关只切换这两个值）。

### 2.4 错误处理

```java
// 禁言请求失败时回滚开关状态
settingViewModel.getMuteTeamAllMemberData().observeForever(booleanResultInfo -> {
    if (booleanResultInfo.isSuccess()) {
        return;
    }
    handleNetworkBrokenResult(this, booleanResultInfo);
    swTeamMute.toggle();  // 失败时回滚
});
```

---

## 3. 群管理（Team Manager）

### 3.1 页面结构

群管理涉及 **3 个页面**：

| 页面 | Android 类 | 功能 |
|------|-----------|------|
| 群管理页 | `BaseTeamManagerActivity` | 权限设置（编辑/邀请/@所有人）+ 管理员列表入口 |
| 管理员列表页 | `BaseTeamManagerListActivity` | 展示管理员列表，添加/删除管理员 |
| 成员选择页 | 跳转到联系人选择器 | 选择要添加为管理员的群成员 |

### 3.2 群管理页内容 (`BaseTeamManagerActivity`)

| 项目 | 类型 | 可见性 | 功能 |
|------|------|--------|------|
| 管理员管理 N人 | 导航行 | 仅群主 | 跳转到管理员列表页 |
| 编辑群信息权限 | 选择行 | 群主+管理员 | 所有人 / 管理员 |
| @所有人权限 | 选择行 | 受 `enableAtMessage` 控制 | 所有人 / 管理员 |
| 邀请他人权限 | 选择行 | 群主+管理员 | 所有人 / 管理员 |
| 消息置顶权限 | 选择行 | 受 `enableTopMessage` 控制 | 所有人 / 管理员 |
| 申请入群审批 | Toggle | 受 `enableTeamJoinAgreeModelAuth` 控制 | JoinMode |
| 被邀请人同意 | Toggle | 受 `enableTeamJoinAgreeModelAuth` 控制 | AgreeMode |

### 3.3 管理员列表页 (`BaseTeamManagerListActivity`)

#### 核心功能

1. **展示管理员列表**: 过滤角色为 `V2NIM_TEAM_MEMBER_ROLE_MANAGER` 的成员
2. **添加管理员**: 仅群主可见「添加」按钮，跳转到成员选择页
3. **删除管理员**: 仅群主可见「删除」标记，点击弹出确认对话框

#### ViewModel 层 (`TeamManagerListViewModel`)

```
requestTeamManagers(teamId)  → 获取管理员列表
addManager(teamId, accounts) → 添加管理员
removeManager(teamId, accounts) → 移除管理员
```

### 3.4 管理员数量限制

Android 端通过 `IMKitConfigCenter.getTeamManagerMaxCount()` 控制管理员数量上限：

- 默认值：10
- -1 表示无限制
- 在全局配置页可修改

---

## 4. 鸿蒙端现状对比

### 4.1 已实现功能

| 功能 | Android | 鸿蒙 | 差异 |
|------|---------|------|------|
| 群禁言开关 | ✅ | ✅ | **基本对齐** — 群主可见，Toggle 切换 |
| 群管理入口 | ✅ 群主+管理员 | ✅ 群主+管理员 | **已对齐** |
| 管理员管理 | ✅ 添加/删除/列表 | ✅ 添加/删除/列表 | **已对齐** |
| 编辑群信息权限 | ✅ | ✅ | **已对齐** |
| @所有人权限 | ✅ | ✅ | **已对齐** |
| 邀请他人权限 | ✅ | ✅ | **已对齐** |
| 消息置顶权限 | ✅ 受 enableTopMessage 控制 | ❌ 未实现 | **需新增** |
| 申请入群/同意审批 | ✅ 受 enableTeamJoinAgreeModelAuth 控制 | ✅ | **已对齐** |

### 4.2 差距分析

#### 差距 1：缺少「消息置顶权限」设置项

Android `BaseTeamManagerActivity` 中有「消息置顶权限」（`viewTopSticky`），受 `IMKitConfigCenter.getEnableTopMessage()` 控制。鸿蒙端 `TeamManagePage` 未实现。

**Android 实现参考**:
```java
// 可见性控制
if (!IMKitConfigCenter.getEnableTopMessage()) {
    viewTopSticky.setVisibility(View.GONE);
} else {
    viewTopSticky.setVisibility(View.VISIBLE);
}

// 权限选择（所有人 / 仅管理员）
viewTopSticky.setOnClickListener(v ->
    getTeamIdentifyDialog().show(type -> {
        viewModel.updateTopStickyPrivilege(teamInfo,
            type == TYPE_TEAM_ALL_MEMBER ? TYPE_EXTENSION_ALLOW_ALL : TYPE_EXTENSION_ALLOW_MANAGER);
    }));
```

#### 差距 2：禁言状态失败回滚

Android 端禁言请求失败时会自动回滚 Toggle 状态（`swTeamMute.toggle()`）。鸿蒙端需确认是否有相同的错误处理。

---

## 5. NIM SDK API 参考

### 5.1 群禁言 API

```typescript
// 设置群禁言模式
TeamRepo.setTeamChatBannedMode(
    teamId: string,
    teamType: V2NIMTeamType,
    bannedMode: V2NIMTeamChatBannedMode
): Promise<void>

// 禁言模式枚举
V2NIMTeamChatBannedMode:
  V2NIM_TEAM_CHAT_BANNED_MODE_UNBAN          // 解除禁言
  V2NIM_TEAM_CHAT_BANNED_MODE_BANNED_NORMAL  // 禁言普通成员
```

### 5.2 管理员管理 API

```typescript
// 添加管理员
TeamRepo.addTeamManagers(teamId, teamType, accounts): Promise<void>

// 移除管理员
TeamRepo.removeTeamManagers(teamId, teamType, accounts): Promise<void>

// 获取群成员列表（过滤角色）
TeamRepo.getTeamMemberListWithUserInfo(teamId): Promise<TeamMemberListResult>
```

### 5.3 群权限更新 API

```typescript
// 更新群信息（含权限字段）
TeamRepo.updateTeamInfo(teamId, teamType, params: V2NIMUpdateTeamInfoParams): Promise<void>

// V2NIMUpdateTeamInfoParams 中的权限字段:
{
    inviteMode?: V2NIMTeamInviteMode,      // 邀请权限
    updateInfoMode?: V2NIMTeamUpdateInfoMode, // 编辑权限
    joinMode?: V2NIMTeamJoinMode,          // 入群模式
    agreeMode?: V2NIMTeamAgreeMode,        // 同意模式
    serverExtension?: string               // 扩展字段（含 @权限、置顶权限）
}
```

---

## 6. 数据流架构

```
┌─────────────────────────────────────────────────────────────────┐
│  UI Layer (TeamSettingPage / TeamManagePage / TeamManagerListPage)│
│  ┌──────────────────┐ ┌──────────────────┐ ┌─────────────────┐ │
│  │ Toggle/开关       │ │ 权限选择弹窗     │ │ 成员列表        │ │
│  └────────┬─────────┘ └────────┬─────────┘ └────────┬────────┘ │
├───────────┼────────────────────┼────────────────────┼──────────┤
│  ViewModel Layer                                               │
│  ┌────────▼──────────────────────────────────────────▼────────┐│
│  │ TeamSettingViewModel / TeamManageViewModel                  ││
│  │ - bannedTeam(isOn)           → setTeamChatBannedMode       ││
│  │ - updateInvitePrivilege()    → updateTeamInfo(inviteMode)  ││
│  │ - updateInfoPrivilege()      → updateTeamInfo(updateInfoMode)│
│  │ - addManager(accounts)       → addTeamManagers             ││
│  │ - removeManager(accounts)    → removeTeamManagers          ││
│  └────────┬───────────────────────────────────────────────────┘│
├───────────┼────────────────────────────────────────────────────┤
│  Repo Layer (TeamRepo)                                         │
│  ┌────────▼───────────────────────────────────────────────────┐│
│  │ setTeamChatBannedMode() / updateTeamInfo()                  ││
│  │ addTeamManagers() / removeTeamManagers()                    ││
│  └────────┬───────────────────────────────────────────────────┘│
├───────────┼────────────────────────────────────────────────────┤
│  NIM SDK                                                       │
│  ┌────────▼───────────────────────────────────────────────────┐│
│  │ V2NIMTeamService                                            ││
│  └────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. 鸿蒙端实现建议

### 7.1 需要补齐的功能

| 优先级 | 功能 | 实现位置 | 工作量 |
|--------|------|---------|--------|
| **P1** | 群管理页新增「消息置顶权限」 | `TeamManagePage.ets` | 小 — 复用 @所有人权限的 Dialog 模式 |
| **P2** | 禁言请求失败回滚 | `TeamSettingPage.ets` | 小 — bannedTeam 方法 catch 后回滚 |

### 7.2 消息置顶权限实现方案

在 `TeamManagePage.ets` 的权限设置区域，新增「消息置顶权限」行：

```
┌──────────────────────────────────────────────────┐
│  编辑群信息权限     所有人/管理员     ▶           │
│  ────────────────────────────────                │
│  @所有人权限       所有人/管理员     ▶           │
│  ────────────────────────────────                │
│  邀请他人权限      所有人/管理员     ▶           │
│  ────────────────────────────────                │
│  消息置顶权限      所有人/管理员     ▶  ← 新增   │
└──────────────────────────────────────────────────┘
```

- 受 `IMKitConfigCenter.enableTopMessage` 控制可见性
- 存储在 `serverExtension` 的自定义 key 中（需调研具体 key 名称）
- 权限选择弹窗复用现有 `CommonChooseDialog`

### 7.3 禁言失败回滚

当前鸿蒙端 `TeamSettingPage` 中禁言调用：
```typescript
this.teamViewModel?.bannedTeam(!isOn)
```
需要在 catch 中回滚 UI 状态（参照 Android 的 `swTeamMute.toggle()`）。

---

## 8. 附录：Android 关键文件索引

| 文件 | 路径 | 功能 |
|------|------|------|
| `BaseTeamSettingActivity.java` | `teamkit-ui/.../activity/` | 群设置页基类（含禁言+管理入口） |
| `TeamSettingViewModel.java` | `teamkit-ui/.../viewmodel/` | 群设置 VM（禁言/通知/置顶） |
| `BaseTeamManagerActivity.java` | `teamkit-ui/.../activity/` | 群管理页基类（权限设置） |
| `TeamManagerViewModel.java` | `teamkit-ui/.../viewmodel/` | 群管理 VM（权限更新） |
| `BaseTeamManagerListActivity.java` | `teamkit-ui/.../activity/` | 管理员列表页（添加/删除管理员） |
| `TeamManagerListViewModel.java` | `teamkit-ui/.../viewmodel/` | 管理员列表 VM |
| `TeamRepo.kt` | `chatkit/.../repo/` | Repo 层（setTeamChatBannedMode） |
| `TeamProvider.kt` | `corekit-im/.../provider/` | 底层 Provider（调 NIM SDK） |

| 鸿蒙文件 | 路径 | 对标 Android |
|----------|------|-------------|
| `TeamSettingPage.ets` | `teamkit_ui/.../pages/` | BaseTeamSettingActivity |
| `TeamManagePage.ets` | `teamkit_ui/.../pages/` | BaseTeamManagerActivity |
| `TeamManagerListPage.ets` | `teamkit_ui/.../pages/` | BaseTeamManagerListActivity |
| `TeamViewModel.ets` | `teamkit_ui/.../viewModel/` | TeamSettingViewModel |
| `TeamManageViewModel.ets` | `teamkit_ui/.../viewModel/` | TeamManagerViewModel |
| `TeamManagerListViewModel.ets` | `teamkit_ui/.../viewModel/` | TeamManagerListViewModel |
