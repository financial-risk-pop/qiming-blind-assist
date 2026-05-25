# 启明 (QiMing) — AI 视障出行辅助 App

> 一部手机，成为视障用户的"眼睛"。

**「愿你眼中有光」**

---

## 项目简介

启明是一款面向视障群体的 AI 辅助应用，基于 Flutter 跨平台开发。通过端侧 AI + 全语音交互，帮助视障用户实现安全出行、信息获取和独立生活。

核心理念：**零硬件成本、零视觉依赖、端侧优先**。

---

## 功能特性

| 功能 | 描述 | 技术实现 |
|------|------|----------|
| 🔍 实时场景识别 | 摄像头画面转语音描述 | ML Kit Image Labeling + 像素分析 |
| ⚠️ 障碍物检测 | 行人/车辆/动物预警，震动+语音双提醒 | ML Kit + 优先级队列 |
| 🧭 步行导航 | 语音输入目的地，全程语音引导 | 高德 v3 步行 API + WGS84→GCJ02 坐标转换 |
| 📄 OCR 文字朗读 | 对准文字自动识别朗读 | ML Kit Text Recognition |
| 🎤 语音交互 | 全功能语音控制 | Android 原生 SpeechRecognizer |
| 🔊 TTS 双引擎 | 系统TTS + 在线TTS自动容灾 | Native Platform Channel |

---

## 技术亮点

### 1. TTS 双引擎容灾机制

国产 Android 设备 TTS 兼容性差是行业难题。启明采用：
- 原生 `TextToSpeech` 优先，失败后自动延迟重试
- 重试仍失败则降级百度在线 TTS
- `AudioFocusRequest` + `USAGE_ASSISTANT` 确保蓝牙/音频路由正确
- 将设备语音可用率从 ~60% 提升至接近 100%

### 2. 端侧多模型复用

场景识别、障碍检测、OCR 三个 AI 引擎共享摄像头数据流，通过帧调度避免资源竞争。全部端侧推理，无需网络，保护隐私。

### 3. WGS-84 → GCJ-02 坐标转换

GPS 返回 WGS-84 坐标，高德 API 需要 GCJ-02。内置坐标转换算法，消除 100-700 米定位偏移。

### 4. 全语音无障碍交互

从权限引导到功能操作，全链路语音驱动。高对比度 UI + 全局语音按钮，零视觉依赖。

---

## 技术架构

```
┌─────────────────────────────────────────────┐
│                 Flutter UI Layer             │
│  (高对比度 · 大字体 · 全语音交互)             │
├─────────────────────────────────────────────┤
│              Feature Modules                 │
│  场景识别 │ 障碍检测 │ 导航 │ OCR │ 语音     │
├─────────────────────────────────────────────┤
│              Core Services                   │
│  TTS双引擎 │ 语音识别 │ 坐标转换 │ 日志      │
├─────────────────────────────────────────────┤
│           Platform Channels                  │
│  TtsChannel.kt │ SpeechChannel.kt           │
├─────────────────────────────────────────────┤
│           Android / iOS Native               │
└─────────────────────────────────────────────┘
```

---

## 项目结构

```
blind_assist_app/
├── lib/
│   ├── main.dart                        # 应用入口
│   ├── core/
│   │   ├── tts/safe_tts.dart            # TTS 统一封装
│   │   ├── speech/native_speech.dart    # 语音识别封装
│   │   ├── services/amap_nav_service.dart  # 高德导航 + 坐标转换
│   │   └── utils/logger.dart            # 日志工具
│   └── features/
│       ├── recognize/                   # 场景识别 (ML Kit)
│       ├── obstacle_detection/          # 障碍物检测
│       ├── navigation/                  # 步行导航
│       ├── ocr_recognition/             # OCR 文字识别
│       ├── voice_interaction/           # 语音交互
│       ├── onboarding/                  # 权限引导
│       └── home/                        # 首页
├── android/
│   └── app/src/main/kotlin/.../channels/
│       ├── TtsChannel.kt                # 原生 TTS 双引擎
│       └── SpeechChannel.kt             # 原生语音识别
├── pubspec.yaml
└── README.md
```

---

## 环境要求

- Flutter SDK >= 3.2.0
- Dart SDK >= 3.2.0
- Android Studio / VS Code
- JDK 17
- Android SDK (compileSdk 35, minSdk 24)

---

## 快速开始

```bash
# 克隆项目
git clone https://github.com/YOUR_USERNAME/qiming-blind-assist.git
cd qiming-blind-assist

# 安装依赖
flutter pub get

# 运行 (Debug)
flutter run

# 构建 Release APK
flutter build apk --release --no-tree-shake-icons
```

---

## 配置说明

### 高德地图 API Key

在 `lib/core/services/amap_nav_service.dart` 中替换为你自己的 Key：

```dart
static const String _apiKey = 'YOUR_AMAP_WEB_SERVICE_KEY';
```

申请地址：[高德开放平台](https://console.amap.com/dev/key/app)，类型选「Web服务」。

---

## 适配测试

| 设备 | 系统 | TTS | 导航 | 识别 |
|------|------|-----|------|------|
| realme GT8 | ColorOS (Android 14) | ✅ 在线降级 | ✅ | ✅ |

---

## 目录说明

| 目录/文件 | 说明 |
|-----------|------|
| `lib/features/` | 各功能模块 (Clean Architecture) |
| `android/channels/` | 原生平台通道 (Kotlin) |
| `docs/` | 技术文档 |
| `assets/` | 模型、音效、国际化资源 |

---

## 许可证

本项目仅供学习交流使用。

---

## 致谢

- [Flutter](https://flutter.dev/)
- [Google ML Kit](https://developers.google.com/ml-kit)
- [高德开放平台](https://lbs.amap.com/)
- [百度语音合成](https://ai.baidu.com/tech/speech/tts_online)
