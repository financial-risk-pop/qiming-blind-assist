#!/bin/bash
# ============================================================
# BlindAssist - AI 模型下载脚本
# 
# 下载并放置所有需要的 TFLite 模型到 assets/models/
# 
# 使用方式：
#   cd blind_assist_app
#   bash scripts/download_models.sh
# ============================================================

set -e

MODELS_DIR="$(dirname "$0")/../assets/models"
mkdir -p "$MODELS_DIR"

echo "📦 开始下载 AI 模型到: $MODELS_DIR"

# ================================================
# 1. 障碍物检测模型（MobileNet-SSD v2 精简版）
# ================================================
# 来源：TensorFlow Lite 官方模型库
# 用途：实时行人/车辆/物体检测
# 大小：~ 3.5 MB
# ================================================
MODEL_URL_DETECTION="https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/2?lite-format=tflite"
MODEL_FILE_DETECTION="$MODELS_DIR/obstacle_detection.tflite"

if [ ! -f "$MODEL_FILE_DETECTION" ]; then
    echo "⬇️  下载障碍物检测模型..."
    curl -L "$MODEL_URL_DETECTION" -o "$MODEL_FILE_DETECTION" --progress-bar
    echo "✅ 障碍物检测模型已保存: $MODEL_FILE_DETECTION"
else
    echo "✔️  障碍物检测模型已存在，跳过下载"
fi

# ================================================
# 2. 障碍物分类标签（COCO 数据集 91 类）
# ================================================
LABELS_FILE="$MODELS_DIR/obstacle_labels.txt"
if [ ! -f "$LABELS_FILE" ]; then
    echo "⬇️  生成障碍物标签文件..."
    cat > "$LABELS_FILE" << 'EOF'
???
person
bicycle
car
motorcycle
airplane
bus
train
truck
boat
traffic light
fire hydrant
???
stop sign
parking meter
bench
bird
cat
dog
horse
sheep
cow
elephant
bear
zebra
giraffe
???
backpack
umbrella
???
???
handbag
tie
suitcase
frisbee
skis
snowboard
sports ball
kite
baseball bat
baseball glove
skateboard
surfboard
tennis racket
bottle
???
wine glass
cup
fork
knife
spoon
bowl
banana
apple
sandwich
orange
broccoli
carrot
hot dog
pizza
donut
cake
chair
couch
potted plant
bed
???
dining table
???
???
toilet
???
tv
laptop
mouse
remote
keyboard
cell phone
microwave
oven
toaster
sink
refrigerator
???
book
clock
vase
scissors
teddy bear
hair drier
toothbrush
EOF
    echo "✅ 标签文件已保存: $LABELS_FILE"
else
    echo "✔️  标签文件已存在，跳过生成"
fi

# ================================================
# 3. 语音唤醒词模型（占位，实际需要 Porcupine Key）
# ================================================
WAKE_PLACEHOLDER="$MODELS_DIR/wake_word_placeholder.txt"
if [ ! -f "$WAKE_PLACEHOLDER" ]; then
    cat > "$WAKE_PLACEHOLDER" << 'EOF'
# 唤醒词模型占位说明
# 
# Porcupine 唤醒词引擎需要付费 Access Key
# 申请地址：https://console.picovoice.ai/
# 
# 获得 Key 后：
# 1. 下载中文 "小助手" 的 .ppn 唤醒词模型
# 2. 重命名为 wake_word.ppn 放入本目录
# 3. 将 Access Key 填入 lib/core/constants/app_constants.dart
EOF
    echo "✅ 唤醒词占位说明已生成"
fi

# ================================================
# 4. 校验
# ================================================
echo ""
echo "📊 模型目录总览："
ls -lh "$MODELS_DIR"

echo ""
echo "✅ 所有模型准备完成！下一步：flutter pub get && flutter build apk --debug"
