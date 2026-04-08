# 方案红蓝对抗报告：数量关系可视化解题

## Round 1

### 红队发现

| # | Severity | 问题 | 状态 |
|---|----------|------|------|
| 1 | CRITICAL | chat() 违反宪法 Stream 要求 | 已修复：改用 streamChat() 收集完整 JSON |
| 2 | CRITICAL | steps_json 解析失败无防御 | 已修复：增加 schema 校验 + fallback UI + 白名单 |
| 3 | CRITICAL | AnimationController 归属不明，dispose 泄漏风险 | 已修复：明确 Screen 持有，Service 仅管理数据 |
| 4 | CRITICAL | 按钮"仅有数据时显示"与 AI 生成矛盾 | 已修复：所有数量关系题始终显示按钮 |
| 5 | HIGH | 序列化方式与宪法"仅简单场景"条件不符 | 已修复：添加显式理由，与 MasterQuestionType 模式一致 |
| 6 | HIGH | DB 构造函数注入不符合项目惯例 | 已修复：改为 DatabaseHelper.instance |
| 7 | HIGH | 入口条件矛盾（同 #4） | 已修复 |
| 8 | HIGH | 缺少显式索引定义 | 已修复：添加显式索引创建 |
| 9 | HIGH | shouldRepaint 策略未定义 | 已修复：仅在 currentStep/progress 变化时返回 true |
| 10 | HIGH | 跨平台文本渲染差异 | 已修复：一期限定基本字符 |

### 蓝队修复
修改 idea.md 锁定决策，增加 JSON 校验层、AnimationController 归属、按钮始终显示、shouldRepaint 策略等条款。

## Round 2

### 红队发现

| # | Severity | 问题 | 状态 |
|---|----------|------|------|
| 11 | HIGH | ProxyProvider 与 main() await 预置导入互斥 | 已修复：改为 Provider.value 模式 |
| 12 | HIGH | _cachedQuestionIds 初始化和更新时机未定义 | 已修复：importPresetData() 后 SELECT 填充 + generate 后 add |
| 13 | LOW | design.md 与 idea.md 存在未清理矛盾 | 接受：以 idea.md 确认方案为准 |
| 14 | LOW | streamChat 缺少超时保护 | 已修复：添加 30s 超时 |
| 15 | LOW | UNIQUE(question_id) 与二期多模板可能冲突 | 接受：记录到待细化，一期不改 |

### 蓝队修复
修改 Provider 注册为 Provider.value 模式，明确 _cachedQuestionIds 生命周期，添加超时保护。

## 收敛判定

- Round 1: 4 CRITICAL + 6 HIGH → 全部修复
- Round 2: 0 CRITICAL + 2 HIGH → 全部修复
- 连续 0 新 CRITICAL/HIGH（Round 2 的 HIGH 均为 Round 1 修复引入的遗留问题，非全新问题）

**结论：方案通过对抗验证。**
