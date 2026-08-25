# Native patches

该目录保存 `tgortcflutter` 仓库之外的 HarmonyOS 原生源码改动，构建不会自动应用这些文件。
当前发布的 `dist/flutter_webrtc.har` 已包含下列补丁；本目录用于源码审查和后续从上游仓库重建。

## 目标仓库与应用顺序

在 `../fluttertpc_flutter_webrtc` 根目录应用：

```bash
git apply ../tgortcflutter/native_patches/flutter_webrtc_sender_identity.patch
git apply ../tgortcflutter/native_patches/flutter_webrtc_foreground_stats.patch
```

在 `../ohos_webrtc` 根目录依次应用：

```bash
git apply ../tgortcflutter/native_patches/ohos_webrtc_first_frame_fallback.patch
git apply ../tgortcflutter/native_patches/ohos_webrtc_fast_preview.patch
git apply ../tgortcflutter/native_patches/ohos_webrtc_back_preview_rotation.patch
git apply ../tgortcflutter/native_patches/ohos_webrtc_receive_backpressure.patch
git apply ../tgortcflutter/native_patches/ohos_webrtc_foreground_camera_recovery.patch
```

`ohos_webrtc_receive_backpressure.patch` 是接收端实时性保护：编码帧积压超过15帧时丢弃旧队列、请求关键帧，并在关键帧到达前拒绝继续积压依赖帧。日志前缀为 `[OhosReceive][Backpressure]`。

`flutter_webrtc_sender_identity.patch` 修复 HarmonyOS `RTCRtpSender.id` 为 `undefined` 时所有 Sender 都退化为固定 `senderId` 的问题。它使用初始 Track ID 建立稳定 Sender 缓存，并输出 `[SenderIdentity] cache/replace` 日志；摄像头切换必须看到 `replace SUCCESS`，本地预览有帧不能替代 Sender 验收。

`flutter_webrtc_foreground_stats.patch` 增加 Ability 前后台通知和 `MediaStreamTrack.restartCapture()` 调用，同时修复 Stats report 未加入返回数组及逐字段 Info 日志刷屏。`ohos_webrtc_foreground_camera_recovery.patch` 在采集线程中强制释放锁屏后失效的 Camera Session/Input/Output，保持原 Track 与 RTP Sender 不变并重建摄像头；只有收到真实首帧才输出 `[OhosCapture][ForegroundRecovery] FIRST_FRAME`。

应用 `ohos_webrtc` 补丁后必须重新生成 `libohos_webrtc.so`，替换到 `fluttertpc_flutter_webrtc/ohos/libs/arm64-v8a/`，再重新构建并交付 `flutter_webrtc.har`。仅复制 `.patch` 文件不会改变运行行为。
