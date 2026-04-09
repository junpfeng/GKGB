# 离线激活系统设计方案

## 1. 背景

应用需要安装保护机制，但无服务器可用。采用 **Ed25519 挑战-应答** 方案：App 首次启动显示机器码，开发者用私钥工具生成带有效期的激活码，用户输入后离线验证。公钥内嵌于 App，即使被反编译也无法伪造激活码。

## 2. 威胁模型与安全边界

**防护目标**: 阻止未授权用户使用 App，防止激活码在设备间共享。

**可防御的威胁:**
- 普通用户直接复制安装包给他人使用
- 激活码在设备间转移（设备指纹绑定）
- 篡改本地存储的过期时间（签名保护）
- 系统时钟回拨延长有效期（时钟检测）

**已知限制（离线方案固有）:**
- 具备逆向能力的攻击者可通过二进制 patch 或内存 hook 绕过客户端检查
- 已签发的激活码无法远程撤销（无服务器）
- 密钥轮换时旧激活码会失效（新公钥无法验证旧签名），需要所有用户重新激活

**缓解措施**: 代码混淆 + 验证点分散，提高攻击成本但无法完全阻止。

## 3. 核心流程

```
首次启动 → 显示机器码(XXXX-XXXX-XXXX-XXXX)
    ↓
用户发机器码给开发者
    ↓
开发者运行: dart run tool/generate_activation.dart --machine-code=XXXX --days=365
    ↓
用户输入激活码 → App 用内嵌公钥验证签名 + 校验机器码 + 检查有效期
    ↓
激活成功 → 存入 flutter_secure_storage → 正常使用
    ↓
每次启动重新验证（防篡改/过期检测/时钟回拨检测）
```

**过期续期流程:**
```
启动检测到过期 → 显示激活页（保留机器码 + "授权已过期，请联系开发者续期"）
    ↓
用户将同一机器码发给开发者 → 开发者生成新激活码 → 用户输入 → 覆盖旧激活数据
```

## 4. 激活码协议

### 4.1 Payload 格式（大端字节序 Big-Endian）

| 字段 | 偏移 | 大小 | 说明 |
|------|------|------|------|
| version | 0 | 1B | 格式版本 (0x01) |
| machine_hash | 1 | 8B | SHA-256(组合设备指纹) 前 8 字节（64 bit） |
| issued_at | 9 | 4B | 签发时间，uint32 大端（秒级 Unix 时间戳） |
| expires_at | 13 | 4B | 过期时间，uint32 大端（秒级 Unix 时间戳） |
| flags | 17 | 1B | 保留字段（0x00） |
| **payload 合计** | | **18B** | Ed25519 签名的输入 |
| signature | 18 | 64B | Ed25519(private_key, payload[0:18]) |
| **总计** | | **82B** | |

**编码方式**: Base32 (RFC 4648, 无 padding)，82 字节 → 约 132 字符，按 5 字符分组用 `-` 连接。

**machine_hash 与机器码的对应关系**: 机器码显示和 payload 中的 machine_hash 均使用 SHA-256 前 8 字节。机器码以 hex 显示（16 字符），CLI 工具接收此 hex 字符串后直接解码为 8 字节写入 payload。64 bit 碰撞空间对此场景充分（需约 2^32 台设备才有 50% 碰撞概率）。若两台设备碰撞产生相同机器码，其激活码可互用——这是可接受的极低概率风险。

**时间戳说明**: 使用 uint32 无符号整数，有效至 2106 年，无 2038 问题。实现时必须使用 `ByteData.getUint32(offset, Endian.big)` / `setUint32` 进行序列化，禁止手写位移操作。单元测试需覆盖 2038 年之后的时间戳值。

**version 升级策略**: 验证时先读取 version 字段路由到对应解码器。新版本发布时保留对旧 version 的验证支持，直到所有用户迁移完成。

### 4.2 机器码格式

SHA-256(组合设备指纹) 前 16 位 hex，显示为 `XXXX-XXXX-XXXX-XXXX`。

### 4.3 激活码输入优化

- 支持剪贴板粘贴，自动去除空格和换行（首期核心功能）
- 输入框使用等宽字体，自动格式化分组显示
- 不区分大小写（Base32 天然大写，输入时自动转大写）
- [后续迭代] Android 端扫描二维码输入（依赖 `mobile_scanner`）
- [后续迭代] Windows 端从二维码图片文件导入

## 5. 设备指纹

采用多因子组合指纹，提高伪造成本：

### Windows
组合以下标识取 SHA-256（所有外部命令均使用 `Process.run` 参数列表形式调用，避免命令注入；对输出做 trim + 非空校验，空值时使用固定占位符 `"UNKNOWN"`）：

- `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid`（`Process.run('reg', ['query', ...])`)
- 主板序列号（`Process.run('wmic', ['baseboard', 'get', 'serialnumber'])`）
- CPU ID（`Process.run('wmic', ['cpu', 'get', 'processorid'])`）

```
fingerprint = SHA-256(MachineGuid + "|" + BoardSerial + "|" + CpuId)
```

> **兼容性备注**: `wmic` 在 Windows 11 中已标记弃用。当前目标平台 Win10 下可用。后续如需支持 Win11+，改用 PowerShell `Get-CimInstance Win32_BaseBoard` / `Get-CimInstance Win32_Processor` 替代。

### Android
组合以下标识取 SHA-256：
- `Settings.Secure.ANDROID_ID`（通过 `android_id` 包获取，每设备+每应用签名唯一）
- `Build.BOARD` + `Build.HARDWARE`（硬件标识，不受系统更新影响）

```
fingerprint = SHA-256(ANDROID_ID + "|" + Build.BOARD + "|" + Build.HARDWARE)
```

> **注意**: 不包含 `Build.FINGERPRINT`，因其在每次 OTA 系统更新后必然变化，会导致用户频繁重新激活。仅使用不受 OTA 影响的稳定标识。

> **以下场景会导致设备指纹变化，需重新激活**（在激活页面给予用户提示）：
> - Windows 重装系统
> - Android 恢复出厂设置（ANDROID_ID 重置）
> - 更换硬件（主板、CPU 等）

**指纹变化时的用户提示**: 验证时区分"签名无效（激活码错误）"和"机器码不匹配（设备已变更）"两种错误。设备变更时显示："检测到设备已变更，请联系开发者获取新激活码"，并展示新的机器码。

## 6. 加密方案: Ed25519 非对称签名

**为什么选 Ed25519 而非 HMAC？**

| 方案 | App 内嵌 | 反编译风险 |
|------|----------|-----------|
| HMAC (对称) | 共享密钥 | 攻击者拿到密钥可自行生成激活码 |
| Ed25519 (非对称) | 公钥 | 攻击者只能验证，无法伪造激活码 |

**密钥管理:**
- 开发者一次性生成 Ed25519 密钥对
- 私钥加密存储在仓库外部，路径通过环境变量 `ACTIVATION_PRIVATE_KEY` 指定
- 私钥文件本身使用密码保护（AES 加密的 PEM），CLI 使用时需输入密码
- 公钥以 `const` 字节数组统一存放在 `activation/activation_crypto.dart` 中（关注点分离，不侵入 `app.dart` 等非加密模块），配合代码混淆已足够
- `.gitignore` 添加 `tool/keys/`、`*.pem` 规则；pre-commit hook 扫描阻止 PEM 文件提交

## 7. 安全措施

### 7.1 时钟回拨检测
- 每次验证记录当前时间戳到 secure storage（`activation_last_check`）
- 同时维护 `activation_max_seen_time`，记录历史观察到的最大时间戳
- 回拨判定（`回拨量 = max_seen_time - 当前时间`）：
  - 回拨量 ≤ 1 小时：忽略（NTP 同步、夏令时、时区切换等正常波动）
  - 1 小时 < 回拨量 ≤ 7 天：设置 `ActivationInfo.hasClockWarning = true`，在 `app.dart` 的 builder 中（已有 `AiAssistantOverlay` 的 Stack）添加 `MaterialBanner` 显示"系统时间异常"，但允许继续使用
  - 回拨量 > 7 天：标记过期（`ActivationState.expired`），要求重新激活，无论 `expires_at` 是否仍在未来
- 可选增强：如果设备联网，通过 HTTPS 响应头 `Date` 字段辅助校验系统时钟可信性

> **已知限制**: 防爆破计数器和时钟记录均存储在 secure storage 中，用户卸载重装 App 后会重置。这是离线方案的固有限制，不做额外防护。

### 7.2 签名绑定存储
激活数据以原始 payload + signature 的 Base32 字符串存储在 secure storage 中（key: `activation_code`），不使用 JSON 序列化（因此 `ActivationInfo` 不需要 `json_serializable`）。每次启动从存储读取后重新验签+解码。即使用户篡改 secure storage 中的数据，签名验证也会失败。

### 7.3 发布混淆
发布构建使用 `--obfuscate --split-debug-info` 增加逆向难度。

### 7.4 验证点分散
激活检查不仅在启动入口执行，还在以下关键业务 Screen 中通过 `context.read<ActivationService>().isFeatureAccessible()` 检查（Screen 层通过 Provider 访问，不破坏分层架构）：
- `PracticeScreen` — 开始刷题时
- `ExamScreen` — 开始模拟考试时
- `InterviewSessionScreen` — 开始 AI 面试辅导时
- `AdaptiveQuizScreen` — 开始自适应出题时

检查失败时统一行为：弹窗提示"授权已失效，请重新激活"，点击确定后跳转 `ActivationScreen`。

> **设计决策**: 验证点放在 Screen 层而非 `LlmManager` 内部，避免 service 层之间产生横向耦合（`LlmManager` 不应依赖 `ActivationService`），符合项目宪法中"screens → services → db/models"的分层约束。

### 7.5 激活码输入防爆破
连续输入错误激活码时实施指数退避：
- 1-3 次：无限制
- 4-5 次：每次等待 30 秒
- 6 次以上：锁定 30 分钟

错误次数和锁定结束时间（`activation_lockout_until` 时间戳）均持久化到 secure storage，防止重启绕过。锁定状态通过 `ActivationInfo.isInputLocked` + `lockoutUntil` 表达（独立于激活生命周期枚举），激活页据此禁用输入框并展示剩余锁定时间倒计时。

### 7.6 Android 最低版本要求
`flutter_secure_storage` 在 Android 上依赖 `EncryptedSharedPreferences`，要求 API 23+（Android 6.0）。需在 `android/app/build.gradle.kts` 中将 `minSdk` 从 `flutter.minSdkVersion`(21) 改为 `23`，并添加注释说明原因。API 21-22 设备（Android 5.x）市场份额已极低（<1%），影响可忽略。

## 8. 新增依赖

| 包 | 用途 |
|----|------|
| `cryptography` | Ed25519 签名验证（纯 Dart，原生 `Ed25519()` API）。版本以 `flutter pub add` 获取最新兼容版为准 |
| `device_info_plus` | Android Build.* 设备信息。版本以 `flutter pub add` 获取最新兼容版为准 |
| `android_id` | Android ANDROID_ID 获取。版本以 `flutter pub add` 获取最新兼容版为准 |

已有依赖: `flutter_secure_storage`（激活数据存储）、`crypto`（SHA-256，传递依赖）

> **包选型说明**: 选择 `cryptography` 而非 `pointycastle`，因为 `cryptography` 原生提供 `Ed25519()` 高层 API（`sign()`/`verify()`），无需手动组装 Signer。备选: `pinenacl`（NaCl 实现）。**实现第一步需执行 spike**: 运行 `flutter pub add cryptography` 并在 Windows + Android 上验证 Ed25519 sign/verify 的最小 demo。若不兼容则切换备选包。

## 9. 文件变更清单

### 新建文件

| 文件 | 说明 |
|------|------|
| `lib/models/activation_status.dart` | ActivationState 枚举（`notActivated`/`activated`/`expired`） + ActivationInfo 模型（含 `bool hasClockWarning`、`bool isInputLocked`、`DateTime? lockoutUntil`、`DateTime? expiresAt`、`int? remainingDays`、`String? machineCode`） |
| `lib/services/activation/activation_crypto.dart` | Ed25519 验签、payload 编解码、内嵌公钥 |
| `lib/services/activation/device_fingerprint.dart` | 多因子平台设备指纹获取 |
| `lib/services/activation/activation_service.dart` | 激活核心服务 (ChangeNotifier) |
| `lib/screens/activation_screen.dart` | 激活页面 UI（机器码展示、激活码输入、过期续期、设备变更提示） |
| `tool/generate_keypair.dart` | 一次性生成 Ed25519 密钥对（开发者工具） |
| `tool/generate_activation.dart` | 开发者激活码生成 CLI 工具（含审计日志） |

### 修改文件

| 文件 | 变更 |
|------|------|
| `pubspec.yaml` | 添加 cryptography、device_info_plus、android_id |
| `lib/main.dart` | 创建 ActivationService 实例，await checkActivation()，加入 Provider 树 |
| `lib/app.dart` | 嵌套 Consumer 条件路由（激活 → 备考目标 → 首页） |
| `android/app/build.gradle.kts` | `minSdk` 从 `flutter.minSdkVersion`(21) 改为 `23`（注释说明原因） |
| `.gitignore` | 添加 `tool/keys/`、`*.pem` |

## 10. 关键实现要点

### 10.1 ActivationService（ChangeNotifier）

```dart
class ActivationService extends ChangeNotifier {
  // 应用启动时调用，检查本地存储的激活状态
  Future<void> checkActivation() async { ... }

  // 获取当前设备机器码（展示给用户）
  Future<String> getMachineCode() async { ... }

  // 用户输入激活码后调用（含防爆破逻辑）
  Future<ActivationResult> activate(String code) async { ... }

  // 在关键业务路径中调用的轻量级检查（读内存缓存，不做 IO）
  bool isFeatureAccessible() { ... }
}
```

### 10.2 main.dart 初始化

采用与现有 `ExamCategoryService` 一致的模式：先构造实例，await 异步加载，再通过 `ChangeNotifierProvider.value` 注入。

```dart
// main() 中：
final activationService = ActivationService();
await activationService.checkActivation();

// Provider 树中：
ChangeNotifierProvider.value(value: activationService),
```

### 10.3 app.dart 条件路由

与现有 `ExamCategoryService` 路由嵌套组合：

```dart
home: Consumer2<ActivationService, ExamCategoryService>(
  builder: (ctx, activation, examCategory, _) {
    // 第一优先级：激活检查
    if (activation.status.state != ActivationState.activated) {
      return const ActivationScreen();
    }
    // 第二优先级：备考目标选择
    if (!examCategory.hasTarget && !examCategory.isExploreMode) {
      return const ExamTargetScreen();
    }
    return const HomeScreen();
  },
),
```

### 10.4 开发者 CLI 工具

```bash
# 一次性生成密钥对（私钥密码保护）
dart run tool/generate_keypair.dart --output=~/activation_keys/

# 为用户生成激活码（需输入私钥密码）
# 私钥路径通过环境变量传递，不在命令行暴露
export ACTIVATION_PRIVATE_KEY=~/activation_keys/private_key.pem
dart run tool/generate_activation.dart \
  --machine-code=A3F7-B2D9-C5E2-D8A1 \
  --days=365
```

**CLI 审计**: 每次签发自动追加记录到私钥同目录下的 `audit.log`（路径跟随 `ACTIVATION_PRIVATE_KEY` 所在目录），格式：
```
2026-04-07T10:30:00Z | machine=A3F7-B2D9-C5E2-D8A1 | days=365 | expires=2027-04-07
```

## 11. 实现顺序

1. **Spike 验证**: `flutter pub add cryptography` → Windows + Android 运行 Ed25519 最小 demo → 确认可行或切换备选包 `pinenacl`。`activation_crypto.dart` 内部封装验签逻辑，对外暴露统一接口，切换包时仅需修改此文件
2. **加密基础**: .gitignore → 密钥对生成工具 → activation_crypto → 开发者签名工具 → 单元测试（含 RFC 8032 测试向量）
3. **设备指纹**: device_fingerprint（Windows 多因子 + Android 多因子）
4. **激活服务**: activation_status 模型 → activation_service（含时钟检测、防爆破、lockout 持久化） → 接入 main.dart Provider
5. **激活 UI**: activation_screen（含过期续期、设备变更提示、剪贴板粘贴） → app.dart 嵌套 Consumer 条件路由
6. **验证点分散**: 在 PracticeScreen、ExamScreen、InterviewSessionScreen、AdaptiveQuizScreen 添加 `isFeatureAccessible()` 检查
7. **加固**: 发布混淆配置（`--obfuscate --split-debug-info`）、pre-commit hook

## 12. 验证方式

1. `dart run tool/generate_keypair.dart` 生成密钥对
2. Windows 运行 App → 显示激活页 → 复制机器码
3. `dart run tool/generate_activation.dart --machine-code=XXXX --days=30` 生成激活码
4. 输入激活码 → 验证成功进入主页
5. 重启 App → 自动通过验证进入主页
6. 时钟回拨测试：
   - 回拨 30 分钟 → 无影响（≤1h 忽略）
   - 回拨 3 小时 → 显示警告横幅但可使用
   - 回拨 8 天 → 标记过期，要求重新激活
7. 篡改 secure storage 中的过期时间 → 签名验证失败，要求重新激活
8. 连续输入 6 次错误激活码 → 触发锁定 30 分钟，重启后锁定仍有效
9. 验证过期后重新输入新激活码 → 续期成功
10. 在不同设备上使用同一激活码 → 机器码不匹配，提示"设备已变更"
11. 检查 `audit.log` 确认签发记录完整
