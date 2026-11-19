#!/bin/bash
# build-ipa.sh — 在 Mac 上把 PodsStats 编译为未签名 IPA（供 AltStore 侧载）。
#
# 用法（在项目根目录）：
#   ./build-ipa.sh
#
# 产物：./build/PodsStats.ipa
# 说明：本脚本不签名、不需要开发者账号、不需要证书。
#   编译用 CODE_SIGNING_ALLOWED=NO 生成未签名的 .app，再打包成 IPA；
#   安装时由 AltStore 用你自己的免费 Apple ID 重新签名。
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
SCHEME="PodsStats"
PROJECT="$PROJECT_ROOT/PodsStats.xcodeproj"
DERIVED_DATA="$PROJECT_ROOT/build/DerivedData"
IPA_PATH="$PROJECT_ROOT/build/PodsStats.ipa"

echo "==> 清理旧产物"
rm -rf "$PROJECT_ROOT/build"
mkdir -p "$DERIVED_DATA"

echo "==> xcodebuild（Release，未签名）"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Release-iphoneos/PodsStats.app"
if [ ! -d "$BUILT_APP" ]; then
  echo "错误：未找到编译产物 $BUILT_APP" >&2
  echo "可能原因：Xcode 版本过旧（需要 Xcode 16+，iOS 17 SDK）或编译报错，往上翻 xcodebuild 的输出。" >&2
  exit 1
fi

echo "==> 打包 IPA"
mkdir -p "$PROJECT_ROOT/build/Payload"
cp -R "$BUILT_APP" "$PROJECT_ROOT/build/Payload/PodsStats.app"
cd "$PROJECT_ROOT/build"
zip -qr PodsStats.ipa Payload
rm -rf Payload

echo "==> 完成：$IPA_PATH"
ls -lh "$IPA_PATH"
