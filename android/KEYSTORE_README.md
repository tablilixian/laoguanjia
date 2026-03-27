# Android Keystore 配置说明

## 概述

此配置用于Android应用的签名，确保在不同设备上打包的应用可以互相覆盖安装。

## 文件说明

### 1. keystore文件
- **路径**: `android/app/release-keystore.jks`
- **用途**: 存储签名密钥
- **类型**: Java KeyStore (JKS)

### 2. key.properties文件
- **路径**: `android/key.properties`
- **用途**: 存储keystore的访问信息
- **格式**: Properties文件

## 配置内容

### key.properties
```properties
storePassword=123456
keyPassword=123456
keyAlias=release
storeFile=android/app/release-keystore.jks
```

### keystore信息
- **别名**: release
- **密钥长度**: 2048位
- **有效期**: 10000天（约27年）
- **算法**: RSA

## 使用说明

### 在其他机器上使用

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd laoguanjia
   ```

2. **确保keystore文件存在**
   - `android/app/release-keystore.jks` 必须存在
   - `android/key.properties` 必须存在

3. **打包应用**
   ```bash
   # 打包APK
   flutter build apk --release

   # 打包App Bundle（推荐用于Google Play）
   flutter build appbundle --release
   ```

## 输出位置

### APK
- **路径**: `build/app/outputs/flutter-apk/app-release.apk`
- **用途**: 直接安装到Android设备

### App Bundle
- **路径**: `build/app/outputs/bundle/release/app-release.aab`
- **用途**: 上传到Google Play Store

## 替换keystore

如果需要使用正式的keystore：

1. **替换keystore文件**
   - 删除 `android/app/release-keystore.jks`
   - 复制新的keystore文件到 `android/app/release-keystore.jks`

2. **更新key.properties**
   - 修改 `android/key.properties` 中的密码和路径

3. **提交更改**
   ```bash
   git add android/app/release-keystore.jks android/key.properties
   git commit -m "更新keystore配置"
   git push
   ```

## 安全注意事项

⚠️ **重要提醒**：

1. **不要泄露keystore密码**
   - keystore密码：123456
   - key密码：123456
   - 别名：release

2. **备份keystore文件**
   - keystore文件丢失后无法恢复
   - 建议定期备份到安全位置

3. **版本管理**
   - 当前配置已提交到git
   - 可以在不同机器上使用
   - 确保keystore文件同步

## 故障排除

### 问题：找不到keystore文件
**解决方案**：
- 检查 `android/app/release-keystore.jks` 是否存在
- 检查 `android/key.properties` 中的路径是否正确

### 问题：签名失败
**解决方案**：
- 检查密码是否正确
- 检查key.properties文件格式
- 清理构建缓存：`flutter clean`

### 问题：无法覆盖安装
**解决方案**：
- 确保使用相同的签名密钥
- 检查versionCode是否递增
- 卸载旧版本后重新安装

## 测试

验证配置是否正确：

```bash
flutter build apk --release
```

如果成功，会在 `build/app/outputs/flutter-apk/` 目录下生成 `app-release.apk` 文件。

## 联系

如有问题，请检查：
1. `android/app/build.gradle.kts` 中的keystore配置
2. `android/key.properties` 文件内容
3. `android/app/release-keystore.jks` 文件是否存在