# TgoRTC Flutter Example

这是 TgoRTC Flutter SDK 的示例应用，演示如何使用 SDK 实现多人音视频通话功能。

## 功能特性

- 📱 连接 TgoRTC Server 服务
- 🏠 创建或加入房间
- 📹 多人视频通话（网格布局显示）
- 🎤 麦克风开关控制
- 📷 摄像头开关控制
- 📞 挂断通话

## API 接口

本示例使用以下 TgoRTC Server API：

### 创建房间
```
POST /api/v1/rooms
```

### 加入房间
```
POST /api/v1/rooms/{roomId}/join
```

### 离开房间
```
POST /api/v1/rooms/{roomId}/leave
```

## 运行示例

### 1. 安装依赖

```bash
cd example
flutter pub get
```

### 2. 配置权限

#### Android

权限已在 `android/app/src/main/AndroidManifest.xml` 中配置。

#### iOS

权限已在 `ios/Runner/Info.plist` 中配置。

### 3. 运行应用

```bash
flutter run
```

## 使用说明

1. 在首页输入 TgoRTC Server 地址（如：192.168.1.100:8080）
2. 输入房间号
3. 点击「创建房间」创建新房间，或点击「加入房间」加入已有房间
4. 在通话页面：
   - 点击麦克风按钮切换静音
   - 点击摄像头按钮开关摄像头
   - 点击挂断按钮结束通话

## 项目结构

```
example/
├── lib/
│   ├── main.dart              # 应用入口
│   ├── pages/
│   │   ├── home_page.dart     # 首页（输入连接信息）
│   │   └── call_page.dart     # 通话页面（多人视频）
│   └── services/
│       └── tgortc_api.dart    # TgoRTC Server API 服务
├── android/                   # Android 平台配置
├── ios/                       # iOS 平台配置
└── pubspec.yaml              # 项目依赖
```

## 依赖

- `tgortcflutter` - TgoRTC Flutter SDK
- `permission_handler` - 权限管理
- `http` - HTTP 请求
