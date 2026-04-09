# 未实现需求索引

> 来源：`docs/TODO/需求—-发给小冯同志.xlsx`
> 需求共 8 个模块，其中 3 个已实现，5 个未实现。各功能完全独立解耦，可并行开发。

## 已实现功能（无需开发）

| 需求模块 | 现有实现 |
|----------|---------|
| 申论—思维培养 | `HotTopicsScreen` + `EssayMaterialScreen` + `HotTopicService` |
| 行测—言语理解—片段阅读 | `QuestionService` 言语理解分类 + `verbal_comprehension.json` |
| 行测—言语理解—选词填空 | `IdiomListScreen` + `IdiomService` + `idioms_preset.json` |

## 未实现功能设计文档

| 优先级 | 功能 | 设计文档 | 复杂度 | 新增表数 |
|--------|------|---------|--------|---------|
| P0 | 资料分析—每日速算训练 | [`speed_training/design.md`](../speed_training/design.md) | 中 | 3 |
| P0 | 政治理论—文件解读与口诀 | [`political_theory/design.md`](../political_theory/design.md) | 中 | 4 |
| P1 | 申论—小题多名师答案对比 | [`essay_comparison/design.md`](../essay_comparison/design.md) | 中高 | 3 |
| P2 | 数量关系—可视化解题 | [`math_visual_explanation/design.md`](../math_visual_explanation/design.md) | 高 | 1 |
| P3 | 图形推理—立体拼合可视化 | [`spatial_visualization/design.md`](../spatial_visualization/design.md) | 极高 | 1 |

## 并行开发注意事项

5 个功能完全独立：各自有独立的表、Service、Screen、Widget，无相互依赖。

**唯一共享点是 DB 版本迁移**：各功能在 `database_helper.dart` 的 `onUpgrade` 中各自创建自己的表。建议统一在 `v14 → v15` 中创建所有 12 张新表（每个功能的 CREATE TABLE 互不影响），避免版本号冲突。
