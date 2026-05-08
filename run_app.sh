#!/bin/bash

# Visual PM2 GUI - 启动脚本

APP_PATH="/Users/douba/Projects/XM/project/pm2-swift/build/VisualPM2GUI.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/VisualPM2GUI"

echo "🚀 启动 Visual PM2 GUI..."
echo ""

# 检查可执行文件
if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ 可执行文件不存在"
    echo "请先运行: ./build.sh"
    exit 1
fi

# 停止已存在的实例
echo "🔄 检查现有实例..."
if pgrep -x VisualPM2GUI > /dev/null; then
    echo "⚠️  发现运行中的实例，正在停止..."
    killall VisualPM2GUI 2>/dev/null
    sleep 1
fi

# 启动应用
echo "▶️  启动应用..."
"$EXECUTABLE" &

# 等待应用启动
sleep 2

# 检查进程状态
if pgrep -x VisualPM2GUI > /dev/null; then
    PID=$(pgrep -x VisualPM2GUI)
    echo "✅ 应用已启动！"
    echo "📊 进程 ID: $PID"
    echo ""
    echo "📍 请检查 macOS 状态栏（右上角）:"
    echo "   - 应该显示 🟢 绿色圆点图标"
    echo "   - 点击图标打开服务列表"
    echo ""
    echo "📝 查看日志:"
    echo "   tail -f /tmp/visual-pm2.log"
    echo ""
    echo "🛑 停止应用:"
    echo "   killall VisualPM2GUI"
else
    echo "❌ 应用启动失败"
    echo "查看日志: cat /tmp/visual-pm2.log"
    exit 1
fi
