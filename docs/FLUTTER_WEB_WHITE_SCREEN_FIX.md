# Flutter Web 白屏问题解决方案

## 问题描述

在 Chrome 浏览器中运行 Flutter Web 应用时，出现以下错误：

```
Error: TypeError: Failed to fetch dynamically imported module:
https://www.gstatic.com/flutter-canvaskit/1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f/chromium/canvaskit.js
```

应用显示白屏，无法正常加载。

## 问题原因

### 1. CanvasKit 加载失败
Flutter Web 默认使用 CanvasKit 作为渲染引擎，它需要从 Google CDN 下载：
- `https://www.gstatic.com/flutter-canvaskit/.../canvaskit.js`
- 文件大小约 2-3 MB

### 2. 网络访问受限
在中国大陆等地区，Google 的 CDN 服务可能被限制访问，导致：
- 无法下载 CanvasKit 文件
- 加载超时
- 应用无法启动

### 3. CDN 连接问题
即使网络正常，也可能因为：
- DNS 解析失败
- 防火墙阻止
- 网络不稳定

## 解决方案

### ✅ 方案 1：禁用 CDN 资源（推荐）

使用命令行参数禁用 CDN 资源加载：

```bash
flutter run -d chrome --no-web-resources-cdn
```

**优点：**
- ✅ 简单直接，无需修改代码
- ✅ 不依赖外部 CDN
- ✅ 启动速度快
- ✅ 兼容性好

**缺点：**
- ⚠️ 可能增加首次加载时间（需要下载更多本地资源）

### 方案 2：使用 HTML 渲染器

修改 `web/index.html`，添加 Flutter 配置：

```html
<body>
  <script>
    // 配置 Flutter Web 使用 HTML 渲染器（避免 CanvasKit 加载失败）
    window.flutterConfiguration = {
      renderer: 'html',
    };
  </script>
  <script src="flutter_bootstrap.js" async></script>
</body>
```

**注意：** 此方法在新版 Flutter 中已弃用，建议使用方案 1。

**优点：**
- 不需要下载额外的 CanvasKit 文件
- 启动速度快
- 不依赖 Google CDN
- 兼容性好

**缺点：**
- 性能略低于 CanvasKit
- 某些高级图形功能可能不可用

### 方案 3：使用本地 CanvasKit

如果需要 CanvasKit 的性能，可以下载到本地：

1. 下载 CanvasKit 文件：
```bash
mkdir -p web/canvaskit
cd web/canvaskit
curl -O https://www.gstatic.com/flutter-canvaskit/1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f/chromium/canvaskit.js
```

2. 修改 `web/index.html`：
```html
<script>
  window.flutterConfiguration = {
    renderer: 'canvaskit',
    assetBase: './canvaskit/',
  };
</script>
```

**优点：**
- 保持高性能渲染
- 不依赖外部 CDN

**缺点：**
- 需要手动下载和更新 CanvasKit
- 增加应用包大小

### 方案 4：使用镜像 CDN

配置使用国内镜像：

```html
<script>
  window.flutterConfiguration = {
    renderer: 'canvaskit',
    assetBase: 'https://cdn.flutter-io.cn/',
  };
</script>
```

**注意：** 需要确认镜像 CDN 的可用性和版本匹配。

## 推荐配置

对于大多数应用，**方案 1（禁用 CDN）** 是最佳选择：

1. ✅ 无需额外配置
2. ✅ 启动速度快
3. ✅ 不依赖外部资源
4. ✅ 兼容性好
5. ✅ 适合大多数业务应用

## 测试验证

修改后，重新运行应用：

```bash
flutter run -d chrome --no-web-resources-cdn
```

应该能够正常启动，不再出现白屏。

## 性能对比

| 渲染器 | 性能 | 启动速度 | 包大小 | 兼容性 |
|--------|------|----------|--------|--------|
| CanvasKit | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | +2-3 MB | ⭐⭐⭐⭐ |
| HTML | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 无额外 | ⭐⭐⭐⭐⭐ |

## 注意事项

1. **HTML 渲染器限制：**
   - 不支持某些高级图形效果
   - 文本渲染可能略有差异
   - 动画性能略低

2. **何时使用 CanvasKit：**
   - 需要高性能图形渲染
   - 复杂的动画效果
   - 游戏 or 图形密集型应用

3. **混合使用：**
   可以根据设备性能动态选择渲染器：

```javascript
const isHighPerformanceDevice = /* 检测设备性能 */;
window.flutterConfiguration = {
  renderer: isHighPerformanceDevice ? 'canvaskit' : 'html',
};
```

## 相关文档

- [Flutter Web 渲染器](https://docs.flutter.dev/platform-integration/web/renderers)
- [Flutter Web 性能优化](https://docs.flutter.dev/perf/web-performance)
- [CanvasKit 文档](https://github.com/flutter/engine/blob/main/lib/web_ui/lib/src/engine/canvaskit/README.md)
