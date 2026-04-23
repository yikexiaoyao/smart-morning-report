#!/bin/bash
# Smart Morning Report Skill - 交互式安装与配置向导 (v2.0 自动读取版)

echo "🦞 欢迎配置智能晨报技能 (Smart Morning Report)"
echo "================================================"
echo ""
echo "本向导将引导您完成晨报技能的配置。"
echo "💡 提示：脚本将自动从 OpenClaw 配置中读取 Bot Token 和 Chat ID。"
echo ""

# 1. 自动获取 Bot Token
echo "🔍 正在扫描 OpenClaw 配置..."
OPENCLAW_CONFIG="/root/.openclaw/openclaw.json"
AUTO_TOKEN=""

if [ -f "$OPENCLAW_CONFIG" ]; then
    # 使用 Python 提取 Token
    AUTO_TOKEN=$(python3 -c "
import json
try:
    with open('$OPENCLAW_CONFIG', 'r') as f:
        config = json.load(f)
    print(config.get('channels', {}).get('telegram', {}).get('botToken', ''))
except:
    print('')
" 2>/dev/null)
fi

if [ -n "$AUTO_TOKEN" ]; then
    echo "✅ 已自动获取 Bot Token (来自 OpenClaw)"
    BOT_TOKEN="$AUTO_TOKEN"
else
    echo "⚠️ 未找到 OpenClaw 配置，请手动输入 Bot Token。"
    read -p "请输入 Bot Token: " BOT_TOKEN
    if [ -z "$BOT_TOKEN" ]; then
        echo "❌ Bot Token 不能为空，安装已取消。"
        exit 1
    fi
fi

# 2. 自动获取 Chat ID (从最近的会话中查找)
echo ""
echo "🔍 正在查找最近的 Telegram 会话..."
AUTO_CHAT_ID=""
SESSIONS_DB="/root/.openclaw/agents/main/sessions/sessions.json"

if [ -f "$SESSIONS_DB" ]; then
    # 查找最近活跃的 telegram 会话
    AUTO_CHAT_ID=$(python3 -c "
import json
try:
    with open('$SESSIONS_DB', 'r') as f:
        sessions = json.load(f)
    # 按更新时间排序
    sorted_sessions = sorted(sessions.items(), key=lambda x: x[1].get('updatedAt', 0), reverse=True)
    for key, sess in sorted_sessions:
        origin = sess.get('origin', {})
        if origin.get('provider') == 'telegram':
            # 提取 chat_id (通常在 key 中，如 agent:main:telegram:direct:123456)
            parts = key.split(':')
            if len(parts) >= 5:
                print(parts[4])
                break
except:
    print('')
" 2>/dev/null)
fi

if [ -n "$AUTO_CHAT_ID" ]; then
    echo "✅ 已自动获取 Chat ID: $AUTO_CHAT_ID"
    read -p "是否使用此 ID? (y/n) [y]: " USE_CHAT_ID
    USE_CHAT_ID=${USE_CHAT_ID:-"y"}
    if [ "$USE_CHAT_ID" == "y" ]; then
        CHAT_ID="$AUTO_CHAT_ID"
    else
        read -p "请输入正确的 Chat ID: " CHAT_ID
    fi
else
    echo "⚠️ 未找到会话记录，请手动输入 Chat ID。"
    read -p "请输入 Chat ID: " CHAT_ID
fi

if [ -z "$CHAT_ID" ]; then
    echo "❌ Chat ID 不能为空，安装已取消。"
    exit 1
fi

# 3. 获取发送时间
echo ""
echo "⏰ 请输入晨报发送时间 (格式：HH:MM):"
read -p "发送时间 [09:30]: " SEND_TIME
SEND_TIME=${SEND_TIME:-"09:30"}

# 4. 获取关键日程
echo ""
echo "📅 请输入关键日程 (格式：MM-DD|提醒内容，例如：04-18|Clawvard 考试):"
echo "   (输入空行结束添加)"
DATES=()
while true; do
    read -p "日程 (留空结束): " DATE_INPUT
    if [ -z "$DATE_INPUT" ]; then
        break
    fi
    DATES+=("$DATE_INPUT")
done

# 5. 生成配置
echo ""
echo "⚙️ 正在生成配置并设置定时任务..."

# 创建 JSON 配置
CRITICAL_DATES_JSON=$(printf '%s\n' "${DATES[@]}" | python3 -c "
import sys, json
print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))
")

cat > /root/.openclaw/workspace/skills/smart-morning-report/config.json << EOF
{
    "chat_id": "$CHAT_ID",
    "bot_token": "$BOT_TOKEN",
    "send_time": "$SEND_TIME",
    "critical_dates": $CRITICAL_DATES_JSON
}
EOF

echo "✅ 配置文件已生成: config.json"

# 6. 设置 Cron 任务
CRON_TIME=$(echo $SEND_TIME | tr ':' ' ')
CRON_SCHEDULE="${CRON_TIME[1]} ${CRON_TIME[0]} * * *"

# 移除旧的 cron 任务 (如果存在)
(crontab -l 2>/dev/null | grep -v "smart-morning-report") | crontab -

# 添加新的 cron 任务
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE /root/.openclaw/workspace/skills/smart-morning-report/scripts/report.sh") | crontab -

echo "✅ 定时任务已设置：每天 $SEND_TIME 执行"

echo ""
echo "🎉 安装完成！"
echo "================================================"
echo "📋 配置摘要："
echo "   • 接收 ID：$CHAT_ID"
echo "   • 发送时间：$SEND_TIME"
echo "   • 关键日程：${#DATES[@]} 个"
echo "   • Bot Token：已自动从 OpenClaw 读取 ✅"
echo ""
echo "💡 提示："
echo "   • 你可以随时修改 config.json 来调整设置。"
echo "   • 你可以随时运行 bash setup.sh 重新配置。"
echo "   • 你可以随时运行 bash scripts/report.sh 手动测试。"
