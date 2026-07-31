# 鸿蒙 XComponent 视频尺寸诊断与集成说明

## 当前渲染路线

RTC 视频默认使用 ArkTS `XComponentType.SURFACE`：

```text
ArkTS RTCVideoSurface
  -> XComponentController.getXComponentSurfaceId()
  -> TgoRTC.attachVideoSurface(...)
  -> Flutter RTCVideoRenderer.bindExternalSurface(...)
  -> libohos_webrtc.so / NativeWindowRendererGl
  -> XComponent Surface
```

该路线不依赖 Flutter Texture、`ImageReceiver` 或 Flutter Engine 的 external texture。Flutter
Texture 保留为未传入 `surfaceId` 时的插件备用能力；它不会在 XComponent renderer 创建时自动初始化，
因此不会再异步覆盖已绑定的 XComponent Surface。

## 尺寸与 object-fit 的职责

- ArkTS `.width('100%').height('100%')` 决定 XComponent 的布局矩形。
- `RenderFit.RESIZE_COVER` 仅影响 ArkUI 对 Surface 的布局/缓冲区策略，**不等同于**视频 `cover`。
- `fit: 'cover'` 会传至 native 的 `ASPECT_FILL`（缩放模式 `1`）；视频等比填满 Surface，超出部分裁切。
- `fit: 'contain'` 会传至 native 的 `ASPECT_FIT`（缩放模式 `2`）；视频完整显示，剩余区域为背景。
- 视频内容的最终裁切由 `NativeWindowRendererGl` 依据 EGL Surface 的实际像素尺寸计算 viewport。

因此，禁止用 ArkTS `.scale()`、人为放大 16:9 XComponent 或重建成员格子来模拟裁切。

## 新增诊断日志

SDK 在几何、视频帧分辨率、旋转、fit 或最终 viewport 变化时，输出一条 native 日志：

```text
[XComponentVideo] surfaceId=<id> frame=1280x720 rotation=0 \
surface=196x196 scaleMode=1 viewport=0,0,196x196 textureCrop=0.5625x1
```

字段含义：

| 字段 | 来源 | 用途 |
| --- | --- | --- |
| `frame` | WebRTC 解码帧 | 判断视频原始比例。 |
| `surface` | EGL 当前 Surface 像素尺寸 | 判断 XComponent 的底层 Buffer 是否真正完成 resize。 |
| `scaleMode` | `1=cover`，`2=contain` | 判断 fit 是否已进入 native renderer。 |
| `viewport` | native 最终绘制区域 | cover 路线始终等于 Surface，避免系统再次按 FIT 合成。 |
| `textureCrop` | native 输入纹理的有效采样范围 | 小于 `1` 的方向会中心裁切，保证等比 cover。 |

同时，集成方的 `RTCVideoSurface.onAreaChange` 应保留布局日志，例如：

```text
surface area: uid=<uid>, surface=<id>, size=195.56x195.56, fit=cover
```

## 如何判断问题位置

以 1280×720 视频放入正方形格子为例：

| ArkTS area | native `surface` | `scaleMode` / `viewport` | 结论 |
| --- | --- | --- | --- |
| 正方形 | 正方形 | `1` 且 `textureCrop` 横向小于 `1` | native 已执行 cover；若仍异常，再检查设备合成。 |
| 正方形 | 16:9 | 任意 | XComponent 可见布局变了，但底层 EGL/Buffer 未 resize；问题在 Surface/系统或 native window 生命周期。 |
| 正方形 | 正方形 | `0` 或 `2` | fit 未正确下发或被 renderer 重置。 |
| 正方形 | 正方形 | `1` 但 `textureCrop=1x1` | 需检查实际运行的 `libohos_webrtc.so` 是否包含此版本的裁切算法。 |

验收 `cover` 时应看到无上下黑边、画面等比、左右裁切；切为 `contain` 后才允许上下黑边。

## 鸿蒙本地上行画面被压缩：采集矩阵诊断与修复

若 Android 和鸿蒙都只在接收**鸿蒙发布者**时看到画面上下压缩，问题不在 XComponent、ArkTS
布局或接收端。应检查相机上行链路：

```text
Camera PreviewOutput -> NativeImage OES texture -> capture transform
-> TextureBuffer::ToI420 -> libvpx/H.264 encoder -> RTP
```

API 15 的 `OH_NativeImage_GetBufferMatrix()` 包含生产者变换及 Buffer 的有效裁切区域；原来的
`GetTransformMatrixV2()` 只读取生产者变换。相机驱动将 16:9 可见画面放在经对齐的较大 Buffer 中时，
漏掉有效裁切区域会把填充区一并采样并编码，造成所有接收端看到发布画面比例错误。

SDK 现统一使用 `GetBufferMatrix()`（当前交付基线为 API 15），并在首帧、矩阵变化或屏幕旋转变化时输出
以下 HiLog；同一稳定矩阵不会每帧重复输出：

```text
[OhosCapture][NativeImage] ... transformSource=GetBufferMatrix(crop+producer,api15) raw4x4=[...] mapped3x3=[...]
[OhosCapture][CameraTransform] ... input=1280x720 ... input3x3=[...] display3x3=[...] output3x3=[...]
[OhosCapture][TextureToI420] ... source=1280x720 stride=1280 i420=1280x720 framebuffer=320x1080 ... sampling3x3=[...]
[OhosCapture][Rotation] camera=<degrees> display=<degrees> finalRotation=<degrees> ...
```

`NativeImage` 日志中的 `rawFrame` 是相机 Buffer 原始宽高，`logicalFrame` 是应用 Buffer Matrix 后交给
WebRTC 的画面宽高。若矩阵是 90°/270° 旋转（例如 `mapped3x3=[0, 1, 0, -1, 0, 1, 0, 0, 1]`），SDK 会输出
`axisSwap=true` 并交换为 `logicalFrame=720x1280`；这是必要的，否则旋转后的纹理仍按 `1280x720` 进入
I420 编码，会在所有接收端产生比例压缩。

验收时，鸿蒙发布流应在 Android 和鸿蒙接收端均保持 16:9；并确认首行是
`transformSource=GetBufferMatrix(crop+producer,api15)`，而不是旧版 V2 矩阵日志。若仍异常，请提供上述
四类完整 HiLog，便可逐项核对原始矩阵、屏幕旋转合成矩阵和 I420 最终采样矩阵。

若 Android/iOS 接收端也看到鸿蒙发布画面中叠加了正常与镜像的两个内容，故障已经在上行编码前；不应再排查
XComponent。本 SDK 会在 `glReadPixels()` 完成、I420 帧交给编码器之前输出：

```text
[OhosCapture][I420Fingerprint] frame=<n> size=<w>x<h> strideYUV=<n> \
yHash=<n> yMean=<n> yHorizontalMirrorMad=<n> uHash=<n> ... vHash=<n> ...
```

该日志只对 Y/U/V 平面固定网格取样并计算指纹，不输出或落盘任何视频像素；首 3 帧及每 30 帧记录一次。
它是判定重影是否已经进入 RTP 编码帧的唯一边界证据，需与同一时段 Android/iOS 接收截图一并提供。

### 上下黑边：无真机时的定量定位

当 Android/iOS 接收端也显示鸿蒙发布流的上下黑边时，黑边已不属于 ArkTS/XComponent UI。SDK 在首 3 帧及每第
30 帧输出下列仅含统计数据的 HiLog，不记录或落盘相机画面：

```text
[OhosCapture][OesFingerprint] ... bands(top/middle/bottom)=<Y>/<Y>/<Y> \
nearBlackPermille(top/middle/bottom)=<0..1000>/<0..1000>/<0..1000>
[OhosCapture][I420Fingerprint] ... bands(top/middle/bottom)=<Y>/<Y>/<Y> \
nearBlackPermille(top/middle/bottom)=<0..1000>/<0..1000>/<0..1000>
[OhosCapture][SourceAdapt] input=<w>x<h> rotation=<degrees> logical=<w>x<h> \
crop=<x>,<y>+<w>x<h> output=<w>x<h> bufferType=<n> drop=<bool>
```

`nearBlackPermille` 是每个垂直三分区中亮度不高于 20 的采样点占比。测试时请对准明亮场景，避免把真实暗场误判为
黑边。

| 日志结果 | 可确认的根因边界 |
| --- | --- |
| OES 顶/底近黑比都接近 `1000`，中段明显较低 | 黑边来自 `NativeImage/OES` 输入；当前无真机时，最可能是模拟器虚拟相机或模拟器 Camera producer。 |
| OES 三段正常，I420 顶/底近黑比接近 `1000` | `TextureBuffer -> YuvConverter -> I420` 打包/采样矩阵制造黑边。 |
| OES、I420 三段均正常，而远端仍有黑边 | 检查 `SourceAdapt` 的 rotation、crop、output；若仍无异常，再检查编码器或接收方。 |

仅完成日志定位时，需要替换的交付物仍只有包含新 `libohos_webrtc.so` 的 `flutter_webrtc.har`。

若黑区只在鸿蒙本机预览可见，同时 OES/I420 统计均正常，则再收集：

```text
[XComponentVideo][OutputSample] surfaceId=<id> count=<n> surface=<w>x<h> \
luma(low/middle/high)=<Y>/<Y>/<Y> nearBlackPermille(low/middle/high)=<0..1000>/<0..1000>/<0..1000>
```

此日志在 `eglSwapBuffers()` 前对 native renderer 已完成绘制的 XComponent framebuffer 采样。它也没有边缘近黑像素时，
native renderer 已正确输出整帧；截图中的黑区只能来自后续 ArkUI Surface 合成，或页面中位于视频 Surface 下方的黑色
背景层。它同样不输出、保存或传输视频像素。

### 本地“原图 + 镜像副本”重影：VideoOutput 采集路线

在 `444.txt` 的实际链路中，本地 track 仅有一次 `videoRendererSetSrcObject` / `SinkAttach`，而
`OesFingerprint` 与编码前的 `I420Fingerprint` 都已表现出强左右对称。采集矩阵仅为旋转/翻转的可逆仿射矩阵，
不能复制画面。因此故障边界是相机 `PreviewOutput -> NativeImage OES`，而不是 XComponent、`mirror` 参数、编码器或
RTP。

从本版本起，`CameraCapturer` 会优先从设备的 `Camera_VideoProfile` 创建 `VideoOutput`，再将同一 NativeImage
surface 交给 WebRTC 编码；`PreviewOutput` 只在设备没有匹配 VideoProfile 时作为兼容回退。它会输出以下低频 HiLog：

```text
[OhosCapture][OutputRoute] video candidate index=<n> ... size=<w>x<h> fps=<min>-<max>
[OhosCapture][OutputRoute] attempt=video surfaceId=<id> size=<w>x<h> ...
[OhosCapture][OutputRoute] active=video surfaceId=<id>
```

只有 `active=video` 才表示 VideoOutput 会话已真正启动。若日志出现 `setup failed output=video`，SDK 会释放
失败会话，关闭并重建 `CameraInput`，再自动尝试 `attempt=preview-fallback`。这一步会输出
`resetting CameraInput before PreviewOutput fallback` 和 `CameraInput reset complete`；缺少后者时不应继续判断
PreviewOutput 本身。看到 `active=preview-fallback` 表示本地视频已回到原先可用的 PreviewOutput 路线，但不能据此
宣称重影已修复。应同时提供候选 profile 日志和 `OesFingerprint` / `I420Fingerprint`。

这个改动只在 `libohos_webrtc.so` 内，交付时仅替换同次打包的 `flutter_webrtc.har` 即可；不需要因它替换
`flutter.har`、`flutter_assets` 或 `tgortc-*.har`。

## 首帧后静止与本地重影诊断

一个远端画面能显示首帧、随后静止，不能仅凭 XComponent 的首帧尺寸日志判断为渲染问题。native
renderer 现额外输出低频且可对账的日志：

```text
[XComponentVideo][Input] surfaceId=<id> count=<n> frameId=<id> ...
[XComponentVideo][Present] surfaceId=<id> count=<n> inputCount=<n> ...
```

- `Input` 只记录第 1–3 帧和每第 30 帧，表示 WebRTC 已把帧交给该 Surface 的 VideoSink。
- `Present` 在 `eglSwapBuffers()` 成功后记录相同节流频率；`inputCount` 持续增长而 `Present` 不增长，或出现
  `Present ... failed`，才是 XComponent/EGL 呈现层故障。
- 若 WebRTC `VideoReceiveStreamInterface stats` 同时出现 `total_bps=0`、`network_fps=0`、
  `decode_fps=0`、`render_fps=0`，且 `Input` 未继续增长，则接收端已经没有新的远端 RTP 视频帧。此时应排查
  对方发送端、LiveKit 转发/订阅状态或网络，不能通过重建 XComponent 修复。

本地“重影/第二个镜像”时，先用 `videoRendererSetSrcObject` 和
`[XComponentVideo] surfaceId` 检查是否有两个 renderer/surface 绑定同一 local track。只有一条绑定时，
不要盲目反转 `mirror`：日志中的 `mirrorRequested` 只是 UI 请求，`rendererMirrorApplied` 表示 renderer 是否
额外施加镜像；对 native `TextureBuffer`，采集矩阵本身已经参与方向处理，强行再镜像会把单画面翻转，不能消除
重影。应同时保留该 surface 的 `Input/Present` 与 `[OhosCapture][NativeImage]` 矩阵日志定位。

当 Android 和 iOS 发布到鸿蒙均出现“首帧后静止”时，还应收集：

```text
[OhosRtpIngress] ssrc=<ssrc> count=<n> payloadType=<pt> marker=<bool> ...
```

它在鸿蒙 WebRTC RTP transport 收到包后、媒体 demux 前记录首 3 包及每 120 包。相同视频 SSRC 的该计数停止，
表示后续包未进入鸿蒙 WebRTC；若持续增长但 `Input` 停止，才继续检查 SRTP、demux 或解码。

## LiveKit AdaptiveStream 与 XComponent 外部 Surface

`RoomOptions.adaptiveStream` 管理的是**本端订阅远端视频**的策略，并非本端发布策略。启用后，LiveKit Flutter
客户端根据远端 `VideoTrackRenderer` 的可见 Widget 和最大尺寸向服务端发送 `UpdateTrackSettings`：有可见 Widget
时选择匹配的 simulcast 图层；没有可见 Widget 时发送 `disabled=true`，使服务端暂停向本端转发该远端视频。

ArkTS XComponent 通过 `attachVideoSurface` 直接绑定 native VideoSink，不会创建 Flutter
`VideoTrackRenderer`，因此不会登记 LiveKit 所依赖的 `viewKeys`。在此路线中启用
`adaptiveStream=true` 会把实际可见的 XComponent 误判为“没有可见视频”，通常在远端轨道订阅后的可见性轮询与
1.5 秒防抖后暂停远端流。典型表现是：首帧及少量视频 RTP 正常到达，随后视频 SSRC 的
`[OhosRtpIngress]` 停止，但音频仍持续到达。

当前 XComponent 基线必须使用：

```dart
RoomOptions(adaptiveStream: false)
```

这不影响本地视频发布；本地发布的 simulcast 图层按订阅者使用情况节流属于 `dynacast` 的职责。关闭
AdaptiveStream 的代价是隐藏的 XComponent 仍会继续接收/解码远端视频。

若后续需要恢复自适应能力，应在 `TgoVideoSurfaceManager` 的 attach、area/visibility change、detach 生命周期中
向 LiveKit 上报 XComponent 的可见性与尺寸：至少一个 Surface 可见时发送 `disabled=false` 并取最大 Surface 的
`width/height`；全部隐藏或解绑时发送 `disabled=true`。不能仅重新打开 `adaptiveStream=true`，否则首帧静止问题会
重新出现。

## 集成与构建产物

此次改动涉及 `libohos_webrtc.so`，因此必须重新构建并替换包含它的：

```text
../fluttertpc_flutter_webrtc/ohos/build/default/outputs/default/flutter_webrtc.har
```

导出后的交付文件为：

```text
dist/flutter_webrtc.har
```

本次不修改 Dart 桥接逻辑、`tgortc` ArkTS 桥接或 Flutter Engine，因此不需要仅因本改动替换
`tgortc-*.har`、`flutter.har` 或 `flutter_assets`；若同时交付这些层的其他改动，仍必须按同次构建规则
整体替换对应运行产物。

构建前必须确认主工程、`../fluttertpc_flutter_webrtc` 和 `../ohos_webrtc` 均位于 `harmonyos` 分支。
`fluttertpc_flutter_webrtc/ohos` 是模块目录，不能直接作为 Hvigor 根工程构建；应从包含该模块的
DevEco Studio 工程或临时根工程执行 `assembleHar`。具体步骤见 [`.codex/AGENTS.md`](../.codex/AGENTS.md)。
