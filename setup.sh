#!/bin/bash
# Smart Morning Report Setup Script
# 引导用户配置晨报技能

echo "🦞 欢迎配置智能晨报技能 (v2.0)"
echo "================================"
echo ""

# 1. 获取 Telegram Chat ID
echo "📱 请输入你的 Telegram Chat ID:"
echo "   (如果你不知道，可以在 Telegram 搜索 @userinfobot 获取)"
read -p "Chat ID: " CHAT_ID

if [ -z "$CHAT_ID" ]; then
    echo "❌ Chat ID 不能为空，安装已取消。"
    exit 1
fi

# 2. 获取发送时间
echo ""
echo "⏰ 请输入晨报发送时间 (格式：HH:MM):"
read -p "发送时间 [09:30]: " SEND_TIME
SEND_TIME=${SEND_TIME:-09:30}

# 3. 获取关键日程
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

# 4. 获取 Bot Token (默认使用系统配置)
echo ""
echo "🔑 请输入 Telegram Bot Token:"
echo "   (默认使用系统已配置的 Token)"
read -p "Bot Token [8507830653:AAExPP5FxP9Me5XbR-zvY3AoC3tSDAHMrlw]: " BOT_TOKEN
BOT_TOKEN=${BOT_TOKEN:-"8507830653:AAExPP5FxP9Me5XbR-zvY3AoC3tSDAHMrlw"}

# 5. 生成配置
echo ""
echo "⚙️ 正在生成配置..."

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

echo "✅ 配置已保存至 config.json"

# 6. 设置 Cron 任务
CRON_TIME=$(echo $SEND_TIME | tr ':' ' ')
CRON_SCHEDULE="${CRON_TIME[1]} ${CRON_TIME[0]} * * *"

# 移除旧的 cron 任务 (如果存在)
(crontab -l 2>/dev/null | grep -v "smart-morning-report") | crontab -

# 添加新的 cron 任务
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE /root/.openclaw/workspace/skills/smart-morning-report/scripts/report.sh") | crontab -

echo "✅ Cron 定时任务已设置：每天 $SEND_TIME 执行"

echo ""
echo "🎉 安装完成！"
echo "================================"
echo "📋 配置摘要："
echo "   • 发送时间：$SEND_TIME"
echo "   • 关键日程：${#DATES[@]} 个"
echo "   • 逻辑：关键日程优先 > 待办任务 > 静默"
echo ""
echo "💡 提示：你可以随时修改 config.json 来调整设置。"
