# Smart Morning Report Skill

## 功能概述
智能晨报技能，每天早上 09:30 检查任务并发送提醒。
**核心逻辑：** 关键日程 (强制) > 待办任务 (条件) > 静默 (无内容不发)。

## 配置文件
`/root/.openclaw/workspace/skills/smart-morning-report/config.json`

## AI 操作指南

### 1. 查看当前配置
```bash
cat /root/.openclaw/workspace/skills/smart-morning-report/config.json
```

### 2. 添加关键日程 (Critical Date)
当用户提到重要日期（如考试、会议、截止日期）时，自动添加到 `critical_dates` 数组。

**格式：** `MM-DD|提醒内容`

**示例操作：**
1. 读取 `config.json`
2. 在 `critical_dates` 数组中添加新条目
3. 保存文件

**Python 代码示例：**
```python
import json
path = '/root/.openclaw/workspace/skills/smart-morning-report/config.json'
with open(path, 'r') as f:
    config = json.load(f)
config['critical_dates'].append('05-01|劳动节假期')
with open(path, 'w') as f:
    json.dump(config, f, indent=4)
```

### 3. 修改发送时间
用户可以说："把晨报时间改成 8 点"。
更新 `config.json` 中的 `send_time` 字段，并更新 crontab。

### 4. 手动测试
运行脚本测试当前逻辑：
```bash
bash /root/.openclaw/workspace/skills/smart-morning-report/scripts/report.sh
```

## 安装与重置
如果配置丢失，运行：
```bash
bash /root/.openclaw/workspace/skills/smart-morning-report/setup.sh
```
