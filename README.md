# 我的记账

一个离线、无账号、无服务器的 Flutter 安卓个人记账应用。账单使用 SQLite 保存在手机本地。

## V1 功能

- 首页展示本月收入、支出、余额和最近记录
- 记录收入或支出，支持分类、日期和备注
- 全部账单按日期倒序分组，点击可查看详情
- 月度收入、支出、结余和支出分类统计

## 开发运行

```powershell
flutter pub get
flutter run
```

## 构建 APK

```powershell
flutter build apk --release
```

输出文件位于 `build/app/outputs/flutter-apk/app-release.apk`。

> 当前 release 构建沿用 Flutter 模板的 debug 签名，适合个人侧载使用。如果以后发布应用商店，应配置独立签名密钥。
