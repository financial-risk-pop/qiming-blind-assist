# 盲人智能辅助App - 技术架构设计文档

> **文档版本**：v1.1  
> **更新日期**：2026-04-17  
> **项目代号**：BlindAssist  

---

## 目录

1. [产品概述](#1-产品概述)
2. [核心功能定义](#2-核心功能定义)
3. [技术栈选型](#3-技术栈选型)
4. [系统架构设计](#4-系统架构设计)
5. [模块详细设计](#5-模块详细设计)
6. [数据流设计](#6-数据流设计)
7. [API接口设计](#7-api接口设计)
8. [传感器融合方案](#8-传感器融合方案)
9. [无障碍设计规范](#9-无障碍设计规范)
10. [性能与安全考量](#10-性能与安全考量)
11. [第三方SDK集成方案](#11-第三方sdk集成方案)
12. [目录结构](#12-目录结构)

---

## 1. 产品概述

### 1.1 产品定位

一款面向盲人/视障群体的智能辅助App，适配Android和iOS全系统。通过AI视觉、传感器融合、语音交互和地图导航等技术，帮助视障用户安全出行、感知环境、获取文字信息，并无障碍地操作手机。

### 1.2 目标用户

| 用户类型 | 特征 | 核心需求 |
|---------|------|---------|
| 全盲用户 | 完全无视力 | 语音为主要交互方式，需要全语音导航和完整的环境描述 |
| 低视力用户 | 有残余视力 | 高对比度界面辅助，结合语音增强信息获取 |
| 后天失明用户 | 曾有视觉经验 | 空间描述可以使用视觉化语言（如"红色建筑"） |
| 辅助者/护工 | 明眼人 | 需要可视化界面监控和远程协助功能 |

### 1.3 核心价值主张

- **安全出行**：实时障碍物检测，降低出行风险
- **独立导航**：精细化语音导航，实现独立出行
- **信息获取**：随时获取环境中的文字信息
- **智能操控**：全语音交互，解放双手
- **App无障碍**：智能解读手机上任何App的界面内容，弥补系统屏幕阅读器的不足

---

## 2. 核心功能定义

### 2.1 语音导航

- 集成地图SDK实现精细化语音导航，提供"前方5米右转"级别的细粒度语音引导
- 支持起点/终点语音输入，路线规划与实时导航
- 关键路口、台阶、斜坡等特殊路段增强提醒
- 偏航自动重新规划并语音告知
- 到达目的地后，辅助定位具体入口/门

### 2.2 障碍物实时检测

- 通过手机摄像头实时分析前方画面，识别行人、车辆、路障、台阶、坑洞等障碍物
- 根据障碍物距离和方位，通过语音播报+震动反馈双通道提醒用户
- 支持离线工作，确保无网络环境下的安全性
- 智能检测频率：静止时低频，行走时高频

### 2.3 文字/牌匾OCR识别与朗读

- 摄像头对准目标后自动识别并朗读文字内容
- 支持牌匾、路牌、菜单、门牌号、药品说明书等多场景
- 支持中英文混合识别
- 云端精细模式支持手写体和低质量图像

### 2.4 全语音交互

- 语音指令控制App所有核心功能（"导航去XXX"、"前方有什么"、"读一下这个"）
- 支持语音唤醒，无需触碰屏幕即可激活
- 所有操作结果均有语音反馈
- 支持自然语言理解（模糊指令也能正确处理）

### 2.5 无障碍手机操作优化

- 深度适配iOS VoiceOver和Android TalkBack
- 所有UI元素提供完整的语义标注
- 简化交互手势，支持大面积触摸区域
- 高对比度界面模式

### 2.6 ⭐ App内容读取与智能解说（Screen Reader AI）

**这是本App的差异化核心功能之一**，旨在解决系统自带屏幕阅读器（TalkBack/VoiceOver）在面对无障碍适配不完善的第三方App时的局限性。

#### 2.6.1 功能描述

| 功能项 | 说明 |
|-------|------|
| **App识别与概述** | 识别当前打开的App，语音播报App名称、功能简介（如"当前在微信，这是一个聊天和社交应用"） |
| **界面结构描述** | 描述当前页面的整体布局结构（如"顶部是搜索框，下方有4个标签页：消息、通讯录、发现、我"） |
| **UI元素智能解读** | 对每个可交互元素（按钮、输入框、列表项等）提供智能语音描述，即使原App未做无障碍标注 |
| **图标/图片语义理解** | 对无文字描述的图标和图片，通过AI视觉识别其含义（如购物车图标→"购物车按钮"） |
| **页面导航辅助** | 告知用户当前在App的哪个层级，如何返回上一级或回到主页 |
| **操作引导** | 对常见操作提供语音引导（如"双击可以打开"、"向右滑动查看更多"） |
| **内容摘要** | 对长列表或复杂页面提供内容摘要（如"当前有12条未读消息，最新一条来自张三"） |

#### 2.6.2 技术路径

**采用双路径融合方案：**

**路径1 — 无障碍服务API（结构化数据）：**
- Android：通过 `AccessibilityService` 获取当前屏幕的UI节点树（View Hierarchy）
- iOS：通过 `UIAccessibility` 协议获取Accessibility元素树
- 提取每个元素的：类型、文本、内容描述、位置坐标、可操作性、层级关系
- 优点：数据结构化，速度快，可离线

**路径2 — 屏幕截图 + AI视觉理解（智能补充）：**
- 获取当前屏幕截图
- 调用多模态大模型（如GPT-4V、Qwen-VL等）进行视觉理解
- AI分析截图中的UI布局、图标含义、文字内容、整体功能推断
- 优点：不依赖App的无障碍标注，对所有App通用

**融合策略：**
1. 优先使用路径1获取结构化信息
2. 对于描述缺失或不清晰的元素（无content description、纯图标按钮），触发路径2的AI补充分析
3. 将两个路径的结果合并，生成完整的、人性化的语音描述
4. 引入缓存机制：对同一App同一页面的AI分析结果进行缓存，避免重复请求

#### 2.6.3 用户交互场景示例

```
用户说："我现在在哪个App？"
系统回复："当前在支付宝，这是一个支付和生活服务应用。
          页面顶部是搜索框，下面有扫一扫、收付款、出行、卡包等快捷功能按钮，
          中间是各种生活服务入口，底部有首页、理财、口碑、消息、我的五个标签栏，
          当前在首页标签。"

用户说："屏幕上有几个按钮？"
系统回复："当前页面有15个可点击的按钮。
          最上方是搜索框，点击可以搜索功能或服务。
          第一排有4个快捷按钮：扫一扫、收付款、出行、卡包..."

用户说："帮我找到付款功能"
系统回复："收付款按钮在页面顶部第二排，从左数第二个位置。
          你可以直接说'打开收付款'，我帮你点击。"
```

---

## 3. 技术栈选型

### 3.1 跨平台框架：Flutter + Dart

| 评估维度 | Flutter | React Native | KMP |
|---------|---------|-------------|-----|
| 无障碍支持 | ⭐⭐⭐⭐⭐ 内置Semantics系统 | ⭐⭐⭐ 依赖原生组件映射 | ⭐⭐⭐⭐ 原生组件 |
| 性能 | ⭐⭐⭐⭐⭐ Skia/Impeller直接渲染 | ⭐⭐⭐ JS Bridge有开销 | ⭐⭐⭐⭐⭐ 原生性能 |
| 摄像头/传感器生态 | ⭐⭐⭐⭐ 官方维护插件 | ⭐⭐⭐ 社区插件质量参差 | ⭐⭐⭐⭐ 原生API直接调用 |
| 开发效率 | ⭐⭐⭐⭐⭐ 热重载+单代码库 | ⭐⭐⭐⭐ 热重载+Web生态 | ⭐⭐⭐ 需处理平台差异 |
| 原生平台API调用 | ⭐⭐⭐ Platform Channel | ⭐⭐⭐ Native Module | ⭐⭐⭐⭐⭐ 直接调用 |
| 无障碍服务集成 | ⭐⭐⭐ 需通过Platform Channel | ⭐⭐⭐ 需要Native Module | ⭐⭐⭐⭐⭐ 原生集成 |

**最终选型：Flutter**

选型理由：
1. **无障碍支持最完善**：内置 `Semantics` Widget系统，可与iOS VoiceOver和Android TalkBack深度集成
2. **性能接近原生**：Skia/Impeller引擎直接渲染，摄像头预览帧处理延迟低
3. **传感器/摄像头插件生态成熟**：`camera`、`sensors_plus`、`geolocator` 等官方维护插件
4. **高效开发**：单代码库同时产出Android和iOS应用，热重载加速迭代
5. **App内容读取模块**：虽然需要通过 Platform Channel 调用原生无障碍API，但Flutter的Method Channel机制足够高效，且这部分逻辑天然需要在原生层实现

> **注意**：App内容读取模块中的 `AccessibilityService`(Android) 和 `UIAccessibility`(iOS) 的调用必须在原生层实现，通过Flutter Platform Channel桥接。这是该功能的唯一技术约束，但不影响Flutter框架选型的整体优势。

### 3.2 AI能力：混合端云方案

| 能力 | 部署位置 | 技术方案 | 理由 |
|-----|---------|---------|------|
| 障碍物检测 | **端侧** | TFLite (Android) + Core ML (iOS) | 安全关键，必须离线实时，延迟<100ms |
| 基础OCR | **端侧** | Google ML Kit (On-device) | 离线可用，中英文支持好 |
| 精细OCR/场景理解 | **云端** | 云端视觉大模型API | 复杂牌匾、手写体等需要更强模型 |
| 语音识别(ASR) | **混合** | 端侧Vosk + 云端讯飞/Google | 基础指令离线，复杂语义走云端 |
| 语音合成(TTS) | **端侧** | 系统原生TTS引擎 | 零延迟，离线可用 |
| **App界面AI解读** | **云端** | 多模态大模型（GPT-4V/Qwen-VL/通义千问） | 需要强大的视觉理解+语义推理能力 |
| **App界面结构解析** | **端侧** | 原生AccessibilityService/UIAccessibility | 结构化数据，速度快，离线可用 |

### 3.3 地图与导航

- **高德地图SDK**（国内场景）/ **Google Maps SDK**（海外场景）
- 步行导航API + POI搜索 + 地理编码/逆地理编码
- 实时定位：GPS + 网络定位 + IMU辅助

### 3.4 语音交互

- ASR：端侧使用 Vosk/Sherpa-ONNX（离线），云端使用讯飞/Google Speech API
- TTS：Android使用系统 `TextToSpeech`，iOS使用 `AVSpeechSynthesizer`
- 语音唤醒：Porcupine（端侧唤醒词引擎）

### 3.5 状态管理与架构

- 状态管理：**Riverpod**（类型安全，适合复杂状态）
- 架构模式：**Clean Architecture**（presentation → domain → data 三层结构）
- 依赖注入：**get_it + injectable**

---

## 4. 系统架构设计

### 4.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                        表现层 (Presentation)                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ 导航页面  │ │ 检测页面  │ │ OCR页面  │ │ 设置页面  │ │ App解读页│  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
│       │            │            │            │            │         │
│  ┌────┴────────────┴────────────┴────────────┴────────────┴─────┐  │
│  │              StateNotifier / Riverpod Providers               │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
├─────────────────────────────┼───────────────────────────────────────┤
│                        领域层 (Domain)                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ 导航用例  │ │ 检测用例  │ │ OCR用例  │ │ 语音用例  │ │ 解读用例  │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
│       │            │            │            │            │         │
│  ┌────┴────────────┴────────────┴────────────┴────────────┴─────┐  │
│  │                    事件总线 (Event Bus)                         │  │
│  │          跨模块通信 / 优先级播报队列 / 状态协调                    │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
├─────────────────────────────┼───────────────────────────────────────┤
│                        数据层 (Data)                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ 地图仓库  │ │ 摄像头仓库│ │ 传感器仓库│ │ AI推理仓库│ │ 解读仓库  │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
├───────┼────────────┼────────────┼────────────┼────────────┼─────────┤
│                   平台/基础设施层 (Infrastructure)                     │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────────┐  │
│  │地图SDK   │ │摄像头插件│ │传感器插件 │ │TFLite/  │ │Accessibility │  │
│  │(高德/   │ │(camera) │ │(sensors │ │ML Kit/  │ │Service API   │  │
│  │Google)  │ │         │ │_plus)   │ │Core ML  │ │(原生层桥接)   │  │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └──────────────┘  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────────────────────┐  │
│  │系统TTS  │ │ASR引擎  │ │唤醒词引擎│ │多模态大模型API            │  │
│  │         │ │         │ │         │ │(GPT-4V/Qwen-VL)          │  │
│  └─────────┘ └─────────┘ └─────────┘ └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 模块间通信架构

```
                    ┌─────────────────────┐
                    │   语音交互模块        │
                    │  (中央控制器)         │
                    └──┬───┬───┬───┬───┬──┘
                       │   │   │   │   │
          ┌────────────┘   │   │   │   └────────────┐
          ▼                ▼   │   ▼                ▼
   ┌──────────┐    ┌──────────┐│┌──────────┐  ┌──────────┐
   │ 导航模块  │    │ 检测模块  │││ OCR模块  │  │ App解读  │
   │          │    │          │││          │  │   模块    │
   └──────────┘    └──────────┘│└──────────┘  └──────────┘
                               │
                    ┌──────────┴──────────┐
                    │   事件总线           │
                    │  (Event Bus)        │
                    │  - 障碍物告警事件     │
                    │  - 导航指令事件       │
                    │  - OCR结果事件       │
                    │  - App解读结果事件    │
                    │  - 语音播报请求事件   │
                    └─────────────────────┘
```

### 4.3 App内容解读模块架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    App内容解读模块                                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 解读协调器 (ScreenReaderCoordinator)      │    │
│  │    - 接收用户请求（"我在哪个App？""屏幕上有什么？"）          │    │
│  │    - 协调两个数据源                                        │    │
│  │    - 合成最终的语音描述                                     │    │
│  └────────────┬──────────────────────┬──────────────────────┘    │
│               │                      │                          │
│    ┌──────────▼──────────┐  ┌───────▼────────────────┐         │
│    │  路径1: 无障碍API    │  │  路径2: 屏幕AI理解      │         │
│    │  (AccessibilitySvc) │  │  (Screen AI)            │         │
│    │                     │  │                         │         │
│    │  ┌───────────────┐  │  │  ┌──────────────────┐   │         │
│    │  │ Android:       │  │  │  │ 1. 截取屏幕      │   │         │
│    │  │ Accessibility  │  │  │  │ 2. 发送到云端    │   │         │
│    │  │ Service        │  │  │  │    大模型API     │   │         │
│    │  ├───────────────┤  │  │  │ 3. 接收AI分析    │   │         │
│    │  │ iOS:           │  │  │  │    结果          │   │         │
│    │  │ UIAccessibility│  │  │  │ 4. 结构化解析    │   │         │
│    │  └───────────────┘  │  │  └──────────────────┘   │         │
│    │                     │  │                         │         │
│    │  输出: UI节点树      │  │  输出: 语义化描述         │         │
│    │  - 元素类型          │  │  - 页面功能概述           │         │
│    │  - 文本内容          │  │  - 图标含义              │         │
│    │  - 位置坐标          │  │  - 交互建议              │         │
│    │  - 可操作性          │  │  - 内容摘要              │         │
│    └─────────────────────┘  └─────────────────────────┘         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   结果缓存层 (Cache)                      │    │
│  │    - 以 App包名 + Activity/ViewController名 为Key         │    │
│  │    - AI分析结果缓存30分钟                                  │    │
│  │    - 用户已知App常驻缓存                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │               App知识库 (App Knowledge Base)             │    │
│  │    - 预置常见App的功能描述和操作指引                        │    │
│  │    - 微信、支付宝、淘宝、抖音等高频App的页面模板             │    │
│  │    - 支持在线更新和用户贡献                                │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. 模块详细设计

### 5.1 导航模块 (Navigation)

#### 职责
提供完整的步行导航能力，从路线规划到实时导航引导，支持语音输入目的地。

#### 核心类
```dart
// 路线信息实体
class RouteInfo {
  final String destination;
  final double totalDistance;     // 总距离（米）
  final int estimatedMinutes;    // 预计时长（分钟）
  final List<RouteStep> steps;   // 导航步骤
  final List<SpecialSegment> specialSegments; // 特殊路段（台阶、斜坡等）
}

// 导航仓库接口
abstract class NavigationRepository {
  Future<RouteInfo> planRoute({required String destination});
  Stream<NavigationStep> startNavigation(RouteInfo route);
  Future<void> stopNavigation();
  Future<List<POI>> searchPOI(String keyword, {double radius = 1000});
}
```

#### 关键逻辑
- 偏航检测：每5秒检查当前位置与规划路线的偏差，超过30米触发重规划
- 特殊路段预警：在到达台阶/斜坡前20米提前播报
- 路口增强引导：使用方向+距离+地标的组合描述（"前方10米丁字路口左转，路口有一个红色邮筒"）

### 5.2 障碍物检测模块 (Obstacle Detection)

#### 职责
通过摄像头实时检测前方障碍物，评估距离和方位，触发多模态警报。

#### 核心类
```dart
// 障碍物实体
class Obstacle {
  final ObstacleType type;       // 类型（行人、车辆、台阶、坑洞、路障、柱子等）
  final double distance;          // 估算距离（米）
  final Direction direction;      // 相对方位（左前、正前、右前等）
  final double confidence;        // 检测置信度 0.0-1.0
  final Rect boundingBox;         // 在画面中的位置
  final DateTime detectedAt;      // 检测时间戳
}

// 检测仓库接口
abstract class DetectionRepository {
  Stream<List<Obstacle>> get obstacleStream;
  Future<void> startDetection({int targetFps = 15});
  Future<void> stopDetection();
  Future<void> updateDetectionConfig(DetectionConfig config);
}
```

#### 关键逻辑
- 帧采样策略：每3帧处理1帧，平衡精度与功耗
- 距离估算：通过物体在画面中的相对大小和位置估算距离（单目测距）
- 告警去重：同一障碍物在移出视野前不重复播报，除非距离显著变化
- 紧急制动：距离<1米的障碍物触发紧急震动+高优先级语音

### 5.3 OCR识别模块 (OCR Recognition)

#### 职责
识别摄像头画面中的文字信息，支持牌匾、路牌、菜单等多场景。

#### 核心类
```dart
// OCR结果实体
class OcrResult {
  final String text;              // 识别文本
  final Rect region;              // 文字在画面中的区域
  final double confidence;        // 置信度
  final String language;          // 识别语言
  final OcrSource source;         // 来源（端侧/云端）
}

// OCR仓库接口
abstract class OcrRepository {
  Future<List<OcrResult>> recognizeFromCamera();
  Future<List<OcrResult>> recognizeFromImage(Uint8List imageData);
  Stream<List<OcrResult>> get realtimeOcrStream; // 实时OCR流
}
```

#### 关键逻辑
- 端云降级策略：先尝试端侧ML Kit，若置信度低于0.7则自动切换云端精细模式
- 文字区域检测：先定位画面中的文字区域，再对局部进行OCR，提高准确率
- 结果过滤：过滤过短（<2字符）和低置信度的结果

### 5.4 语音交互模块 (Voice Interaction)

#### 职责
提供完整的语音交互能力，包括唤醒、指令识别、自然语言理解、语音反馈。

#### 核心类
```dart
// 语音指令实体
class VoiceCommand {
  final CommandType type;         // 指令类型
  final Map<String, dynamic> params; // 指令参数
  final double confidence;        // 识别置信度
  final String rawText;           // 原始文本
}

// 语音交互状态机
enum VoiceState {
  idle,              // 空闲状态
  wakeListening,     // 等待唤醒词
  commandListening,  // 监听指令
  processing,        // 处理中
  speaking,          // 语音播报中
}

// 播报优先级
enum FeedbackPriority {
  critical,          // 紧急障碍物警报（立即打断当前播报）
  navigation,        // 导航指令（排队等待）
  information,       // 一般信息（排队等待）
}
```

#### 关键逻辑
- 打断机制：用户说话时自动停止当前播报；`critical` 级别可打断所有其他播报
- 指令解析：支持精确指令和模糊指令两种模式
  - 精确："导航去人民医院"→直接触发导航
  - 模糊："我想去看病"→理解语义后搜索附近医院
- 上下文对话：支持多轮对话，如"导航去火车站"→"走哪条路？"→"最近的那条"

### 5.5 ⭐ App内容解读模块 (Screen Reader AI)

#### 职责
读取并智能解析手机上任何App的界面内容，为盲人用户提供完整的App使用体验。

#### 核心类
```dart
// 屏幕元素实体
class ScreenElement {
  final String id;                   // 元素唯一标识
  final ScreenElementType type;      // 元素类型（按钮、文本、输入框、图片、列表等）
  final String? text;                // 元素文本（如有）
  final String? contentDescription;  // 无障碍描述（如有）
  final Rect bounds;                 // 在屏幕上的位置和大小
  final bool isClickable;           // 是否可点击
  final bool isScrollable;          // 是否可滚动
  final bool isFocused;             // 是否获得焦点
  final List<ScreenElement> children; // 子元素
}

// App信息实体
class AppInfo {
  final String packageName;          // 包名
  final String appName;              // App名称
  final String? currentActivity;     // 当前页面（Android Activity名）
  final String? appCategory;         // App分类（社交、购物、工具等）
  final String? appDescription;      // App功能简介
}

// 页面解读结果
class ScreenReadResult {
  final AppInfo appInfo;             // App信息
  final String pageSummary;          // 页面概要描述
  final List<ScreenElement> elements; // 所有UI元素
  final List<InteractionHint> hints; // 操作提示
  final String? aiEnhancedDescription; // AI增强描述（来自云端大模型）
  final DateTime timestamp;
}

// 解读仓库接口
abstract class ScreenReaderRepository {
  /// 获取当前屏幕的完整解读
  Future<ScreenReadResult> readCurrentScreen();
  
  /// 获取当前App的基本信息
  Future<AppInfo> getCurrentAppInfo();
  
  /// 获取指定区域的详细解读（用户触摸某个位置时）
  Future<ScreenElement?> readElementAt(Offset position);
  
  /// AI增强解读（截图+大模型分析）
  Future<String> getAiEnhancedDescription(Uint8List screenshot);
  
  /// 执行操作（点击、滑动等）
  Future<bool> performAction(String elementId, AccessibilityAction action);
  
  /// 注册屏幕变化监听
  Stream<ScreenChangeEvent> get screenChangeStream;
}

// 屏幕变化事件
class ScreenChangeEvent {
  final ScreenChangeType type;       // 变化类型（窗口切换、内容更新、滚动等）
  final AppInfo? newApp;             // 新App信息（窗口切换时）
  final String? changeDescription;   // 变化描述
}
```

#### 关键逻辑

**1. 无障碍服务注册与权限**
```
Android端：
- 注册为AccessibilityService
- 在AndroidManifest.xml中声明service及配置
- 需要用户手动在系统设置中开启无障碍服务权限
- 使用TYPE_VIEW_SCROLLED, TYPE_WINDOW_STATE_CHANGED等事件监听页面变化

iOS端：
- 使用UIAccessibility API（有一定限制）
- 通过Accessibility Inspector获取的信息作为补充
- 注意：iOS的限制比Android大，更依赖路径2（截图+AI）
```

**2. 智能缓存机制**
```
缓存策略：
- L1缓存（内存）：当前App的当前页面解读结果，页面切换时自动更新
- L2缓存（本地存储）：常用App的AI分析结果，按包名+页面名索引，有效期24小时
- L3缓存（云端）：共享的App知识库，所有用户贡献的App操作指南
- 缓存失效：检测到App版本更新时清除该App缓存
```

**3. App知识库**
```
预置常用App模板：
- 微信：消息列表页、聊天页、朋友圈、支付页、小程序页等模板
- 支付宝：首页、扫码页、转账页、账单页等模板
- 淘宝/京东：首页、搜索结果页、商品详情页、购物车页等模板
- 抖音/快手：视频播放页、评论页、搜索页等模板
- 电话/短信/通讯录：系统应用的标准模板

模板包含：
- 页面结构描述
- 各区域功能说明
- 常见操作路径（如"微信发消息：消息标签→选择联系人→输入文字→发送"）
- 注意事项和操作技巧
```

**4. 用户意图理解**
```
用户可能的提问模式：
- "我在哪个App？" → 返回AppInfo概要
- "屏幕上有什么？" → 返回完整页面描述
- "这个按钮是做什么的？" → 解读用户当前焦点元素
- "帮我找到XX功能" → 搜索页面元素，引导用户定位
- "怎么发消息？" → 查询App知识库，提供操作指引
- "帮我点击XX" → 通过无障碍服务执行操作
```

### 5.6 无障碍优化模块 (Accessibility)

#### 职责
提供全局的无障碍配置和基础组件。

#### 关键设计
- 所有UI元素必须包含 `Semantics` 标注
- 最小触摸区域：56x56dp
- 高对比度配色方案（WCAG AAA级别，对比度≥7:1）
- 焦点管理：合理的Tab顺序和焦点流转逻辑
- 屏幕阅读器兼容：所有动态内容变化均通过 `SemanticsService.announce()` 通知

---

## 6. 数据流设计

### 6.1 主数据流（行走+导航+检测）

```
┌─────────┐     ┌──────────────┐     ┌───────────────┐     ┌──────────┐
│ 摄像头   │────▶│ Isolate      │────▶│ TFLite推理    │────▶│ 障碍物   │
│ 帧数据   │     │ 预处理       │     │ (端侧)        │     │ 检测结果  │
└─────────┘     └──────────────┘     └───────────────┘     └────┬─────┘
                                                                │
┌─────────┐     ┌──────────────┐                               │
│ GPS     │────▶│ 卡尔曼滤波   │────▶ 精确位置 ──┐              │
│ + IMU   │     │ 传感器融合    │               │              │
└─────────┘     └──────────────┘               │              │
                                               ▼              ▼
                                    ┌──────────────────────────────┐
                                    │      事件总线 (Event Bus)      │
                                    │  优先级：critical > nav > info │
                                    └──────────────┬───────────────┘
                                                   │
                                                   ▼
                                    ┌──────────────────────────────┐
                                    │    TTS 优先级队列              │
                                    │    语音播报 + 震动反馈          │
                                    └──────────────────────────────┘
```

### 6.2 App内容解读数据流

```
用户触发（语音/触摸）
        │
        ▼
┌───────────────────┐
│ 解读协调器         │
│ (Coordinator)     │
└───────┬───────────┘
        │
        ├─────────────────────────┐
        │                         │
        ▼                         ▼
┌───────────────┐      ┌─────────────────────┐
│ 路径1:         │      │ 路径2:               │
│ 无障碍API      │      │ 截图 + AI            │
│               │      │                     │
│ ┌───────────┐ │      │ ┌─────────────────┐ │
│ │ 获取UI     │ │      │ │ 1. 截取屏幕      │ │
│ │ 节点树     │ │      │ │ 2. 压缩/裁剪     │ │
│ ├───────────┤ │      │ │ 3. 上传云端      │ │
│ │ 解析元素   │ │      │ │ 4. 大模型分析    │ │
│ │ 类型+文本  │ │      │ │ 5. 返回描述      │ │
│ ├───────────┤ │      │ └─────────────────┘ │
│ │ 标记缺失   │ │      │                     │
│ │ 描述的元素 │ │      │ 仅对"缺失描述"的     │
│ └───────────┘ │      │ 区域请求AI补充        │
└───────┬───────┘      └──────────┬──────────┘
        │                         │
        └────────┬────────────────┘
                 │
                 ▼
        ┌────────────────┐
        │ 结果融合器      │
        │ (Merger)       │
        │                │
        │ 1. 合并两路数据  │
        │ 2. 查询知识库   │
        │ 3. 生成描述文案  │
        │ 4. 写入缓存     │
        └────────┬───────┘
                 │
                 ▼
        ┌────────────────┐
        │ TTS 语音播报    │
        └────────────────┘
```

### 6.3 OCR识别数据流

```
用户触发（"读一下"指令 / 手动打开OCR页面）
        │
        ▼
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│ 摄像头取景     │────▶│ ML Kit端侧OCR  │────▶│ 结果判断       │
│ (引导用户对准) │     │ (离线快速识别)  │     │ 置信度 ≥ 0.7?  │
└────────────────┘     └────────────────┘     └───┬────────┬───┘
                                                  │        │
                                            ≥0.7  │        │ <0.7
                                                  ▼        ▼
                                          ┌──────────┐ ┌──────────┐
                                          │ 直接播报  │ │ 云端精细  │
                                          │ 结果     │ │ OCR识别  │
                                          └──────────┘ └────┬─────┘
                                                            │
                                                            ▼
                                                     ┌──────────┐
                                                     │ 播报增强  │
                                                     │ 结果     │
                                                     └──────────┘
```

---

## 7. API接口设计

### 7.1 模块间内部API

#### 事件总线事件类型

```dart
// 基础事件类
abstract class AppEvent {
  final DateTime timestamp;
  final String sourceModule;
}

// 障碍物告警事件
class ObstacleAlertEvent extends AppEvent {
  final List<Obstacle> obstacles;
  final FeedbackPriority priority;
}

// 导航指令事件
class NavigationEvent extends AppEvent {
  final NavigationStep step;
  final bool isDeviationAlert;
}

// OCR结果事件
class OcrResultEvent extends AppEvent {
  final List<OcrResult> results;
}

// 语音播报请求事件
class SpeakRequestEvent extends AppEvent {
  final String text;
  final FeedbackPriority priority;
  final bool interruptCurrent;
}

// App解读结果事件
class ScreenReadEvent extends AppEvent {
  final ScreenReadResult result;
  final ScreenReadRequestType requestType; // 概要/详细/某个元素
}

// 屏幕变化事件
class ScreenChangedEvent extends AppEvent {
  final ScreenChangeEvent change;
}
```

### 7.2 云端API接口

#### AI视觉理解API

```
POST /api/v1/vision/analyze
Request:
{
  "image": "base64_encoded_screenshot",
  "task": "screen_understanding",     // 或 "ocr_fine", "scene_understanding"
  "context": {
    "app_name": "支付宝",
    "platform": "android",
    "locale": "zh-CN"
  }
}
Response:
{
  "description": "这是支付宝的首页...",
  "elements": [...],
  "interaction_hints": [...],
  "confidence": 0.92
}
```

#### 精细OCR API

```
POST /api/v1/ocr/recognize
Request:
{
  "image": "base64_encoded_image",
  "mode": "fine",         // "fast" | "fine"
  "languages": ["zh", "en"]
}
Response:
{
  "results": [
    {"text": "人民医院急诊入口", "confidence": 0.98, "region": {...}}
  ]
}
```

### 7.3 Platform Channel接口（Flutter ↔ 原生）

#### Android AccessibilityService Channel

```dart
// Flutter端调用
const channel = MethodChannel('com.blindassist/accessibility');

// 获取当前屏幕UI树
final Map result = await channel.invokeMethod('getScreenElements');

// 获取当前App信息
final Map appInfo = await channel.invokeMethod('getCurrentAppInfo');

// 对指定元素执行操作
await channel.invokeMethod('performAction', {
  'nodeId': elementId,
  'action': 'click',  // click, scroll_forward, scroll_backward, focus
});

// 监听屏幕变化
channel.setMethodCallHandler((call) {
  if (call.method == 'onScreenChanged') {
    // 处理屏幕变化事件
  }
});
```

#### iOS UIAccessibility Channel

```dart
const channel = MethodChannel('com.blindassist/ios_accessibility');

// 获取当前可访问的UI元素
final List elements = await channel.invokeMethod('getAccessibilityElements');

// 获取当前App信息
final Map appInfo = await channel.invokeMethod('getCurrentAppInfo');
```

---

## 8. 传感器融合方案

### 8.1 传感器组合

| 传感器 | 用途 | 数据频率 |
|-------|------|---------|
| GPS | 室外定位 | 1Hz |
| 加速度计 | 运动状态检测 | 50Hz |
| 陀螺仪 | 方向和姿态 | 50Hz |
| 磁力计 | 朝向（指南针） | 10Hz |
| 气压计 | 楼层变化 | 1Hz |
| 摄像头 | 视觉检测 | 15-30fps |
| LiDAR（如有） | 精确测距 | 设备依赖 |

### 8.2 融合算法

```
GPS原始数据 ─────┐
                 │     ┌─────────────────┐
IMU数据 ─────────┼────▶│  扩展卡尔曼滤波  │────▶ 精确位置 + 朝向
（加速度+陀螺仪） │     │  (EKF)           │
                 │     └─────────────────┘
磁力计数据 ──────┘
                        ┌─────────────────┐
加速度计 ──────────────▶│  步态检测算法    │────▶ 行走/静止/跑步 状态
                        │  (Peak Detection)│
                        └─────────────────┘
                        ┌─────────────────┐
气压计 ────────────────▶│  楼层变化检测    │────▶ 上楼/下楼 事件
                        │  (阈值法)        │
                        └─────────────────┘
```

### 8.3 智能功耗管理

| 用户状态 | 摄像头帧率 | GPS频率 | AI推理频率 | 预估功耗 |
|---------|-----------|---------|-----------|---------|
| 静止 | 5fps | 0.2Hz | 每5秒1次 | 低 |
| 慢走 | 15fps | 1Hz | 每秒3帧 | 中 |
| 快走/跑步 | 30fps | 1Hz | 每秒10帧 | 高 |
| 省电模式 | 关闭 | 0.5Hz | 仅语音 | 最低 |

---

## 9. 无障碍设计规范

### 9.1 语义标注规范

```dart
// 所有可交互元素必须包含完整语义
Semantics(
  label: '导航',                    // 元素名称
  hint: '双击开始语音导航',          // 操作提示
  button: true,                    // 元素角色
  enabled: true,                   // 是否可用
  onTap: () => startNavigation(),
  child: NavigationButton(),
)
```

### 9.2 触觉反馈规范

| 事件 | 震动模式 | 说明 |
|-----|---------|------|
| 普通障碍物（>3m） | 短震一次 | 100ms |
| 近距障碍物（1-3m） | 短震两次 | 100ms-50ms-100ms |
| 紧急障碍物（<1m） | 持续震动 | 500ms连续 |
| 导航转弯提示 | 短震三次 | 50ms×3 |
| 操作确认 | 轻微震动 | 30ms |

### 9.3 语音播报规范

| 场景 | 播报规则 | 示例 |
|-----|---------|------|
| 障碍物检测 | 方位+距离+类型 | "正前方3米有台阶" |
| 导航指令 | 距离+方向+地标 | "前方20米路口右转，路口有红绿灯" |
| OCR结果 | 直接朗读文字 | "牌匾写着：人民医院急诊入口" |
| App解读 | 页面概要→逐元素 | "当前在微信消息列表，共有5条未读" |
| 错误提示 | 原因+建议操作 | "网络连接失败，请检查WiFi后重试" |

### 9.4 App解读播报规范

| 场景 | 播报策略 | 示例 |
|-----|---------|------|
| App切换 | 自动播报App名称和概述 | "已切换到微信，这是一个聊天和社交应用" |
| 页面切换 | 自动播报页面名称和主要内容 | "已进入通讯录页面，共有128个联系人" |
| 用户询问 | 详细描述当前页面 | "当前页面从上到下依次是：搜索框、功能按钮区..." |
| 焦点元素 | 描述当前焦点元素的功能 | "这是扫一扫按钮，用于扫描二维码进行支付或添加好友" |
| 操作引导 | 告知如何执行操作 | "您可以说'打开'来点击这个按钮，或说'下一个'切换到下一个元素" |

---

## 10. 性能与安全考量

### 10.1 性能目标

| 指标 | 目标值 | 说明 |
|-----|-------|------|
| 障碍物检测延迟 | <100ms | 从帧获取到结果输出 |
| OCR识别延迟（端侧） | <500ms | 单帧识别 |
| OCR识别延迟（云端） | <2s | 含网络传输 |
| 语音响应延迟 | <300ms | 从唤醒到开始监听 |
| TTS播报延迟 | <100ms | 从触发到开始播放 |
| App解读延迟（结构化） | <200ms | 无障碍API获取 |
| App解读延迟（AI增强） | <3s | 含截图上传和推理 |
| 帧率（检测模式） | ≥15fps | 最低可接受帧率 |
| 内存占用 | <300MB | 常驻内存 |
| App冷启动时间 | <3s | 到可交互状态 |

### 10.2 安全策略

| 安全维度 | 策略 |
|---------|------|
| **隐私保护** | 摄像头数据仅在内存中处理，不持久化；App截图分析完立即删除 |
| **数据传输** | 所有云端API通信使用HTTPS + 请求签名 |
| **检测兜底** | 置信度低于阈值时主动提醒"检测不确定，请谨慎前行" |
| **离线安全** | 所有安全关键功能必须离线可用 |
| **权限最小化** | 仅申请必要权限，明确告知用途 |
| **无障碍权限** | App解读功能需要AccessibilityService权限，在首次使用时通过语音引导用户开启，并清晰说明权限用途 |
| **截图安全** | 屏幕截图数据不存储、不缓存文件，仅在内存中处理后立即释放；敏感App（银行、支付界面）进行特殊处理 |

### 10.3 敏感界面保护

```
对于银行App、支付密码页等敏感界面：
1. 检测到金融类App时，自动禁用截图+AI分析功能
2. 仅使用无障碍API获取非密码类元素信息
3. 密码输入区域不读取内容，仅告知"这是密码输入框"
4. 用户可在设置中配置"敏感App白名单"
```

---

## 11. 第三方SDK集成方案

### 11.1 SDK清单

| SDK | 平台 | 用途 | 许可证 |
|-----|------|------|-------|
| 高德地图SDK | Android+iOS | 导航、定位、POI | 商业（申请Key） |
| Google Maps SDK | Android+iOS | 海外导航备选 | 商业（API Key） |
| TensorFlow Lite | Android+iOS | 端侧AI推理 | Apache 2.0 |
| Core ML | iOS | 端侧AI推理 | Apple |
| Google ML Kit | Android+iOS | 端侧OCR | Google ToS |
| Vosk | Android+iOS | 离线语音识别 | Apache 2.0 |
| Porcupine | Android+iOS | 唤醒词引擎 | 商业（有免费额度） |
| 讯飞SDK | Android+iOS | 云端ASR/TTS | 商业 |

### 11.2 Flutter插件依赖

```yaml
dependencies:
  # 核心框架
  flutter_riverpod: ^2.4.0     # 状态管理
  get_it: ^7.6.0               # 依赖注入
  injectable: ^2.3.0           # DI代码生成
  go_router: ^13.0.0           # 路由管理
  
  # 摄像头与传感器
  camera: ^0.10.5              # 摄像头
  sensors_plus: ^4.0.0         # 传感器
  geolocator: ^11.0.0         # GPS定位
  
  # AI推理
  tflite_flutter: ^0.10.4     # TFLite推理
  google_mlkit_text_recognition: ^0.11.0  # ML Kit OCR
  
  # 地图
  amap_flutter_map: ^3.0.0    # 高德地图
  amap_flutter_location: ^3.0.0 # 高德定位
  
  # 语音
  speech_to_text: ^6.6.0      # ASR
  flutter_tts: ^3.8.0         # TTS
  
  # 工具
  permission_handler: ^11.1.0 # 权限管理
  vibration: ^1.8.0           # 震动反馈
  connectivity_plus: ^5.0.0   # 网络状态
  hive: ^2.2.3                # 本地存储（缓存）
  
  # 无障碍增强
  flutter_accessibility_service: ^0.3.0  # Android无障碍服务桥接
  screen_capturer: ^0.1.0               # 屏幕截图（App解读用）
```

---

## 12. 目录结构

```
blind_assist_app/
├── android/                              # Android平台原生代码
│   └── app/src/main/
│       ├── java/.../
│       │   ├── accessibility/            # [NEW] Android AccessibilityService实现
│       │   │   ├── BlindAssistAccessibilityService.java  # 核心无障碍服务
│       │   │   └── ScreenElementParser.java              # UI节点树解析器
│       │   └── channels/                 # [NEW] Platform Channel原生端
│       │       └── AccessibilityChannel.java             # 无障碍API通道
│       ├── AndroidManifest.xml           # 含AccessibilityService声明
│       └── res/xml/
│           └── accessibility_service_config.xml  # [NEW] 无障碍服务配置
├── ios/                                  # iOS平台原生代码
│   └── Runner/
│       ├── Accessibility/                # [NEW] iOS无障碍功能实现
│       │   ├── AccessibilityBridge.swift # UIAccessibility桥接
│       │   └── ScreenAnalyzer.swift      # 屏幕分析器
│       └── Channels/
│           └── AccessibilityChannel.swift # Platform Channel iOS端
├── assets/                               # 静态资源
│   ├── models/                           # AI模型文件（TFLite模型）
│   ├── sounds/                           # 提示音文件（警报音、提示音）
│   ├── i18n/                             # 国际化文件（中文/英文）
│   └── app_knowledge/                    # [NEW] App知识库数据
│       ├── wechat.json                   # 微信操作指南
│       ├── alipay.json                   # 支付宝操作指南
│       └── common_apps.json              # 常用App基础信息
├── lib/                                  # Dart源代码主目录
│   ├── main.dart                         # 应用入口
│   ├── app.dart                          # MaterialApp配置
│   ├── core/                             # 核心公共层
│   │   ├── di/
│   │   │   └── injection.dart            # 依赖注入配置
│   │   ├── event_bus/
│   │   │   └── event_bus.dart            # 跨模块事件总线
│   │   ├── accessibility/
│   │   │   ├── a11y_config.dart          # 全局无障碍配置
│   │   │   └── a11y_widgets.dart         # 封装的无障碍基础组件
│   │   ├── utils/
│   │   │   ├── permission_handler.dart   # 统一权限请求管理
│   │   │   ├── haptic_feedback.dart      # 震动反馈工具类
│   │   │   └── logger.dart               # 日志工具
│   │   └── constants/
│   │       └── app_constants.dart        # 全局常量定义
│   ├── features/                         # 功能模块目录
│   │   ├── navigation/                   # 导航模块
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── route_info.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── navigation_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── plan_route.dart
│   │   │   │       └── start_navigation.dart
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   └── map_sdk_datasource.dart
│   │   │   │   └── repositories/
│   │   │   │       └── navigation_repository_impl.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── navigation_provider.dart
│   │   │       ├── pages/
│   │   │       │   └── navigation_page.dart
│   │   │       └── widgets/
│   │   │           └── route_info_widget.dart
│   │   ├── obstacle_detection/           # 障碍物检测模块
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── obstacle.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── detection_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       └── detect_obstacles.dart
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   ├── camera_datasource.dart
│   │   │   │   │   └── tflite_datasource.dart
│   │   │   │   └── repositories/
│   │   │   │       └── detection_repository_impl.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── detection_provider.dart
│   │   │       └── widgets/
│   │   │           └── detection_overlay.dart
│   │   ├── ocr_recognition/              # OCR识别模块
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── ocr_result.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── ocr_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       └── recognize_text.dart
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   ├── mlkit_ocr_datasource.dart
│   │   │   │   │   └── cloud_ocr_datasource.dart
│   │   │   │   └── repositories/
│   │   │   │       └── ocr_repository_impl.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── ocr_provider.dart
│   │   │       └── pages/
│   │   │           └── ocr_page.dart
│   │   ├── voice_interaction/            # 语音交互模块
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── voice_command.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── voice_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── process_command.dart
│   │   │   │       └── speak_feedback.dart
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   ├── asr_datasource.dart
│   │   │   │   │   ├── tts_datasource.dart
│   │   │   │   │   └── wake_word_datasource.dart
│   │   │   │   └── repositories/
│   │   │   │       └── voice_repository_impl.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── voice_provider.dart
│   │   │       └── widgets/
│   │   │           └── voice_indicator.dart
│   │   ├── screen_reader/                # ⭐ [NEW] App内容解读模块
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── screen_element.dart      # 屏幕元素实体
│   │   │   │   │   ├── app_info.dart             # App信息实体
│   │   │   │   │   └── screen_read_result.dart   # 解读结果实体
│   │   │   │   ├── repositories/
│   │   │   │   │   └── screen_reader_repository.dart  # 解读仓库接口
│   │   │   │   └── usecases/
│   │   │   │       ├── read_current_screen.dart  # 读取当前屏幕用例
│   │   │   │       ├── get_app_info.dart          # 获取App信息用例
│   │   │   │       ├── read_element_detail.dart   # 读取元素详情用例
│   │   │   │       ├── find_element.dart           # 搜索元素用例
│   │   │   │       └── perform_action.dart         # 执行操作用例
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   ├── accessibility_api_datasource.dart  # 无障碍API数据源
│   │   │   │   │   ├── screen_ai_datasource.dart          # 屏幕AI分析数据源
│   │   │   │   │   └── app_knowledge_datasource.dart      # App知识库数据源
│   │   │   │   ├── repositories/
│   │   │   │   │   └── screen_reader_repository_impl.dart # 解读仓库实现
│   │   │   │   └── cache/
│   │   │   │       └── screen_read_cache.dart             # 解读结果缓存
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   └── screen_reader_provider.dart        # 解读状态管理
│   │   │       ├── pages/
│   │   │       │   └── screen_reader_page.dart            # 解读设置/状态页面
│   │   │       └── widgets/
│   │   │           └── app_element_list.dart               # 元素列表展示组件
│   │   └── home/                         # 主页模块
│   │       └── presentation/
│   │           └── pages/
│   │               └── home_page.dart
│   └── shared/                           # 共享组件
│       ├── widgets/
│       │   ├── accessible_button.dart
│       │   └── high_contrast_text.dart
│       └── theme/
│           └── app_theme.dart
├── test/                                 # 测试目录
│   ├── features/
│   │   ├── navigation/
│   │   ├── obstacle_detection/
│   │   ├── ocr_recognition/
│   │   ├── voice_interaction/
│   │   └── screen_reader/               # ⭐ [NEW] App解读模块测试
│   └── core/
├── docs/                                 # 文档目录
│   └── technical_architecture.md         # 本文档
├── pubspec.yaml                          # Flutter项目依赖配置
├── analysis_options.yaml                 # Dart静态分析规则
└── README.md                             # 项目说明文档
```

---

## 附录A：常见问题与决策记录

### Q1: 为什么选Flutter而不是原生双端开发？
**A**: 虽然App解读功能需要深入原生API，但这只是一个模块。其他5个模块（导航、检测、OCR、语音、主页）使用Flutter可以实现一次开发双端运行，整体效率提升60%+。原生部分通过Platform Channel桥接即可。

### Q2: iOS上App解读功能的限制？
**A**: iOS不像Android有 `AccessibilityService` 那么开放的API，无法直接获取其他App的UI树。主要依赖路径2（截图+AI理解）。但iOS的VoiceOver体系本身比Android的TalkBack更完善，一定程度上弥补了这个限制。

### Q3: 如何处理AI识别的延迟？
**A**: 采用"先速后准"策略：先用端侧模型给出快速结果播报，后台异步请求云端精细结果，如果云端结果与端侧差异大则补充播报。

### Q4: App解读功能的隐私风险？
**A**: 所有截图数据仅在内存中处理，不存储；对银行/支付类App自动禁用截图分析；用户可自行配置敏感App名单；云端传输全程加密。

---

## 附录B：App解读功能的Android/iOS实现差异

| 维度 | Android | iOS |
|------|---------|-----|
| 系统API | AccessibilityService（功能强大） | UIAccessibility（有限制） |
| 获取UI树 | 可获取完整节点树 | 仅可获取标记为Accessible的元素 |
| 执行操作 | 可代理点击、滑动等操作 | 受限，仅可通过VoiceOver API |
| 权限获取 | 需手动开启无障碍服务 | 相对宽松 |
| 截图能力 | MediaProjection API | 受限，需特殊处理 |
| 推荐主路径 | 路径1（无障碍API）为主 | 路径2（截图+AI）为主 |

---

*文档结束。后续将基于此架构文档搭建Flutter项目工程骨架。*
