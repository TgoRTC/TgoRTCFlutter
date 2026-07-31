# 鸿蒙（HarmonyOS NEXT）构建与 HAR 集成说明

本仓库的鸿蒙适配仅在 `harmonyos` 分支维护。开始修改或打包前，先确认：

```bash
git branch --show-current
# 预期输出：harmonyos
```

## 1. 必须使用鸿蒙版 Flutter SDK

系统默认 Flutter 可能是标准版，**不支持** `ohos` / `hap` 构建，不能用于本项目的鸿蒙产物。

当前机器已安装的鸿蒙版 Flutter 为：

```text
/usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/bin/flutter
```

建议在当前终端显式切换，避免误用标准 Flutter：

```bash
export PATH="/usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/bin:$PATH"
flutter --version
```

输出应包含 `ohos` 标识。请勿使用 `/usr/local/Caskroom/flutter/3.24.5/flutter/bin/flutter` 生成鸿蒙运行产物。

命令行环境与 DevEco Studio 的环境不完全相同。若 `flutter build hap` 报找不到 `ohpm` 或
`hvigorw`，应使用已验证的环境后重试；不要把 Dart 前置资源生成误判为完整 HAP 成功：

```bash
PATH="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:$PATH" \
DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk" \
/usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/bin/flutter \
  build hap --debug -t lib/main_texture.dart
```

正常完成会输出 `Running Hvigor task assembleHap...` 的耗时和调试签名提示；没有配置签名时可产生
`entry-default-unsigned.hap`，但这不影响 `build/ohos/flutter_assets/` 的 Debug 资源生成。

## 2. 产物组成与不可混用规则

启用 ArkTS XComponent 多路视频后，一次可运行的 Debug 鸿蒙 SDK 由下列四部分组成，必须来自**同一套 Flutter/插件源码**并整体更新：

1. `tgortc-<version>.har`：ArkTS RTC 桥接层。
2. `flutter_webrtc.har`：WebRTC 的 ArkTS `NativeVideoRenderer` 实现（包含外部 XComponent Surface 支持）。
3. `flutter.har`：Flutter 运行时（含 `libflutter.so`）。
4. `flutter_assets/`：Dart 代码和资源。

`tgortc.har` 只包含 ArkTS 接收层。Flutter/Dart 的事件发送逻辑（例如远端离开事件）位于 `flutter_assets/kernel_blob.bin`；仅替换 `tgortc.har` 不会更新 Dart 逻辑。

Debug 的 `flutter_assets/` 至少必须包含：

```text
kernel_blob.bin
vm_snapshot_data
isolate_snapshot_data
icudtl.dat
AssetManifest.json
FontManifest.json
NOTICES.Z
```

不要将新的 `flutter.har` 与旧的 `flutter_assets` 混用；这会导致 Dart 快照与运行时不匹配，可能在启动时闪退。

## 3. 构建 tgortc ArkTS HAR

ArkTS 源码位于 `ohos/tgortc_library/`，生成包的版本由
`ohos/tgortc_library/oh-package.json5` 中的 `version` 决定。

优先在 **DevEco Studio** 中选择 `tgortc_library` 模块执行 `assembleHar`。IDE 会注入其已选择的 SDK 配置；当 IDE 构建日志显示 `BUILD SUCCESSFUL` 时，以下文件就是唯一可信的 ArkTS HAR 源：

```text
ohos/tgortc_library/build/default/outputs/default/tgortc_library.har
```

如 IDE 未运行且已确认终端 SDK 环境与 IDE 完全相同，才可在仓库根目录执行：

```bash
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module \
  -p product=default \
  -p module=tgortc_library@default \
  assembleHar --analyze=normal --parallel --incremental --daemon
```

成功标志是 `BUILD SUCCESSFUL`。生成文件：

```text
ohos/tgortc_library/build/default/outputs/default/tgortc_library.har
```

可将其复制并按版本重命名为：

```text
dist/tgortc-<version>.har
```

`@ohos/flutter_ohos` 中的 ArkTS 告警、`targetSdkVersion` 建议等不等于构建失败；以最终的 `BUILD SUCCESSFUL` 为准。任何 `ERROR` 都必须先处理。

### DevEco Studio 与终端 Hvigor 的环境陷阱

- 不要因终端报 `DEVECO_SDK_HOME`、`SDK component missing` 而修改工程的 `compatibleSdkVersion`。这通常是终端没有继承 DevEco Studio 选定的 SDK，而不是源码或 HAR 不兼容。
- `ohos/local.properties` 的 `hwsdk.dir` 是 SDK **根目录**。本机为 `/Applications/DevEco-Studio.app/Contents/sdk`；不要猜测并设置为 `/Applications/DevEco-Studio.app/Contents/sdk/default`。
- DevEco Studio 正在构建时，不要从另一个终端使用 `--daemon` 启动同一 Hvigor。两个进程会竞争 `~/.hvigor/daemon/cache/daemon-sec.json.lock`，终端可能报 daemon 注册失败。应优先使用 IDE 已成功生成的 HAR，不要删除 IDE 正在使用的锁。
- `ohos/tgortc_library/oh_modules/@ohos/flutter_ohos` 是本机 `ohpm install` 生成的符号链接，可能指向其他工作区；它不是源码产物，绝不能提交到 Git。

## 4. 生成匹配的 Flutter 运行包与完整资源

每当修改 Dart 代码（尤其 `lib/bridge/` 下的事件、MethodChannel 或序列化逻辑）后，都必须重新生成 Flutter 运行产物：

```bash
/usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/bin/flutter build hap --debug
```

该命令会刷新 Dart 快照。当前鸿蒙 Flutter SDK 的可导出目录为：

```text
build/ohos/flutter_assets/
```

其中必须检查 `kernel_blob.bin`、`vm_snapshot_data` 和 `isolate_snapshot_data` 已刷新。
`icudtl.dat` 由当前鸿蒙 Flutter SDK 的
`packages/flutter_tools/templates/app_shared/ohos.tmpl/dta/icudtl.dat` 提供，也必须一并复制。

`flutter.har` 是鸿蒙 Flutter SDK 自带的引擎 HAR，文件时间通常等于 SDK 安装时间，并不会在每次业务 Dart 修改后变化。不能仅凭时间判断它“过旧”；应确认它来自当前使用的鸿蒙 Flutter SDK，例如：

```bash
cmp -s ohos/har/flutter.har \
  /usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/bin/cache/artifacts/engine/ohos-arm64/flutter.har
```

本仓库是 Flutter 应用而非 Flutter module，`flutter build har` 报“current project is not module”属于预期行为；应使用 `flutter build hap --debug` 生成 Dart 快照和 `flutter_assets`。

若 `flutter build hap` 仅输出 `Running Hvigor task assembleHap...` 就中断，Flutter 前端仍可能已刷新 `flutter_assets`，但不能宣称完整 HAP 构建成功。此时应同时取得 DevEco Studio 成功构建的 `tgortc_library.har`，再按下文的逐文件校验组装 `dist/`。

将同次构建产物导出到 `dist/`：

```bash
cp -p ohos/har/flutter.har dist/flutter.har
mkdir -p dist/flutter_assets
cp -Rp build/ohos/flutter_assets/. dist/flutter_assets/
cp -p /usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/packages/flutter_tools/templates/app_shared/ohos.tmpl/dta/icudtl.dat \
  dist/flutter_assets/icudtl.dat
cp -p ohos/tgortc_library/build/default/outputs/default/tgortc_library.har \
  dist/tgortc-<version>.har
cp -p ../fluttertpc_flutter_webrtc/ohos/build/default/outputs/default/flutter_webrtc.har \
  dist/flutter_webrtc.har
```

发布前核查关键文件：

```bash
find dist/flutter_assets -maxdepth 2 -type f | sort
du -sh dist/flutter.har dist/flutter_webrtc.har dist/flutter_assets dist/tgortc-<version>.har
```

同时验证导出结果与构建源完全一致：

```bash
cmp -s ohos/tgortc_library/build/default/outputs/default/tgortc_library.har \
  dist/tgortc-<version>.har
cmp -s ohos/har/flutter.har dist/flutter.har
cmp -s build/ohos/flutter_assets/kernel_blob.bin dist/flutter_assets/kernel_blob.bin
cmp -s /usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/packages/flutter_tools/templates/app_shared/ohos.tmpl/dta/icudtl.dat \
  dist/flutter_assets/icudtl.dat
```

如需发布 Release 包，使用 `flutter build hap --release` 重新生成整套产物；不要将 Debug 的 Flutter 资源与 Release 运行时混用。

## 5. 集成方更新步骤

集成方需要一次性取得 `dist/` 中的以下内容：

```text
tgortc-<version>.har
flutter_webrtc.har        # XComponent Surface 能力启用时必须更新
flutter.har
flutter_assets/        # 整个目录，保持层级
```

推荐流程：

1. 替换其工程引用的 `tgortc-<version>.har`。
2. 若使用 `attachVideoSurface`，替换其 `flutter_webrtc.har`（或将其工程的同名模块源码切换至本 fork）。
3. 替换其工程 `ohos/har/flutter.har`。
4. **先清空**其 `entry/src/main/resources/rawfile/flutter_assets/` 的旧内容，再完整复制新的 `flutter_assets/` 内容。
5. 在 DevEco Studio 重新执行 `ohpm install` / Sync，然后构建并安装新的 HAP。

示例依赖声明（路径按集成方工程调整）：

```json5
{
  "dependencies": {
    "@anthropic/tgortc": "file:../har/tgortc-1.0.2.har"
  }
}
```

`tgortc.har` 内部依赖 `@ohos/flutter_ohos: file:../har/flutter.har`，因此集成方应保持 `flutter.har` 位于与其依赖路径相匹配的位置。

## 6. 桥接事件调试注意事项

- Flutter 入口必须在加入房间前且仅一次调用 `TgoRTCOhosBridge.register()`。
- ArkTS 通道使用 `StandardMethodCodec`；Flutter 传来的 payload 是 `Map`，应使用 `args.get('key')`，不能用 `args.key` 或 `JSON.stringify(args)`。
- ArkTS 插件必须在 Flutter Engine 创建后注册 `TgoRTCFlutter.getInstance()`；具体 API 见 `docs/TgoRTC鸿蒙桥接API说明.md`。

## 7. `flutter_webrtc` 鸿蒙 Surface 能力与本地 Fork

当前 `flutter_webrtc` 使用 OpenHarmony SIG 的鸿蒙适配版：

```text
https://gitcode.com/openharmony-sig/fluttertpc_flutter_webrtc.git
```

当前锁定源码提交由 `pubspec.lock` 决定；本机 Pub 缓存中的源码仅用于参考，例如：

```text
/Users/songlun/.pub-cache/git/fluttertpc_flutter_webrtc-<resolved-ref>/
```

不要直接修改这个缓存目录：执行 `flutter pub get`、清缓存或切换依赖后改动都会丢失。也不要修改 `ohos/entry/oh_modules/flutter_webrtc`，它是 `ohpm` 安装的生成模块。

### Fork 位置和引用规则

- 需要扩展 ArkTS XComponent Surface 能力时，将完整 fork 放在本仓库同级目录：`../fluttertpc_flutter_webrtc/`。
- 本仓库通过 `pubspec.yaml` 的 `dependency_overrides.flutter_webrtc.path: ../fluttertpc_flutter_webrtc` 引用该 fork；改动完成后执行鸿蒙版 `flutter pub get`，并核对 `ohos/build-profile.json5` 的 `flutter_webrtc.srcPath` 是否为 `../../fluttertpc_flutter_webrtc/ohos`。
- 当前鸿蒙 Flutter 版本在处理 `example/` 的旧插件缓存路径时可能在最后报 `Parse ohos module.json5 error`，即使根工程的 `.flutter-plugins-dependencies` 和 `pubspec.lock` 已切换到 fork。此时不能继续使用缓存路径；必须手动核对并修正上述 `srcPath` 后再用 DevEco Studio 构建。
- Fork 内的 Dart 层与 `ohos/` ArkTS 层必须一起维护；仅编译 `tgortc_library.har` 不会打包或更新 `flutter_webrtc` 模块。
- 交付前在 fork 的 `ohos/` 模块执行 `assembleHar`；唯一可信的 WebRTC HAR 输出为 `../fluttertpc_flutter_webrtc/ohos/build/default/outputs/default/flutter_webrtc.har`，并将它作为 `dist/flutter_webrtc.har` 一并交付。
- 当前 Hvigor 版本要求从**项目根目录**读取 `modules` 数组；不能直接在 fork 的 `ohos/` 模块目录运行
  `hvigorw assembleHar`，否则会报 `The property of module should be an array`。应使用 DevEco Studio 中包含该模块
  的工程，或建立临时根工程并在其 `build-profile.json5` 的 `modules` 中引用
  `../fluttertpc_flutter_webrtc/ohos`，再执行 `-p module=flutter_webrtc@default assembleHar`。
- 独立构建 fork 前，`ohos/oh-package.json5` 的 `file:../libs/flutter.har` 实际指向 fork 根目录的 `../fluttertpc_flutter_webrtc/libs/flutter.har`。可临时复制主工程同版本 `ohos/har/flutter.har` 后执行 `ohpm install`；该本地 HAR 必须被 `.gitignore` 忽略，不能提交。
- fork 中的 `ohos/libs` 可能使用 Git LFS。克隆后先确认二进制库不是 LFS 指针，再构建；不要用不完整的缓存目录替代正式 clone。

### XComponent Surface 必须实现的安全约束

ArkTS 多成员网格需要将 `XComponentController.getXComponentSurfaceId()` 返回的真实 `surfaceId` 绑定到指定成员视频轨道。此能力位于 `flutter_webrtc`，不能只通过 `tgortc` HAR 实现。

- 必须支持按指定 `trackId` 选择视频轨道，不能总是绑定流中的第一个视频轨道。
- detach/rebind 只能移除当前 `NativeVideoRenderer` 的 VideoSink；**绝不能调用**共享 `videoTrack.stop()`，否则会停止实际采集或远端解码。
- 必须提供 `attachVideoSurface`、`detachVideoSurface`、`updateVideoSurface` 所需的外部 Surface、镜像和 `cover/contain` 控制，并确保 detach 幂等。
- 一个 `surfaceId` 仅能绑定一个成员；同一成员最多保留一个主画面和一个小窗 renderer。超过限额返回 `renderer_bind_failed`。
- 轨道未订阅、重连或替换期间，保留绑定登记并回调 `waiting_track`；首帧、解绑和错误均通过 `onVideoSurfaceStateChanged` 回调，并携带 `roomName`、`uid`、`surfaceId`。
- 不允许把视频帧经 `MethodChannel` 回传到 ArkTS；视频必须在 WebRTC `NativeVideoRenderer` / VideoSink 层直接输出到 XComponent Surface。

### XComponent 路线与尺寸诊断

- TgoCall 的默认视频路线是 ArkTS XComponent；`RTCVideoRenderer` 不得在构造时自动初始化 Flutter
  `ImageReceiver`。否则异步回调可能在 XComponent 已绑定后重新替换其 `surfaceId`。
- `RenderFit.RESIZE_COVER` 只控制 XComponent 的布局，不能代替视频 `cover`。`fit: 'cover'` 必须下发到
  `NativeWindowRendererGl` 的 `ASPECT_FILL`（值 `1`）；`contain` 对应 `ASPECT_FIT`（值 `2`）。
- 诊断尺寸问题时，收集 ArkTS `onAreaChange` 的布局尺寸，以及 native
  `[XComponentVideo] frame=... surface=... scaleMode=... viewport=...` 日志。前者是 ArkUI 单位，后者是
  EGL 实际像素尺寸；两者不一致时，不要通过 ArkTS scale 伪造裁切。
- 完整排查与验收步骤见 `docs/鸿蒙XComponent视频尺寸诊断说明.md`。XComponent 路线变更后必须重新构建
  `flutter_webrtc.har`，其中包含 ArkTS renderer 和 `libohos_webrtc.so`。

### LiveKit AdaptiveStream 与 XComponent 外部 Surface

- `RoomOptions.adaptiveStream` 管理本端**订阅远端视频**的可见性/尺寸和 simulcast 图层，不管理本端发布流；
  本端发布图层节流由 `dynacast` 管理。
- LiveKit Flutter 仅通过远端 `VideoTrackRenderer` 的 `viewKeys` 识别可见视频。ArkTS XComponent 通过
  `attachVideoSurface` 直接绑定 native VideoSink，不会生成该 Flutter Widget，因此在 XComponent 路线使用
  `adaptiveStream: true` 会被误判为无可见视频，并在可见性轮询和约 1.5 秒防抖后向服务端发送
  `UpdateTrackSettings(disabled=true)`；服务端随即暂停向鸿蒙转发远端视频。表现为先显示少量帧，随后视频 RTP
  SSRC 停止而音频持续。
- 当前 XComponent 基线固定为 `RoomOptions(adaptiveStream: false)`；这是 Dart 改动，必须重新生成并整体替换
  `flutter_assets`（尤其 `kernel_blob.bin`），不需要仅因该改动重编 `flutter_webrtc.har`。
- 如需恢复 AdaptiveStream，先实现 XComponent 的外部可见性桥接：attach/visible/area change 时向 LiveKit 上报
  `disabled=false` 与最大可见 Surface 的 `width/height`；全部隐藏或 detach 时上报 `disabled=true`。未完成这层
  桥接前不得重新启用 `adaptiveStream: true`。

## 8. 可选的 Flutter Texture 视频层

当 XComponent 外部 Surface 的 `cover/contain` 无法由 `libohos_webrtc.so` 正确执行时，保留
旧 Surface API，同时可使用 `lib/pages/arkts_video_texture_layer.dart` 的
`TgoFlutterVideoTextureLayer`。它必须由**一个** ArkTS FlutterPage 承载，不能每个视频格子
创建一个 FlutterPage。

- ArkTS 通过 `setFlutterVideoLayout` 下发完整 `tiles` 列表；几何使用相对 FlutterPage 的 `0..1`
  归一化坐标，避免 vp/px 与 Flutter logical pixel 换算。
- `tileId` 必须稳定且唯一；同一 uid 可使用两个 tileId 实现主画面和悬浮窗。位置变化会复用
  对应 Flutter Texture renderer。
- ArkTS 继续拥有名称、音量、Loading、手势和覆盖层。Flutter 视频层使用 `IgnorePointer`，不接管
  ArkTS 手势。
- 两侧动画必须使用同一 `animationDurationMs` / `animationCurve`。不要逐帧经 MethodChannel
  下发拖动位置；拖动结束后下发最终布局，或自行节流并实机验证。
- 页面销毁、最小化或切回旧 XComponent 方案前调用 `clearFlutterVideoLayout`。
- 详细示例与验收项在 `docs/鸿蒙FlutterTexture视频层集成说明.md`。
- 旧入口为 `lib/main.dart`；Texture 入口为 `lib/main_texture.dart`。构建 Texture 资源时必须
  使用 `flutter build hap --debug -t lib/main_texture.dart`，并单独标记/分发其 `flutter_assets`，
  绝不能与旧入口的 `kernel_blob.bin` 混用。

## 9. `libohos_webrtc.so` native 源码、EGL 与替换规则

`fluttertpc_flutter_webrtc` 仓库内的 `ohos/libs/arm64-v8a/libohos_webrtc.so` 是预编译 native
二进制；仅修改 Dart、ArkTS 或 HAR 无法修复其 EGL / GPU 输出问题。它的公开原始源码位于：

```text
https://gitcode.com/openharmony-sig/ohos_webrtc.git
```

需要修改 native 视频输出时，将该源码完整 clone 到本仓库同级目录：

```text
../ohos_webrtc/
```

并确保其工作分支也为 `harmonyos`。核心源码和构建入口为：

```text
../ohos_webrtc/sdk/ohos/src/ohos_webrtc/render/native_video_renderer.cpp
../ohos_webrtc/sdk/ohos/src/ohos_webrtc/render/native_window_renderer_gl.cpp
../ohos_webrtc/sdk/ohos/src/ohos_webrtc/render/egl_env.cpp
../ohos_webrtc/sdk/ohos/src/ohos_webrtc/BUILD.gn
../ohos_webrtc/build.sh
```

`sdk/ohos/BUILD.gn` 的 `libohos_webrtc` target 会编译上述 N-API、EGL 和视频渲染源码并输出
`libohos_webrtc.so`。`NativeVideoRenderer.init(surfaceId)` 当前把 Surface ID 转为
`OH_NativeWindow`，再由 `NativeWindowRendererGl` 创建 EGL window surface、`eglMakeCurrent`、绘制
并 `eglSwapBuffers`。

### Flutter Texture native 输出限制

- 原始 `flutter_webrtc` HarmonyOS 实现中的 `RTCVideoView` 会创建 `OhosView` / ArkTS XComponent；它能
  显示视频并不代表 `Texture(textureId)` 输出已可用。
- Flutter `TextureRegistry.registerTexture()` 返回的 Surface 不能直接假定与 XComponent 使用同一 EGL
  context。若日志出现 `eglMakeCurrent in update failed`，必须在上述 native 源码中新增 Flutter Texture
  专用 sink 或兼容的 EGL / BufferQueue 输出路径；不要在 ArkTS/Dart 层绕过该错误。
- `NativeVideoRenderer.init(surfaceId, sharedContext?)` 的 `sharedContext` 是该 WebRTC native 模块的
  `NapiEglContext`，不是 Flutter Engine EGL context；仅补充 `.d.ts` 或传入默认 context 不能解决
  Flutter Texture 的上下文兼容问题。
- native 修复后必须**同次构建、整体替换**：
  `libohos_webrtc.so`、`flutter_webrtc.har`、`tgortc-<version>.har`、`flutter.har` 与对应完整
  `flutter_assets/`。禁止将新 `.so` / HAR 与旧 Dart 快照混用。
- 当前修复方案使用明确的 `NativeVideoRenderer.initFlutterTexture(surfaceId)`：它只用于
  Flutter `TextureRegistry.registerTexture()` 返回的 Surface，并强制使用 native CPU/RGBA
  BufferQueue 输出，避免 WebRTC 自建 EGL context 对 Flutter Surface 执行 `eglMakeCurrent`。
  `init(surfaceId)` 保持为 ArkTS XComponent 的 GL/EGL 路径；两者不得混用。该路径是兼容性
  fallback，性能低于后续由 Flutter Engine 提供 EGL 共享上下文的零拷贝 sink，必须真机测量
  多路视频的帧率、CPU 和首帧。

### 构建与替换前的必做检查

- `ohos_webrtc` 的构建依赖 WebRTC third_party、`depot_tools` 和与目标设备匹配的 HarmonyOS Native SDK；
  不要在未确认 SDK/ABI 的情况下替换当前可运行的 `.so`。
- macOS 上 `depot_tools` 还会从 `chrome-infra-packages.appspot.com` 下载 GN/Python。若网络超时，
  会导致 `python3_bin_reldir.txt not found`，不能据此误判 native 代码编译失败；先恢复该下载通道或
  使用已初始化的同版本 `depot_tools`，再执行 `gn gen` / `ninja`。
- 当前插件二进制和候选源码虽然均包含 `NativeVideoRenderer`、`sharedContext` 与
  `native_window_renderer_gl`，但替换前仍应构建新 `.so` 并核对 ARM64 ABI、N-API 导出和真机首帧。
- 先备份现有 `../fluttertpc_flutter_webrtc/ohos/libs/arm64-v8a/libohos_webrtc.so`，再替换；替换后重新
  编译 `flutter_webrtc.har`，并在真机验证 XComponent 回归与 Flutter Texture 首帧。不要提交 Hvigor
  缓存目录或由 `ohpm install` 生成的 `oh_modules`。
- 当前已验证的本机交叉编译输出为
  `../ohos_webrtc/out/flutter_texture/libohos_webrtc.so`。它必须是 `ELF 64-bit, ARM aarch64`，并可用
  `strings` 确认 `initFlutterTexture`；不要以未构建的源码目录或 x86 产物替代 arm64-v8a 二进制。
- `flutter_webrtc.har` 是 gzip/tar 格式而非 zip。替换前可用
  `tar -xOzf flutter_webrtc.har package/libs/arm64-v8a/libohos_webrtc.so | strings | rg initFlutterTexture`
  确认新 native 路径确实已打包；Hvigor 的 `DoNativeStrip` 会改变 `.so` 的哈希，因此 HAR 内二进制哈希
  不必与未 strip 的 `out/flutter_texture/libohos_webrtc.so` 相同。

### 鸿蒙相机采集比例异常（API 15）

- 若 Android 和鸿蒙接收端都仅对**鸿蒙发布流**出现上下压缩，应停止调整 XComponent/ArkTS 布局；故障位于
  `Camera PreviewOutput -> NativeImage OES -> TextureBuffer::ToI420 -> encoder` 上行链路。
- API 15 的 `OH_NativeImage_GetBufferMatrix()` 同时包含 producer transform 和有效 crop rect；
  `OH_NativeImage_GetTransformMatrixV2()` 只有 producer transform。对齐后 Buffer 大于可见相机帧时，使用
  V2 会把填充区域错误采样进编码帧并改变内容比例。API 15 产物必须在
  `video_frame_receiver_gl.cpp` 使用 `GetBufferMatrix()`，不能回退为 V2。
- 若 Buffer Matrix 的二维部分为非对角轴（90°/270°，如 `[0, 1; -1, 0]`），矩阵已把内容旋转为
  `height x width`；创建 `TextureBuffer` 时必须交换逻辑宽高，并在 HiLog 输出
  `rawFrame`、`logicalFrame` 与 `axisSwap`。保留原始横屏宽高会使 `VideoAdapter`/I420 按错误的比例缩放，
  且 Android 与鸿蒙接收端都会看到鸿蒙发布流被压缩。
- 本机 native 产物固定从 `../ohos_webrtc/out/flutter_texture/libohos_webrtc.so` 生成。可使用 DevEco
  自带 Ninja 构建：

  ```bash
  /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/build-tools/cmake/bin/ninja \
    -C ../ohos_webrtc/out/flutter_texture libohos_webrtc
  ```

- 必须保留精确且去重的 HiLog 前缀：`[OhosCapture][NativeImage]`、
  `[OhosCapture][CameraTransform]`、`[OhosCapture][TextureToI420]` 和
  `[OhosCapture][Rotation]`。它们分别记录 NativeImage 原始/映射矩阵、旋转合成矩阵、I420 采样矩阵和
  设备旋转；只在首帧、矩阵或旋转变化时记录，禁止逐帧刷日志。
- 仅修改上述 native 采集代码时，交付内容是重新打包的 `flutter_webrtc.har`（其中含新
  `libohos_webrtc.so`）。没有 Dart、Flutter Engine 或 `tgortc` 改动时，**不需要**更新 `flutter.har`、
  `flutter_assets` 或 `tgortc-*.har`。
- 对“原图与镜像副本叠加”的采集重影，不能通过 `mirror` 或 XComponent 处理。`444.txt` 已证实单一 local
  renderer、OES 与编码前 I420 均已有该特征，而采集矩阵只有旋转/翻转，不能产生第二张图。`CameraCapturer` 必须
  优先枚举 `Camera_VideoProfile` 并使用 `CreateVideoOutput` / `AddVideoOutput` 将 NativeImage surface 作为视频
  采集输出；仅在设备没有匹配 VideoProfile 时回退 `CreatePreviewOutput` / `AddPreviewOutput`。
- 此路线必须记录 `[OhosCapture][OutputRoute]`：视频 profile 候选、`attempt=video` 以及会话真正启动后的
  `active=video`。`VideoOutput` 在某些设备/SDK 组合会于 `CommitConfig` 失败；实现必须释放失败的 output/session，
  关闭并重建 `CameraInput` 后自动尝试 `PreviewOutput`，并记录 `setup failed output=video stage=<...>`、
  `resetting CameraInput before PreviewOutput fallback`、`CameraInput reset complete`、`attempt=preview-fallback` 和
  `active=preview-fallback`。验收重影修复必须确认 `active=video`；回退日志只证明本地视频恢复，仍是旧采集路径。
  该 native 改动只需重打包和替换 `flutter_webrtc.har`。

### XComponent 首帧静止与镜像重影的定位规则

- `NativeWindowRendererGl` 必须保留低频 HiLog：`[XComponentVideo][Input]` 表示 VideoSink 收到帧，
  `[XComponentVideo][Present]` 表示该帧已成功通过 `eglSwapBuffers()` 呈现。只记录第 1–3 帧和每第 30 帧；
  `Present ... failed` 是唯一可直接归因于 EGL 呈现失败的证据。
- 远端只显示首帧时，先核对同一 SSRC 的 `VideoReceiveStreamInterface stats`。如果 `total_bps=0`、
  `network_fps=0`、`decode_fps=0`、`render_fps=0`，并且 `[Input]` 计数停止增长，说明接收端已没有新的 RTP
  视频帧；排查对端发布、LiveKit 订阅/转发或网络，不能靠重建 XComponent 修复。
- 若本机截图仍显示黑区，但 OES 与 I420 的 `nearBlackPermille` 都为零，必须收集
  `[XComponentVideo][OutputSample]`。它在 `eglSwapBuffers()` 前对 XComponent 已绘制 framebuffer 的低/中/高
  三段做 RGBA 亮度采样；它也为零则 native renderer 已输出完整画面，黑区只能由 ArkUI Surface 合成或页面背景层
  在其后产生。该日志同样只输出统计值，首 3 帧及每 30 帧记录一次。
- 本地重影不能仅根据 `mirror=true` 处理。先确认 `videoRendererSetSrcObject`、`setVideoTrack` 和
  `surfaceId` 是否存在重复绑定。`mirrorRequested` 是 ArkTS 请求，`rendererMirrorApplied` 仅表示 native
  renderer 是否额外施加镜像；native `TextureBuffer` 的方向由采集矩阵处理，强制再翻转不能消除重影且可能造成
  单画面方向错误。
- 若 Android/iOS 接收端也看到鸿蒙发布流存在正常与镜像内容重叠，问题位于 `NativeImage OES -> I420 -> encoder`
  上行边界，不能修改 XComponent。必须采集 `[OhosCapture][I420Fingerprint]`：它在 `glReadPixels()` 后针对实际
  编码 I420 的 Y/U/V 平面输出固定网格指纹、均值和 `yHorizontalMirrorMad`，只记录首 3 帧与每 30 帧，不得输出
  原始摄像头像素或将其写入磁盘。
- 若 Android/iOS 接收端也出现鸿蒙发布流的上下黑边，使用同一帧的
  `[OhosCapture][OesFingerprint]`、`[OhosCapture][I420Fingerprint]` 与
  `[OhosCapture][SourceAdapt]`。前两者的 `bands(top/middle/bottom)` 和
  `nearBlackPermille(top/middle/bottom)` 只统计三段亮度与近黑像素比例：顶/底接近 `1000` 而中段明显较低，表示
  黑边已在该边界出现。OES 已出现则归因于模拟器/相机 producer；只有 I420 出现则归因于纹理转 I420；两处都没有
  而远端仍有黑边，才继续排查 SourceAdapter、编码器或接收方。`SourceAdapt` 会输出原始尺寸、rotation、逻辑尺寸、
  crop 与 output，以确认旋转元数据是否导致错误的裁切/缩放。
- 当 Android/iOS 发布到鸿蒙均首帧后静止，应同时检索 `[OhosRtpIngress]`。它在 RTP transport 收包、SRTP/media
  demux 前按 SSRC 记录首 3 包与每 120 包：SSRC 计数停止说明没有后续视频包进入鸿蒙 WebRTC；SSRC 继续增长而
  `[XComponentVideo][Input]` 停止，才排查鸿蒙的 SRTP、demux 或解码层。
