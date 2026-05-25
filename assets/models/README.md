# AI 模型文件目录

本目录存放端侧 AI 推理使用的 TFLite 模型文件。

## 需要放入的模型

### 1. 障碍物检测模型
- **文件名**：`obstacle_detection.tflite`
- **推荐模型**：MobileNet-SSD v2 / YOLOv8n
- **输入尺寸**：320×320 RGB
- **输出**：检测框 + 类别 + 置信度
- **大小约束**：< 10MB
- **下载来源**：
  - TensorFlow Hub: https://tfhub.dev/
  - YOLOv8: https://github.com/ultralytics/ultralytics

### 2. 障碍物类别标签
- **文件名**：`obstacle_labels.txt`
- **格式**：每行一个类别（与模型输出顺序对应）
- 例如：person / car / bicycle / step / hole / pole...

### 3. OCR 模型（可选，如不使用 ML Kit）
- **文件名**：`ocr_text_detection.tflite`

## 注意事项

- 模型文件较大，建议通过 Git LFS 管理或首次启动时从云端下载
- 当前为空目录，模型将在 MVP 开发阶段下载填充
- 不要提交大型 `.tflite` 文件到 Git 仓库
