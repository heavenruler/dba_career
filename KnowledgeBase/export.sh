#!/bin/bash

# 配置参数
JSON_FILE="knowledge_base_md5_test.json"
OUTPUT_DIR="collector"
CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
VIRTUAL_TIME=10000  # 10秒等待时间 (毫秒)

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 递归提取所有条目并处理
jq -r '.. | .[]? | select(type == "array" and length >=3) | "\(.[1]) \(.[2])"' "$JSON_FILE" | while read -r url md5; do

  # 过滤空行和非 URL
  if [[ -z "$url" || "$url" != http* ]]; then
    continue
  fi

  echo "Processing: $url"
  
  # 构建输出路径
  output_pdf="${OUTPUT_DIR}/${md5}.pdf"
  
  # 执行 Chrome 截图命令
  "$CHROME_PATH" \
    --headless \
    --disable-gpu \
    --run-all-compositor-stages-before-draw \
    --virtual-time-budget=$VIRTUAL_TIME \
    --print-to-pdf="$output_pdf" \
    "$url" 2> /dev/null

  # 检查是否生成成功
  if [[ -f "$output_pdf" ]]; then
    echo "Success: ${md5}.pdf"
  else
    echo "Failed:  $url"
  fi

  # 添加延迟防止高频请求
  sleep 3
done
