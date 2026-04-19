#!/bin/bash
# Script untuk membantu refactoring script shell yang ada

set -euo pipefail

SCRIPT_TO_REFACTOR="$1"
BACKUP_DIR="/root/.openclaw/workspace/backups/scripts"

if [ -z "$SCRIPT_TO_REFACTOR" ] || [ ! -f "$SCRIPT_TO_REFACTOR" ]; then
    echo "Usage: $0 <script_path>"
    echo "Example: $0 /root/.openclaw/workspace/scripts/generate-image.sh"
    exit 1
fi

# Create backup
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/$(basename "$SCRIPT_TO_REFACTOR").$(date +%Y%m%d-%H%M%S).bak"
cp "$SCRIPT_TO_REFACTOR" "$BACKUP_FILE"
echo "✅ Backup created: $BACKUP_FILE"

# Analyze script
echo "🔍 Analyzing $SCRIPT_TO_REFACTOR..."
echo ""

# Check for common issues
echo "📋 ISSUES FOUND:"
echo "----------------"

# 1. Check for set -e
if ! grep -q "^set -e" "$SCRIPT_TO_REFACTOR"; then
    echo "❌ Missing 'set -e' (exit on error)"
fi

# 2. Check for hardcoded /root/.openclaw paths
HARDCODED_PATHS=$(grep -c "/root/\\.openclaw" "$SCRIPT_TO_REFACTOR" || true)
if [ "$HARDCODED_PATHS" -gt 0 ]; then
    echo "❌ $HARDCODED_PATHS hardcoded /root/.openclaw paths"
fi

# 3. Check for insecure temp files
INSECURE_TEMP=$(grep -c "/tmp/[a-zA-Z]" "$SCRIPT_TO_REFACTOR" || true)
if [ "$INSECURE_TEMP" -gt 0 ]; then
    echo "❌ $INSECURE_TEMP insecure /tmp/ file patterns"
fi

# 4. Check for silent curl
SILENT_CURL=$(grep -c "curl -s" "$SCRIPT_TO_REFACTOR" || true)
if [ "$SILENT_CURL" -gt 0 ]; then
    echo "⚠️  $SILENT_CURL silent curl commands (consider -f flag)"
fi

# 5. Check for API key patterns
API_KEY_PATTERNS=$(grep -c "auth-profiles\\.json" "$SCRIPT_TO_REFACTOR" || true)
if [ "$API_KEY_PATTERNS" -gt 0 ]; then
    echo "⚠️  $API_KEY_PATTERNS direct auth-profiles.json references"
fi

# 6. Check script length
LINE_COUNT=$(wc -l < "$SCRIPT_TO_REFACTOR")
if [ "$LINE_COUNT" -gt 150 ]; then
    echo "⚠️  Script is $LINE_COUNT lines (consider modularization)"
fi

echo ""
echo "🔧 RECOMMENDED REFACTORING STEPS:"
echo "---------------------------------"

cat << 'EOF'

1. ADD ERROR HANDLING HEADER:
   ```
   #!/bin/bash
   set -euo pipefail
   IFS=$'\n\t'
   trap 'echo "Error at line $LINENO"; exit 1' ERR
   ```

2. REPLACE HARCODED PATHS:
   ```
   # Before: /root/.openclaw/agents/agent1/agent/auth-profiles.json
   # After:  ${OPENCLAW_DIR:-/root/.openclaw}/agents/agent1/agent/auth-profiles.json
   ```

3. USE SAFE TEMP FILES:
   ```
   # Before: /tmp/myfile-$$.txt
   # After:  TEMP_FILE=$(mktemp)
   #         trap 'rm -f "$TEMP_FILE"' EXIT
   ```

4. IMPROVE CURL COMMANDS:
   ```
   # Before: curl -s https://api.example.com
   # After:  curl -f -s --max-time 30 https://api.example.com
   ```

5. CENTRALIZE API KEY LOOKUP:
   Use the get_api_key() function from template-best-practice.sh

6. ADD INPUT VALIDATION:
   Validate all function arguments and file paths

7. ADD LOGGING:
   Add log_info(), log_error() functions for better debugging

EOF

echo ""
echo "📝 GENERATED REFACTORING PATCH:"
echo "-------------------------------"

# Generate simple patch suggestions
cat << EOF
--- a/$(basename "$SCRIPT_TO_REFACTOR")
+++ b/$(basename "$SCRIPT_TO_REFACTOR")
@@ -1,4 +1,10 @@
 #!/bin/bash
+set -euo pipefail
+IFS=\$'\\n\\t'
+
+# Configuration
+: "\${OPENCLAW_DIR:=/root/.openclaw}"
+: "\${OPENCLAW_WORKSPACE:=\$OPENCLAW_DIR/workspace}"

EOF

# Show first 10 lines for context
echo ""
echo "📄 SCRIPT PREVIEW (first 20 lines):"
echo "-----------------------------------"
head -20 "$SCRIPT_TO_REFACTOR"

echo ""
echo "🎯 NEXT STEPS:"
echo "1. Review the issues above"
echo "2. Apply the refactoring patch"
echo "3. Test the script thoroughly"
echo "4. Run shellcheck: shellcheck $SCRIPT_TO_REFACTOR"
echo ""
echo "📚 See template: /root/.openclaw/workspace/scripts/template-best-practice.sh"