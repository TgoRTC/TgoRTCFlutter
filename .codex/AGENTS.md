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

## 2. 产物组成与不可混用规则

一次可运行的 Debug 鸿蒙 SDK 由下列三部分组成，必须来自**同一次 Flutter 构建**并整体更新：

1. `tgortc-<version>.har`：ArkTS RTC 桥接层。
2. `flutter.har`：Flutter 运行时（含 `libflutter.so`）。
3. `flutter_assets/`：Dart 代码和资源。

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

在仓库根目录执行（与 DevEco Studio 使用同一套 Hvigor）：

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

## 4. 生成匹配的 Flutter 运行包与完整资源

每当修改 Dart 代码（尤其 `lib/bridge/` 下的事件、MethodChannel 或序列化逻辑）后，都必须重新生成 Flutter 运行产物：

```bash
/usr/local/Caskroom/flutter/harmonyos_flutter/flutter_ohos/bin/flutter build hap --debug
```

该命令会同时生成：

```text
ohos/har/flutter.har
ohos/entry/src/main/resources/rawfile/flutter_assets/
```

其中 `flutter_assets/` 才是用于分发的完整目录；不要用 `build/ohos/flutter_assets/` 替代，因为该目录可能仅含普通资源，漏掉 `kernel_blob.bin` 和 `icudtl.dat`。

将同次构建产物导出到 `dist/`：

```bash
cp -p ohos/har/flutter.har dist/flutter.har
mkdir -p dist/flutter_assets
cp -Rp ohos/entry/src/main/resources/rawfile/flutter_assets/. dist/flutter_assets/
cp -p ohos/tgortc_library/build/default/outputs/default/tgortc_library.har \
  dist/tgortc-<version>.har
```

发布前核查关键文件：

```bash
find dist/flutter_assets -maxdepth 2 -type f | sort
du -sh dist/flutter.har dist/flutter_assets dist/tgortc-<version>.har
```

如需发布 Release 包，使用 `flutter build hap --release` 重新生成整套产物；不要将 Debug 的 Flutter 资源与 Release 运行时混用。

## 5. 集成方更新步骤

集成方需要一次性取得 `dist/` 中的以下内容：

```text
tgortc-<version>.har
flutter.har
flutter_assets/        # 整个目录，保持层级
```

推荐流程：

1. 替换其工程引用的 `tgortc-<version>.har`。
2. 替换其工程 `ohos/har/flutter.har`。
3. **先清空**其 `entry/src/main/resources/rawfile/flutter_assets/` 的旧内容，再完整复制新的 `flutter_assets/` 内容。
4. 在 DevEco Studio 重新执行 `ohpm install` / Sync，然后构建并安装新的 HAP。

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
