#!/bin/bash

# JSON 파일 경로
JSON_FILE="video_bulk_single_line.json"

# JSON 유효성 확인
echo "1. Checking JSON validity..."
if ! jq empty "$JSON_FILE" 2>/dev/null; then
    echo "Error: JSON 파일이 유효하지 않습니다. 올바른 형식인지 확인하세요."
    exit 1
fi
echo "JSON 파일이 유효합니다."

# 원본 JSON 데이터를 한 줄로 변환
echo "2. Flattening JSON content into a single line..."
FLATTENED_JSON=$(jq -c . "$JSON_FILE" 2>/dev/null)

if [ -z "$FLATTENED_JSON" ]; then
    echo "Error: JSON을 한 줄로 변환하는 중 문제가 발생했습니다."
    exit 1
fi

# 결과 출력
echo "Flattened JSON content:"
echo "$FLATTENED_JSON"

# 변환된 JSON을 파일로 저장
FLATTENED_FILE="flattened_${JSON_FILE}"
echo "$FLATTENED_JSON" > "$FLATTENED_FILE"
echo "변환된 JSON이 $FLATTENED_FILE 파일에 저장되었습니다."

