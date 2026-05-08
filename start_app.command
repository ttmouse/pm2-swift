#!/bin/bash
# Visual PM2 GUI - 一键启动脚本
# 双击此文件即可启动应用

cd "$(dirname "$0")"

echo "🚀 正在启动 Visual PM2 GUI..."
echo ""

# 检查是否已构建
if [ ! -f "build/VisualPM2GUI.app/Contents/MacOS/VisualPM2GUI" ]; then
    echo "📦 应用未构建，正在构建..."
    ./build.sh
    
    if [ $? -ne 0 ]; then
        echo "❌ 构建失败！"
        read -p "按任意键退出..."
        exit 1
    fi
fi

# 启动应用
echo "✅ 启动应用..."
open "build/VisualPM2GUI.app"

echo ""
echo "💡 提示："
echo "   - 应用图标会出现在状态栏（右上角）"
echo "   - 点击图标可以查看 PM2 服务状态"
echo "   - 右键点击图标可以退出应用"
echo ""

# 3秒后自动关闭
sleep 3
