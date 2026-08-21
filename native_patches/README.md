# Native patches

该目录保存 `tgortcflutter` 仓库之外的 HarmonyOS 原生源码改动，构建不会自动应用这些文件。
当前发布的 `dist/flutter_webrtc.har` 已包含下列补丁；本目录用于源码审查和后续从上游仓库重建。

## 目标仓库与应用顺序

在 `../fluttertpc_flutter_webrtc` 根目录应用：

```bash
git apply ../tgortcflutter/native_patches/flutter_webrtc_sender_identity.patch
```

在 `../ohos_webrtc` 根目录依次应用：

```bash
git apply ../tgortcflutter/native_patches/ohos_webrtc_first_frame_fallback.patch
git apply ../tgortcflutter/native_patches/ohos_webrtc_fast_preview.patch
git apply ../tgortcflutter/native_patches/ohos_webrtc_back_preview_rotation.patch
git apply ../tgortcflutter/native_patches/ohos_webrtc_receive_backpressure.patch
```

`ohos_webrtc_receive_backpressure.patch` 是接收端实时性保护：编码帧积压超过15帧时丢弃旧队列、请求关键帧，并在关键帧到达前拒绝继续积压依赖帧。日志前缀为 `[OhosReceive][Backpressure]`。

应用 `ohos_webrtc` 补丁后必须重新生成 `libohos_webrtc.so`，替换到 `fluttertpc_flutter_webrtc/ohos/libs/arm64-v8a/`，再重新构建并交付 `flutter_webrtc.har`。仅复制 `.patch` 文件不会改变运行行为。
