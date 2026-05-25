#!/bin/bash
# ============================================================
# BlindAssist 开发环境加载脚本
# 
# 用法：
#   source scripts/setup_env.sh
#
# 请根据你的本地环境修改以下路径
# ============================================================

export JAVA_HOME="$HOME/jdk-17"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER_HOME="$HOME/flutter"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$FLUTTER_HOME/bin:$PATH"

echo "✅ BlindAssist 开发环境已加载"
echo "  Java:    $(java -version 2>&1 | head -1)"
echo "  Flutter: $(flutter --version 2>&1 | head -1)"
echo "  ADB:     $(adb --version 2>&1 | head -1)"
