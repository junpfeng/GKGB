#!/bin/bash
# Hook: 检查代码中是否包含虚假/占位符数据
# 扫描被修改的文件，检测常见的假数据模式

# 获取所有待提交和已修改的文件（Dart 和 JSON）
FILES=$(git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null; git diff --name-only --diff-filter=ACMR --cached 2>/dev/null)
if [ -z "$FILES" ]; then
  # 如果没有 git diff，检查最近修改的文件
  FILES=$(git diff --name-only --diff-filter=ACMR HEAD~1 HEAD 2>/dev/null)
fi

if [ -z "$FILES" ]; then
  exit 0
fi

# 只检查 Dart 和 JSON 文件
FILES=$(echo "$FILES" | grep -E '\.(dart|json)$' || true)
if [ -z "$FILES" ]; then
  exit 0
fi

VIOLATIONS=""

for f in $FILES; do
  [ -f "$f" ] || continue

  # 检测假 URL 模式
  if grep -nE 'example\.com|test\.com|placeholder\.com|fake\.com|dummy\.com|localhost.*公告|http://test[./]|https?://xxx' "$f" 2>/dev/null; then
    VIOLATIONS="$VIOLATIONS\n⚠️ [$f] 包含疑似虚假 URL（example.com/test.com 等占位域名）"
  fi

  # 检测 lorem ipsum 等占位文本
  if grep -niE 'lorem ipsum|placeholder|fake.?data|dummy.?data|todo.*replace|测试数据.*勿用|假数据' "$f" 2>/dev/null; then
    VIOLATIONS="$VIOLATIONS\n⚠️ [$f] 包含占位符文本（lorem ipsum/placeholder/fake data 等）"
  fi

  # 检测明显的虚构公告数据模式（常见于预置数据）
  if grep -nE '"url"\s*:\s*"https?://(www\.)?example' "$f" 2>/dev/null; then
    VIOLATIONS="$VIOLATIONS\n⚠️ [$f] 包含指向 example.com 的公告 URL，必须使用真实链接"
  fi
done

if [ -n "$VIOLATIONS" ]; then
  echo ""
  echo "============================================"
  echo "❌ 数据真实性检查失败"
  echo "============================================"
  echo -e "$VIOLATIONS"
  echo ""
  echo "规则：所有数据必须全面、真实、有效。"
  echo "禁止使用虚假 URL、占位符文本或编造的数据。"
  echo "如无法获取真实数据，应留空而非用假数据填充。"
  echo "============================================"
  exit 1
fi

exit 0
