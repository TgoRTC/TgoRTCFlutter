# 鸿蒙 ArkTS 宿主 + Flutter Texture 视频层

## 目的

这是群通话视频渲染的**新可选方案**。ArkTS 继续负责会议页、名称、音量、Loading、
点击、拖拽和动画覆盖层；一个 FlutterPage 仅负责视频 Texture。视频因此走 Flutter 的
`VideoTrackRenderer` 链路，`cover` / `contain` 由 Flutter widget 布局实现，不复用
XComponent 外部 Surface 的缩放逻辑。

> 前提：必须使用包含 `NativeVideoRenderer.initFlutterTexture(surfaceId)` 的新版
> `libohos_webrtc.so` / `flutter_webrtc.har`。旧二进制会将 Flutter Texture Surface 当成
> XComponent Surface 走 EGL 输出，在真机上可能报 `eglMakeCurrent in update failed` 并黑屏。
> 新接口改走 CPU/RGBA BufferQueue 输出，以兼容 Flutter Engine 所有权；它是兼容性路径，
> 上线前必须实测多路视频性能。

旧的 `attachVideoSurface` / `detachVideoSurface` / `updateVideoSurface` 保留且不受影响。
一个会议页应选择其中一种视频渲染路径，不能让同一视频格子同时绑定 XComponent 和
Flutter Texture。

## 架构

```text
ArkTS MeetingPage
├─ FlutterPage（一个，覆盖视频可用区域）
│  └─ TgoFlutterVideoTextureLayer
│     └─ VideoTrackRenderer / Flutter Texture（每个 tile）
└─ ArkTS Stack Overlay
   ├─ 名称、音量、Loading
   ├─ 点击/长按/拖拽
   └─ 边框、菜单与业务动画
```

Flutter 的视频层已使用 `IgnorePointer`，触摸由 ArkTS 覆盖层处理。

## Flutter 入口

仓库提供独立入口 `lib/main_texture.dart`，不会替换旧的 `lib/main.dart`。使用鸿蒙 Flutter
SDK 构建新方案：

```bash
PATH="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:$PATH" \
DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk" \
/usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/bin/flutter \
  build hap --debug -t lib/main_texture.dart
```

不要使用系统默认 Flutter；它没有 `hap` 子命令。命令成功后必须完整替换
`dist/flutter_assets_texture/`，尤其是 `kernel_blob.bin`、`vm_snapshot_data`、
`isolate_snapshot_data`、`icudtl.dat` 和 `io.flutter.shaders.json`。后者即使没有
预热 SkSL 也必须是合法的 `{"data":{}}`；部分 OHOS Flutter Engine 缺失该文件时会无法创建
主 Skia context，导致 Flutter Texture 持续黑屏。

承载该 FlutterPage 的 Dart 入口必须注册桥接，并把新视频层作为页面内容：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  TgoRTCOhosBridge.register();
  runApp(const TgoFlutterVideoTextureApp());
}
```

若应用已有 Flutter 根页面，也可仅在对应路由使用：

```dart
const TgoFlutterVideoTextureLayer()
```

旧 XComponent 方案继续使用原 `lib/main.dart` 构建。两个入口产生不同的
`kernel_blob.bin`；分发时不要将 Texture 入口的 `flutter_assets` 与旧入口混用。

## 构建产物选择

本仓库 `dist/` 同时保留两套 Flutter 资源：

| 使用方式 | Flutter 入口 | 要复制到集成工程 `flutter_assets/` 的目录 |
| --- | --- | --- |
| 旧 XComponent Surface | `lib/main.dart` | `dist/flutter_assets/` |
| 新 Flutter Texture 视频层 | `lib/main_texture.dart` | `dist/flutter_assets_texture/` |

两种方式都需要使用同一批、同次构建的 `dist/tgortc-1.0.2.har`、
`dist/flutter_webrtc.har` 和 `dist/flutter.har`。Texture 方案还要求
`flutter_webrtc.har` 内已包含新的 `libohos_webrtc.so`。切换方案时，必须先清空集成工程的旧
`flutter_assets/`，再完整复制选中目录的内容。

该 widget 没有文字、Loading、手势或业务按钮；空轨道只显示透明视频内容，底色由
`backgroundColor` 控制。

## ArkTS：创建一个 FlutterPage

在会议页面中创建**一个** FlutterPage，尺寸覆盖整个视频区域。名称、音量等 ArkTS UI
应放在同一个 ArkTS `Stack` 的上层。不要为每个成员单独创建 FlutterPage，也不要再为
该页面创建 `RTCVideoSurface/XComponent`。

加入房间后，使用 `TgoRTCFlutter.setFlutterVideoLayout` 下发完整布局。所有坐标均相对
于 FlutterPage 的宽高，范围是 `0..1`，因此不需要在 ArkTS vp、px 与 Flutter logical
pixel 之间换算。

```ts
await TgoRTCFlutter.setFlutterVideoLayout({
  animationDurationMs: 220,
  animationCurve: 'easeInOut',
  tiles: [
    {
      tileId: 'remote-main',
      uid: remoteUid,
      isLocal: false,
      left: 0,
      top: 0,
      width: 1,
      height: 1,
      zIndex: 0,
      fit: 'cover',
    },
    {
      tileId: 'local-floating',
      uid: loginUid,
      isLocal: true,
      left: 0.72,
      top: 0.04,
      width: 0.24,
      height: 0.24,
      zIndex: 10,
      mirror: true,
      fit: 'cover',
    },
  ],
})
```

### tile 字段

| 字段 | 说明 |
| --- | --- |
| `tileId` | 稳定且唯一的格子 ID。布局、放大或拖动时保持不变以复用 Flutter Texture renderer。 |
| `uid` / `isLocal` | 要渲染的成员。未实际入房或轨道未订阅时该 tile 不会显示视频，ArkTS 继续显示 Loading。 |
| `left` / `top` / `width` / `height` | 相对 FlutterPage 宽高的比例；矩形必须完整位于 `0..1` 内。 |
| `zIndex` | 视频层内的顺序；更大者在上。 |
| `visible` | `false` 时该 tile 不渲染。 |
| `mirror` | 可选；省略时使用 SDK 初始化的全局镜像设置。 |
| `fit` | `cover`（等比填满裁切）或 `contain`（完整显示，允许黑边）。 |

同一 `uid` 可以有两个不同 `tileId`，用于“主画面 + 悬浮小窗”。两个 tile 会各自保留
自己的 Flutter Texture renderer；因此小窗移动或放大不会重建其他成员视频。

## 动画与悬浮窗

ArkTS 发起格子放大、缩小或拖动结束时，应下发新的完整 `tiles` 列表，并传入与 ArkTS
覆盖层相同的 `animationDurationMs`、`animationCurve`。Flutter 使用 `AnimatedPositioned`
同步视频矩形动画；ArkTS 同步自身姓名/边框/Loading 的动画，即可避免视频跳动。

连续拖动不建议逐帧跨 MethodChannel 下发布局。应让 ArkTS 在拖动时只移动自身视觉外壳，
在拖动结束时下发最终布局；如必须实时移动，需节流到显示帧率以内并做实机性能验证。

## 生命周期

1. FlutterPage 已就绪并执行 `TgoRTCOhosBridge.register()` 后，再调用布局 API。
2. 成员加入、离开、摄像头开关或重连时，原有 `onParticipantsChanged`、
   `onVideoTrackChanged` 仍照常使用；ArkTS 根据这些事件更新其 Overlay 和下一次布局。
3. 隐藏会议页、销毁 FlutterPage 或结束通话前调用：

```ts
await TgoRTCFlutter.clearFlutterVideoLayout()
```

4. 需要恢复原 XComponent 方案时，先清空 Flutter 布局，再按旧 API 绑定 Surface。

## ArkTS API

```ts
interface FlutterVideoTile {
  tileId: string
  uid: string
  isLocal: boolean
  left: number
  top: number
  width: number
  height: number
  zIndex?: number
  visible?: boolean
  mirror?: boolean
  fit?: 'cover' | 'contain'
}

await TgoRTCFlutter.setFlutterVideoLayout({
  tiles: FlutterVideoTile[],
  animationDurationMs?: number, // 0..5000
  animationCurve?: 'linear' | 'easeIn' | 'easeOut' | 'easeInOut',
})
await TgoRTCFlutter.clearFlutterVideoLayout()
```

参数不合法、tileId 重复或矩形越界时，调用会返回 `invalid_flutter_video_layout`。

## 验收清单

- 真机日志不再出现 `eglMakeCurrent in update failed`，并至少出现一次首帧与
  `didTextureRenderFirstFrame` 回调。
- 1280×720 视频在正方形 tile 使用 `cover` 时左右裁切且无上下黑边。
- 720×1280 视频在正方形 tile 使用 `cover` 时上下裁切且无左右黑边。
- `contain` 完整显示画面。
- 主画面与悬浮窗切换时，其他 `tileId` 对应视频不中断。
- 成员离开只移除对应 tile；其余 video Texture 不重建。
- 验证 2、4、9 路视频，及前后台、重连、横竖屏和悬浮窗拖动后的性能。
