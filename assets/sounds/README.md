# 提示音文件目录

本目录存放 App 使用的提示音效文件。

## 需要准备的音效

| 文件名 | 用途 | 时长建议 |
|-------|------|---------|
| `alert_critical.mp3` | 紧急障碍物警报 | 0.3s |
| `alert_warning.mp3` | 普通障碍物提醒 | 0.2s |
| `notify_info.mp3` | 信息提示音 | 0.2s |
| `voice_wake.mp3` | 语音唤醒成功 | 0.15s |
| `voice_start.mp3` | 开始监听 | 0.1s |
| `voice_end.mp3` | 结束监听 | 0.1s |
| `success.mp3` | 操作成功 | 0.3s |
| `error.mp3` | 错误提示 | 0.3s |

## 设计规范

- 采样率：44.1kHz
- 格式：MP3 或 OGG
- 单个文件 < 50KB
- 不同音效有明显辨识度（盲人用户需要通过音色区分）
- 避免刺耳频率（>4kHz 高音）

## 获取来源建议

- freesound.org（CC0 授权音效库）
- 使用 AI 生成工具（如 ElevenLabs Sound Effects）
- 自行录制
