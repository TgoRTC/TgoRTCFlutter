# tgortcflutter 鸿蒙（OHOS）平台适配改造步骤

本文档根据以下参考整理，仅描述**修改步骤**，不包含具体代码修改。实施前请先阅读对应官方/社区文档。

**参考文档与资源：**
- [OHOS平台适配 Flutter 三方库指导](https://gitee.com/openharmony-sig/flutter_samples/blob/master/ohos/docs/07_plugin/ohos%E5%B9%B3%E5%8F%B0%E9%80%82%E9%85%8Dflutter%E4%B8%89%E6%96%B9%E5%BA%93%E6%8C%87%E5%AF%BC.md)（Gitee）
- [鸿蒙版 Flutter 环境搭建指导](https://gitee.com/openharmony-sig/flutter_samples/blob/master/ohos/docs/03_environment/鸿蒙版Flutter环境搭建指导.md)（Gitee）
- [HarmonyOS Flutter Practice: 05-Use third-party plug-ins](https://dev.to/shaohushuo/harmonyos-flutter-practice-05-use-third-party-plug-ins-1ohk)（DEV）
- [Adapting Flutter Plugins for OpenHarmony (OHOS)](https://forem.com/flfljh/adapting-flutter-plugins-for-openharmony-ohos-1ek2)（Forem）
- 华为开发者博客：<https://developer.huawei.com/consumer/cn/blog/topic/03191269062405177>

**鸿蒙版依赖仓库：**
- flutter_webrtc 鸿蒙版：<https://gitcode.com/openharmony-sig/fluttertpc_flutter_webrtc>（分支 `br_v1.2.1_ohos`）
- livekit_client 鸿蒙版：<https://gitcode.com/openharmony-sig/fluttertpc_livekit_client>
- 鸿蒙 Flutter 引擎与示例：<https://gitcode.com/openharmony-tpc/flutter_flutter>、<https://gitcode.com/openharmony-tpc/flutter_samples>

---

## 一、环境准备

### 1.1 鸿蒙版 Flutter SDK

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 1.1.1 | 无 | 阅读《鸿蒙版 Flutter 环境搭建指导》中「Flutter SDK」相关章节 | 明确需使用的 Flutter 渠道（如 OpenHarmony-TPC 或文档指定仓库） |
| 1.1.2 | 1.1.1 | 按文档下载或克隆鸿蒙版 Flutter SDK 到本地目录 | 目录中存在 `bin/flutter` 可执行文件 |
| 1.1.3 | 1.1.2 | 将鸿蒙版 Flutter 的 `bin` 目录加入系统 `PATH`，并确保优先于系统/其他 Flutter | 在终端执行 `which flutter` 指向该 SDK 的 `bin/flutter` |
| 1.1.4 | 1.1.3 | 执行 `flutter --version`，记录 Flutter 与 Dart 版本号 | 版本与文档要求一致，并记录下来供后续步骤对照 |

### 1.2 DevEco Studio 与 HarmonyOS SDK

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 1.2.1 | 无 | 从华为/OpenHarmony 官方渠道下载并安装 DevEco Studio | 能正常启动 DevEco Studio |
| 1.2.2 | 1.2.1 | 在 DevEco 中通过 SDK Manager 安装 HarmonyOS SDK（含 API 版本、工具链） | SDK 路径可查，且文档要求的 API 级别已安装 |
| 1.2.3 | 1.2.2 | 在《鸿蒙版 Flutter 环境搭建指导》中查找需配置的环境变量名（如 `OHOS_SDK_HOME` 等） | 列出所有需设置的变量名与示例值 |
| 1.2.4 | 1.2.3 | 在系统或 shell 配置文件中设置上述环境变量，并 `source` 或重启终端 | 在终端中 `echo $OHOS_SDK_HOME`（或等价变量）能输出有效路径 |

### 1.3 Flutter OHOS 镜像与工具链

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 1.3.1 | 1.1.4 | 按《鸿蒙版 Flutter 环境搭建指导》配置 Flutter 使用的 pub/分析等镜像（若有专门 OHOS 镜像） | 文档中提到的镜像相关环境变量已配置 |
| 1.3.2 | 1.3.1 | 执行 `flutter doctor`，查看输出中与「OHOS」「Harmony」相关的项 | 明确哪些项必须为 ✓，哪些为可选 |
| 1.3.3 | 1.3.2 | 根据 `flutter doctor` 提示补齐缺失依赖（如 ADB 路径、设备连接等） | `flutter doctor` 中鸿蒙相关项无阻塞性错误 |

### 1.4 设备与模拟器

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 1.4.1 | 1.2.2 | 按文档创建或连接鸿蒙设备/模拟器（真机需开启开发者模式、USB 调试等） | 在 DevEco 或设备管理中能看到设备 |
| 1.4.2 | 1.4.1、1.1.3 | 在项目外任意目录执行 `flutter devices` | 列表中出现鸿蒙设备，并记录其 `<device-id>` 供后续使用 |

### 1.5 Flutter / Dart 版本与工程一致性

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 1.5.1 | 1.1.4 | 打开 [fluttertpc_flutter_webrtc](https://gitcode.com/openharmony-sig/fluttertpc_flutter_webrtc) 的 README 或 `pubspec.yaml`，记录其要求的 Flutter / Dart / SDK 约束 | 得到「最低 / 推荐」版本或范围 |
| 1.5.2 | 同上 | 打开 [fluttertpc_livekit_client](https://gitcode.com/openharmony-sig/fluttertpc_livekit_client) 的 README 或 `pubspec.yaml`，记录其 Flutter / Dart / SDK 约束 | 得到其版本要求 |
| 1.5.3 | 1.5.1、1.5.2 | 取两个仓库要求的交集（或 README 中明确写明的「推荐组合」） | 确定本工程拟使用的 Flutter、Dart、SDK 版本 |
| 1.5.4 | 1.5.3 | 若当前主包或 example 的 `pubspec.yaml` 中 `environment.sdk` / `environment.flutter` 与上述不一致，则计划在后续步骤中修改 | 明确要在「主包 pubspec」「example pubspec」中改动的字段与目标值 |

---

## 二、为工程添加 OHOS 平台

### 2.1 主包添加 OHOS 平台

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 2.1.1 | 一已完成 | 进入项目根目录 `tgortcflutter/`，确认当前无 `ohos/` 目录 | 根目录下仅有 android、ios、linux、macos、web、windows 等，无 ohos |
| 2.1.2 | 2.1.1 | 若担心覆盖，对根目录做一次完整备份（如拷贝为 `tgortcflutter_backup`） | 备份目录存在且可访问 |
| 2.1.3 | 2.1.2 | 在根目录执行：`flutter create --platforms ohos .` | 命令执行无报错，且根目录下出现 `ohos/` |
| 2.1.4 | 2.1.3 | 若命令报错或未生成 `ohos/`，则打开 [flutter_samples](https://gitcode.com/openharmony-tpc/flutter_samples)，找一个含 `ohos/` 的示例工程，下载其 `ohos/` 目录结构 | 得到一份可用的 `ohos/` 模板目录 |
| 2.1.5 | 2.1.4（仅在 2.1.3 失败时） | 将示例中的 `ohos/` 拷贝到本工程根目录，并按示例的 `pubspec.yaml` 中 `name` 等字段，把 `ohos/` 内工程名、包名等占位符替换为本工程（tgortcflutter） | 本工程根目录下存在 `ohos/`，且其中工程标识与本工程一致 |

### 2.2 主包 ohos 目录结构核对

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 2.2.1 | 2.1.3 或 2.1.5 | 打开 `tgortcflutter/ohos/`，确认存在 DevEco 可识别的工程结构 | 通常包含 `entry/`、`oh-package.json5`、ArkTS 入口等（以《鸿蒙版 Flutter 环境搭建指导》或 flutter_samples 为准） |
| 2.2.2 | 2.2.1 | 若有 `oh-package.json5`，打开并确认 `name`、`dependencies` 等与文档/示例一致 | 无语法错误，且未缺少文档要求的依赖 |
| 2.2.3 | 2.2.2 | 在《鸿蒙版 Flutter 环境搭建指导》或 flutter_samples 中查找「Flutter 与 OHOS 工程映射」说明（如 entry 对应宿主、资源目录等） | 能说清 `ohos/` 下各子目录的角色 |

### 2.3 example 应用添加 OHOS 平台

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 2.3.1 | 2.2 已完成 | 进入 `tgortcflutter/example/`，确认当前无 `ohos/` | example 目录下无 ohos |
| 2.3.2 | 2.3.1 | 在 `example/` 下执行：`flutter create --platforms ohos .` | 命令成功，且 `example/ohos/` 生成 |
| 2.3.3 | 2.3.2 | 若失败，则从 flutter_samples 的 example 中拷贝 `ohos/` 到本工程 `example/`，并替换工程名/包名为本 example（如 tgortc_example） | `example/ohos/` 存在且工程名正确 |

### 2.4 example 的 ohos 目录结构核对

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 2.4.1 | 2.3.2 或 2.3.3 | 打开 `example/ohos/`，确认具备 entry、oh-package 等与主包 ohos 类似的结构 | 与 2.2 的核对要点一致，且为「应用」形态（可单独运行） |
| 2.4.2 | 2.4.1 | 确认 example 的 ohos 工程中，对 Flutter 引擎/运行时的依赖路径与主包或文档一致（如通过相对路径或配置指向同一 Flutter 运行时） | 文档或示例中要求的依赖关系已满足 |

---

## 三、依赖替换：使用鸿蒙版 flutter_webrtc 与 livekit_client

### 3.1 确认鸿蒙版仓库信息

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 3.1.1 | 无 | 打开 [fluttertpc_flutter_webrtc](https://gitcode.com/openharmony-sig/fluttertpc_flutter_webrtc)，在 README 或首页查看「鸿蒙分支」「包路径」说明 | 记录：仓库 URL、鸿蒙分支名（如 `br_v1.2.1_ohos`）、包在仓库中的 path（根目录或子路径，如 `packages/flutter_webrtc`） |
| 3.1.2 | 无 | 打开 [fluttertpc_livekit_client](https://gitcode.com/openharmony-sig/fluttertpc_livekit_client)，同样记录：仓库 URL、OHOS 分支、包 path | 得到 livekit_client 的 git + ref + path 三要素 |
| 3.1.3 | 3.1.1、3.1.2 | 在 fluttertpc_livekit_client 的 README 或 pubspec 中查看其依赖的 flutter_webrtc 写法（分支/路径） | 若有「推荐与 fluttertpc_flutter_webrtc 某分支配套使用」的说明，则采用该组合 |

### 3.2 在主包 pubspec.yaml 中增加 dependency_overrides

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 3.2.1 | 3.1 已完成 | 打开主包 `tgortcflutter/pubspec.yaml`，在文件末尾或合适位置新增一级键 `dependency_overrides:`（若已存在则在其下追加） | 不会破坏现有 YAML 缩进与结构 |
| 3.2.2 | 3.2.1 | 在 `dependency_overrides` 下为 `flutter_webrtc` 增加一条覆盖：来源为 `git`，`url` 为 3.1.1 记录的仓库 URL，`ref` 为 3.1.1 记录的分支；若包不在根目录，则增加 `path` 为 3.1.1 记录的 path | YAML 语法正确，且与《OHOS平台适配 Flutter 三方库指导》中 git 依赖写法一致 |
| 3.2.3 | 3.2.2 | 在 `dependency_overrides` 下为 `livekit_client` 增加一条覆盖：同样使用 `git` + `url` + `ref`（及必要时 `path`），取值来自 3.1.2、3.1.3 | 两条 overrides 均填写完整，且 ref 与各仓库推荐组合一致 |
| 3.2.4 | 3.2.3 | 若 1.5.4 中计划修改主包 `environment`，在本步骤一并修改并保存 | `environment.sdk` / `environment.flutter` 与 1.5.3 一致 |

### 3.3 执行 pub get 并检查 lock 是否使用鸿蒙版

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 3.3.1 | 3.2 已完成 | 在项目根目录 `tgortcflutter/` 执行 `flutter pub get` | 无报错完成 |
| 3.3.2 | 3.3.1 | 打开 `pubspec.lock`，搜索 `flutter_webrtc` 与 `livekit_client` 的 `source`、`description` | 两者来源为 `git`，且 `url`/`resolved` 指向上述鸿蒙版仓库与分支 |
| 3.3.3 | 3.3.2 | 若 lock 中仍是 `source: hosted` 或非鸿蒙仓库，则判定 dependency_overrides 未生效，进入 3.4 | 明确「是否已生效」的结论 |

### 3.4 当 dependency_overrides 未生效时使用 pubspec_overrides.yaml

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 3.4.1 | 3.3.3 判定未生效 | 在项目根目录 `tgortcflutter/` 下新建或打开 `pubspec_overrides.yaml` | 文件存在且可编辑 |
| 3.4.2 | 3.4.1 | 在 `pubspec_overrides.yaml` 中写入与主包 `pubspec.yaml` 完全一致的 `dependency_overrides` 内容（仅 overrides 部分，格式与 pubspec 中相同） | 语法正确，且包含 flutter_webrtc、livekit_client 两条 |
| 3.4.3 | 3.4.2 | 保存后，在根目录再次执行 `flutter pub get` | 命令成功 |
| 3.4.4 | 3.4.3 | 再次打开 `pubspec.lock`，按 3.3.2 检查 | 两个依赖已解析为鸿蒙版 git 源 |

### 3.5 传递依赖与版本兼容

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 3.5.1 | 3.3 或 3.4 已通过 | 在 `pubspec.lock` 中查看 `livekit_client` 的依赖树，确认其依赖的 `flutter_webrtc` 版本或来源 | 若为 git，确认与 3.2 中 overrides 的仓库/分支一致或兼容 |
| 3.5.2 | 3.5.1 | 若出现「livekit_client 要求某版本 flutter_webrtc，而 overrides 指向另一分支」等冲突，以 fluttertpc_livekit_client、fluttertpc_flutter_webrtc 的 README/issue 推荐组合为准，回头调整 3.2 中的 ref/path | 无版本冲突，或冲突已按官方推荐方式解决 |

---

## 四、example 的依赖与运行配置

### 4.1 确保 example 使用主包的 overrides 结果

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 4.1.1 | 三已完成 | 在 `example/` 目录执行 `flutter pub get` | 命令成功 |
| 4.1.2 | 4.1.1 | 打开 `example/pubspec.lock`，搜索 `flutter_webrtc`、`livekit_client` 的 source | 与主包 `pubspec.lock` 一致，均为鸿蒙版 git 源 |
| 4.1.3 | 4.1.2 | 若 example 的 lock 中仍为非鸿蒙版，则在 **example** 的 `pubspec.yaml` 中增加与主包相同的 `dependency_overrides` 段（或使用 `pubspec_overrides.yaml` 置于 example 目录），再在 example 下执行 `flutter pub get` | example 的 lock 中已为鸿蒙版 |

### 4.2 example 的 environment 与主包一致（若 1.5.4 有计划）

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 4.2.1 | 1.5.4、3.2.4 | 打开 `example/pubspec.yaml`，检查 `environment.sdk` 等是否与主包一致 | 与主包及 1.5.3 确定的版本一致，避免在 example 中拉错 SDK |

### 4.3 DevEco 中配置 example 的 OHOS 签名

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 4.3.1 | 2.4 已完成 | 使用 DevEco Studio 打开 `tgortcflutter/example/ohos`（或文档指定的「用 DevEco 打开」的路径） | 工程能正常加载，无红色报错 |
| 4.3.2 | 4.3.1 | 在 DevEco 中打开 Project Structure（或 File > Project Structure），进入 Signing Configs 相关配置页 | 能看到签名/证书配置项 |
| 4.3.3 | 4.3.2 | 按《鸿蒙版 Flutter 环境搭建指导》或 [Adapting Flutter Plugins for OpenHarmony](https://forem.com/flfljh/adapting-flutter-plugins-for-openharmony-ohos-1ek2) 中「Configure Example」的说明，勾选自动生成签名或配置调试签名 | 签名配置已保存，工程可构建 |

### 4.4 在鸿蒙设备上运行 example

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 4.4.1 | 4.3、1.4.2 | 在 `example/` 目录执行 `flutter pub get`（若 4.1 之后未再改依赖可省略） | 无报错 |
| 4.4.2 | 4.4.1 | 执行 `flutter run -d <device-id>`，其中 `<device-id>` 替换为 1.4.2 记录的鸿蒙设备 id | 应用能安装并启动在鸿蒙设备/模拟器上 |
| 4.4.3 | 4.4.2 | 若报「找不到 OHOS 设备」，回到《鸿蒙版 Flutter 环境搭建指导》核对设备连接、`flutter devices` 与 IDE 中的 device-id 是否一致 | 能列出设备并成功 run |

---

## 五、按需处理其他依赖的鸿蒙替代

### 5.1 列出所有传递依赖并识别平台实现

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 5.1.1 | 三、四已完成 | 在主包根目录执行 `flutter pub get` 后，打开 `pubspec.lock`，从根依赖 `tgortcflutter` 起遍历其依赖树（或使用 `flutter pub deps` 等） | 得到完整依赖列表或树状图 |
| 5.1.2 | 5.1.1 | 在 lock 或 deps 输出中，逐一识别「带 platform 的插件」（如包名含 `_android`、`_ios`、或 description 中出现 platform 实现） | 列出所有「可能有原生实现」的包名 |
| 5.1.3 | 5.1.2 | 在 Gitee OpenHarmony-SIG、gitcode 中搜索上述包名 + 「ohos」「openharmony」「鸿蒙」等关键词 | 标记出已有鸿蒙/OHOS 适配版的包及仓库 URL、分支、path |

### 5.2 为缺失鸿蒙实现的依赖添加 overrides

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 5.2.1 | 5.1.3 中已有鸿蒙版的包 | 在主包 `pubspec.yaml` 的 `dependency_overrides` 中，为这些包增加与 3.2 写法一致的 `git` 覆盖（url、ref、path） | 每增加一条后保存，YAML 仍合法 |
| 5.2.2 | 5.2.1 | 若 overrides 不生效，同样在 `pubspec_overrides.yaml` 中追加上述条目，再执行 `flutter pub get` | pubspec.lock 中对应包已指向鸿蒙源 |
| 5.2.3 | 5.2.2 | 对 example 重复 4.1：在 example 下执行 `flutter pub get`，必要时在 example 的 pubspec 或 pubspec_overrides 中同步 overrides | example 的 lock 与主包对齐 |

### 5.3 参考 path_provider 的 overrides 写法（可选）

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 5.3.1 | 需为「非 flutter_webrtc / livekit_client」的依赖写 overrides 时 | 在《OHOS平台适配 Flutter 三方库指导》或 [Use third-party plug-ins](https://dev.to/shaohushuo/harmonyos-flutter-practice-05-use-third-party-plug-ins-1ohk) 中查看 path_provider 的示例：`dependency_overrides` 中 `git` + `url` + `path`（及 `ref`）的写法 | 按同一格式为本项目其余依赖填写鸿蒙版 |

---

## 六、插件与原生配置（若有 native 行为）

### 6.1 确认主包与 example 是否含原生插件代码

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 6.1.1 | 无 | 查看主包 `tgortcflutter/pubspec.yaml` 是否存在 `flutter.plugin.platforms` 或 `plugin` 段且声明了 android/ios 等 | 若有，则主包为插件包；若无，则主包为纯 Dart 包 |
| 6.1.2 | 6.1.1 | 查看主包下是否存在 `android/`、`ios/` 等目录且内含插件实现（非 example 的 android/ios） | 明确「主包是否自带原生实现」 |
| 6.1.3 | 6.1.2 | 若主包为纯 Dart 包、仅依赖 livekit_client 与 flutter_webrtc，则鸿蒙侧无需在本仓库内新建 ohos 插件实现，依赖 三、四、五 的 overrides 即可 | 结论记录：本仓库「需要 / 不需要」自建 ohos 插件 |

### 6.2 若将来需在本仓库增加鸿蒙插件（可选扩展）

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 6.2.1 | 规划中要在本仓库为 tgortcflutter 或 example 增加鸿蒙专用插件 | 按《Adapting Flutter Plugins for OpenHarmony》流程：创建 OHOS 模块、调整 Dart 与 pubspec、开发 ArkTS、生成 HAR、在 example 的 ohos 工程中配置依赖与运行 | 以该文为准，此处不展开子步骤 |

---

## 七、验证与迭代

### 7.1 编译与运行验证

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 7.1.1 | 四已完成 | 在主包根目录执行 `flutter pub get` | 成功 |
| 7.1.2 | 7.1.1 | 在 `example/` 执行 `flutter pub get`，再执行 `flutter run -d <ohos-device-id>` | 应用在鸿蒙设备上成功安装并启动 |
| 7.1.3 | 7.1.2 | 若出现「找不到 OHOS 设备」，对照《鸿蒙版 Flutter 环境搭建指导》检查：USB 连接、开发者选项、`flutter devices` 与 IDE 的 device-id 一致性 | 能稳定识别设备并 run |

### 7.2 功能与兼容性验证

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 7.2.1 | 7.1.2 | 在鸿蒙设备上操作 example：进入房间、开启/关闭音视频、挂断等 | 核心流程无崩溃、无明显逻辑错误 |
| 7.2.2 | 7.2.1 | 打开 fluttertpc_flutter_webrtc、fluttertpc_livekit_client 的 README / issue，查阅「已知问题」「鸿蒙适配说明」「API 差异」 | 列出与当前业务相关的限制或必读项 |
| 7.2.3 | 7.2.2 | 若文档要求在某场景下使用不同参数或 API，在业务代码中做最小改动并加注释「鸿蒙适配」 | 行为符合鸿蒙版文档要求，且不影响 Android/iOS |

### 7.3 后续迭代

| 子步骤 | 前置条件 | 执行动作 | 校验标准 |
|--------|----------|----------|----------|
| 7.3.1 | 鸿蒙版仓库发布新分支/标签时 | 将主包（及必要时 example）的 `dependency_overrides` 中对应包的 `ref` 或 `path` 更新为推荐版本 | 更新后执行 `flutter pub get` 与 7.1、7.2 再验证一遍 |
| 7.3.2 | 发现鸿蒙与 Android/iOS 行为不一致且需改 Dart 逻辑时 | 在对应业务文件中做条件分支或参数调整，并加注释说明仅用于鸿蒙 | 便于后续维护与排查 |

---

## 八、步骤清单速览（细分子步编号）

便于按「编号」逐项打勾使用。

| 序号 | 步骤摘要 | 对应章节 |
|------|----------|----------|
| 1.1.1–1.1.4 | 鸿蒙版 Flutter SDK 获取、PATH、版本确认 | 1.1 |
| 1.2.1–1.2.4 | DevEco 与 HarmonyOS SDK 安装、环境变量 | 1.2 |
| 1.3.1–1.3.3 | 镜像与 flutter doctor、依赖补齐 | 1.3 |
| 1.4.1–1.4.2 | 设备/模拟器、flutter devices 与 device-id | 1.4 |
| 1.5.1–1.5.4 | 对照鸿蒙版仓库确定 Flutter/Dart 版本及工程修改计划 | 1.5 |
| 2.1.1–2.1.5 | 主包根目录添加 ohos 平台（含失败时拷贝示例） | 2.1 |
| 2.2.1–2.2.3 | 主包 ohos 目录结构、oh-package、文档对照 | 2.2 |
| 2.3.1–2.3.3 | example 添加 ohos 平台 | 2.3 |
| 2.4.1–2.4.2 | example ohos 结构核对与依赖关系 | 2.4 |
| 3.1.1–3.1.3 | 鸿蒙版 flutter_webrtc、livekit_client 的 url/ref/path 与推荐组合 | 3.1 |
| 3.2.1–3.2.4 | 主包 pubspec 中 dependency_overrides 及 environment | 3.2 |
| 3.3.1–3.3.3 | pub get、检查 lock、判断 overrides 是否生效 | 3.3 |
| 3.4.1–3.4.4 | pubspec_overrides.yaml 编写与再次 pub get、lock 校验 | 3.4 |
| 3.5.1–3.5.2 | 传递依赖、livekit_client 与 flutter_webrtc 版本兼容 | 3.5 |
| 4.1.1–4.1.3 | example 继承/同步 overrides，保证 example lock 为鸿蒙版 | 4.1 |
| 4.2.1 | example 的 environment 与主包一致 | 4.2 |
| 4.3.1–4.3.3 | DevEco 打开 example/ohos、签名配置 | 4.3 |
| 4.4.1–4.4.3 | example 下 flutter run -d 鸿蒙设备、设备不可见时的排查 | 4.4 |
| 5.1.1–5.1.3 | 传递依赖列表、平台实现识别、鸿蒙适配版检索 | 5.1 |
| 5.2.1–5.2.3 | 为其他依赖加 overrides、必要时 pubspec_overrides、example 同步 | 5.2 |
| 5.3.1 | 参考 path_provider 写法为其余依赖写 overrides | 5.3 |
| 6.1.1–6.1.3 | 判断主包是否为插件包、是否需自建 ohos 插件 | 6.1 |
| 6.2.1 | 若将来自建鸿蒙插件，按 Adapting 文档执行 | 6.2 |
| 7.1.1–7.1.3 | 主包与 example 的 pub get、flutter run、设备识别 | 7.1 |
| 7.2.1–7.2.3 | 业务功能验证、已知问题对照、鸿蒙相关代码改动与注释 | 7.2 |
| 7.3.1–7.3.2 | 依赖版本升级、鸿蒙差异的 Dart 侧迭代 | 7.3 |

实施时请以 Gitee/GitCode 上的最新文档与各仓库 README 为准，本步骤为归纳性指导，不替代官方说明。
