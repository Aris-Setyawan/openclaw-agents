#!/bin/bash

# Check DeepSeek balance
echo "DeepSeek:"
curl -s https://api.openrouter.ai/v1/auth/key \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq '.credits'

# Check OpenRouter balance
echo "\nOpenRouter:"
curl -s https://api.openrouter.ai/v1/auth/key \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq '.credits'

# Check ModelStudio (Alibaba DashScope) status
echo "\nModelStudio:"
curl -s https://dashscope-intl.aliyuncs.com/compatible-mode/v1 \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" -I | head -n 1