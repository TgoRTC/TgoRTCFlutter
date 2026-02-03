#!/bin/bash

# TgoRTC Flutter SDK - HAR 打包脚本
# 
# 此脚本将 Flutter 项目编译并打包成可分发的 HAR 模块
#
# 前提条件:
#   1. 安装鸿蒙版 Flutter SDK (非官方 stable 版本)
#   2. 配置好 OHOS_SDK_HOME 环境变量
#   3. 安装 DevEco Studio
#
# 使用方法:
#   ./scripts/build_har.sh
#
# 输出:
#   dist/tgortc-x.x.x.har
#
# 注意:
#   如果 flutter build ohos 命令不可用，请确保使用的是鸿蒙版 Flutter SDK
#   参考: https://gitcode.com/openharmony-tpc/flutter_flutter

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} TgoRTC Flutter SDK - HAR 打包工具${NC}"
echo -e "${GREEN}========================================${NC}"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 构建模式
BUILD_MODE="${1:-release}"

echo -e "${YELLOW}项目目录: ${PROJECT_ROOT}${NC}"
echo -e "${YELLOW}构建模式: ${BUILD_MODE}${NC}"

# 步骤 1: 检查 Flutter 环境
echo -e "\n${GREEN}[1/5] 检查 Flutter 环境...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}错误: 未找到 flutter 命令。请确保已安装支持鸿蒙的 Flutter SDK。${NC}"
    exit 1
fi
flutter --version

# 步骤 2: 获取依赖
echo -e "\n${GREEN}[2/5] 获取 Flutter 依赖...${NC}"
cd "$PROJECT_ROOT"
flutter pub get

# 步骤 3: 构建 Flutter OHOS 产物
echo -e "\n${GREEN}[3/5] 构建 Flutter OHOS 产物...${NC}"

# 检查是否支持 ohos 平台
if flutter build --help 2>&1 | grep -q "ohos"; then
    echo -e "${GREEN}检测到鸿蒙版 Flutter SDK，执行 flutter build ohos...${NC}"
    flutter build ohos || {
        echo -e "${YELLOW}警告: flutter build ohos 失败${NC}"
    }
else
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}注意: 当前 Flutter SDK 不支持 ohos 平台${NC}"
    echo -e "${YELLOW}================================================${NC}"
    echo -e ""
    echo -e "当前使用的是官方 Flutter SDK，不是鸿蒙版。"
    echo -e "HAR 构建将跳过 Flutter 编译步骤。"
    echo -e ""
    echo -e "后续步骤："
    echo -e "  1. 使用 DevEco Studio 打开 ohos/ 目录"
    echo -e "  2. 在 DevEco 中执行 Build -> Build Hap(s)/APP(s)"
    echo -e "  3. DevEco 会自动调用 Flutter 编译"
    echo -e ""
    echo -e "如需命令行构建，请安装鸿蒙版 Flutter SDK："
    echo -e "  https://gitcode.com/openharmony-tpc/flutter_flutter"
    echo -e ""
fi

# 步骤 4: 构建 HAR 模块
echo -e "\n${GREEN}[4/5] 构建 HAR 模块...${NC}"
cd "$PROJECT_ROOT/ohos"

# 检查 hvigor 是否可用
if command -v hvigorw &> /dev/null; then
    hvigorw assembleHar --mode module -p module=tgortc_library@default
elif [ -f "./hvigorw" ]; then
    ./hvigorw assembleHar --mode module -p module=tgortc_library@default
else
    echo -e "${YELLOW}警告: 未找到 hvigorw，请在 DevEco Studio 中手动构建 HAR${NC}"
    echo -e "${YELLOW}步骤: Build -> Build Hap(s)/APP(s) -> Build HAR${NC}"
fi

# 步骤 5: 复制产物到 dist 目录
echo -e "\n${GREEN}[5/5] 整理输出...${NC}"
DIST_DIR="$PROJECT_ROOT/dist"
mkdir -p "$DIST_DIR"

# 获取版本号
VERSION=$(grep '"version"' "$PROJECT_ROOT/ohos/tgortc_library/oh-package.json5" | sed 's/.*"version": "\(.*\)".*/\1/')

# 复制 HAR 文件
HAR_OUTPUT="$PROJECT_ROOT/ohos/tgortc_library/build/default/outputs/default/tgortc_library.har"
if [ -f "$HAR_OUTPUT" ]; then
    cp "$HAR_OUTPUT" "$DIST_DIR/tgortc-${VERSION}.har"
    echo -e "${GREEN}HAR 文件已生成: dist/tgortc-${VERSION}.har${NC}"
fi

# 复制 Flutter 引擎 HAR
FLUTTER_HAR="$PROJECT_ROOT/ohos/har/flutter.har"
if [ -f "$FLUTTER_HAR" ]; then
    cp "$FLUTTER_HAR" "$DIST_DIR/flutter.har"
    echo -e "${GREEN}Flutter 引擎已复制: dist/flutter.har${NC}"
fi

# 复制 Flutter 产物
FLUTTER_ASSETS="$PROJECT_ROOT/build/ohos/flutter_assets"
if [ -d "$FLUTTER_ASSETS" ]; then
    cp -r "$FLUTTER_ASSETS" "$DIST_DIR/"
    echo -e "${GREEN}Flutter 资源已复制: dist/flutter_assets/${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN} 打包完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}输出目录: ${DIST_DIR}${NC}"
echo ""
echo -e "分发给第三方时，需要提供以下文件:"
echo -e "  1. tgortc-${VERSION}.har    - TgoRTC SDK 模块"
echo -e "  2. flutter.har              - Flutter 引擎"
echo -e "  3. flutter_assets/          - Dart 编译产物"
echo ""
echo -e "第三方集成方式请参考: docs/鸿蒙NEXT集成指南.md"
