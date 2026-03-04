#!/bin/bash
set -e

APP_NAME="MojiSticker"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

# 终止已运行的实例
pkill -x "$APP_NAME" 2>/dev/null && sleep 0.5 || true

# 构建到本地 build 目录
echo "🔨 构建中..."
xcodebuild -scheme "$APP_NAME" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    build -quiet

# 启动
APP_PATH="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
echo "🚀 启动 $APP_NAME"
open "$APP_PATH"
