# 岗位公告详情查看

## 核心需求
岗位匹配中，点击相应的岗位，需要能看到岗位的公告详情。

## 确认方案

### 锁定决策
- 扩展已有的 `PositionDetailScreen`（StatelessWidget → StatefulWidget）
- initState 通过 `positionId` 查询 position 和关联的 policy
- 展示三段内容：匹配分析 → 岗位要求详情 → 公告原文
- 新增 `DatabaseHelper.queryPolicyById()` 方法
- 无新 model、无新 service、无 DB schema 变更

### 验收标准
- [mechanical] queryPolicyById 存在：`grep "queryPolicyById" lib/db/database_helper.dart`
- [mechanical] PositionDetailScreen 为 StatefulWidget：`grep "StatefulWidget" lib/screens/policy_match_screen.dart`
- [manual] 点击匹配结果中的"查看详情" → 显示岗位要求和公告原文
