#!/bin/bash
# Smart Morning Report Script (v2.0)
# 逻辑：关键日程 > 待办任务 > 静默

# 配置文件路径
CONFIG_FILE="/root/.openclaw/workspace/skills/smart-morning-report/config.json"
DB_FILE="/root/.openclaw/workspace/data/tasks.db"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件未找到，请运行 setup.sh 进行初始化。"
    exit 1
fi

# 读取配置
CHAT_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['chat_id'])")
BOT_TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['bot_token'])")

# 1. 检查关键日程 (Critical Dates)
# 格式在 config.json 中：["04-18|考试", "05-01|假期"]
CRITICAL_ALERT=""
TODAY=$(date +%m-%d)

# 读取 JSON 中的 critical_dates 数组
DATES=$(python3 -c "
import json, sys
config = json.load(open('$CONFIG_FILE'))
dates = config.get('critical_dates', [])
for d in dates:
    parts = d.split('|')
    if len(parts) == 2 and parts[0].strip() == '$TODAY':
        print(parts[1].strip())
        sys.exit(0)
")

if [ -n "$DATES" ]; then
    CRITICAL_ALERT="⚠️ 关键提醒：$DATES"
fi

# 如果有关键日程，直接发送并退出
if [ -n "$CRITICAL_ALERT" ]; then
    echo "📅 触发关键日程提醒：$DATES"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -d "chat_id=${CHAT_ID}" \
      -d "text=${CRITICAL_ALERT}" > /dev/null
    exit 0
fi

# 2. 检查待办任务 (Pending Tasks)
# 只有数据库存在时才检查
if [ -f "$DB_FILE" ]; then
    PENDING=$(python3 -c "
import sqlite3
conn = sqlite3.connect('$DB_FILE')
cursor = conn.cursor()
cursor.execute('SELECT COUNT(*) FROM tasks WHERE status = \"pending\" AND due_date <= DATE(\"now\")')
print(cursor.fetchone()[0])
conn.close()
" 2>/dev/null)

    if [ "$PENDING" -gt 0 ]; then
        echo "📋 发现 $PENDING 个待办任务，生成晨报..."
        # 调用智能晨报生成器
        REPORT=$(python3 /root/.openclaw/workspace/scripts/smart-morning-report.py generate 2>/dev/null)
        
        if [ -n "$REPORT" ]; then
            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
              -d "chat_id=${CHAT_ID}" \
              -d "text=${REPORT}" \
              -d "parse_mode=Markdown" > /dev/null
            echo "✅ 晨报已发送"
        else
            echo "⚠️ 生成晨报失败"
        fi
        exit 0
    fi
fi

# 3. 无任务且无日程，静默
echo "⏭️ 无任务，无日程，跳过发送。"
exit 0
