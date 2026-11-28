# CapuLife Native

成都航空职业技术大学校园应用的 Flutter 原生重构版。项目以原 CapuLife 的布局、字体、配色和本地数据模型为基准，用原生 Flutter + Android 平台通道重写，数据默认只保存在本机。

> 非学校官方应用。课表等数据来自学校 WebVPN/教务系统页面，登录和读取由用户本人在应用内完成。

## 功能

- 首页：今日课程、待办、倒计日、记账与电费概览
- 课表：手动编辑、WebVPN 课表提取、日/周视图、周次同步与课程提醒
- 事务：待办、倒计日、记账、电费、贴吧入口
- 记账：本地账本、预算、分类统计、AA、账单搜索、通知/无障碍页面自动记账
- 电费：龙泉/新都校区寝室绑定与余额查询
- 贴吧：成航吧信息流、热榜/推荐、帖子详情、楼中楼回复、点赞、收藏、搜索、消息、登录与发帖
- 通知：课程、待办、倒计日提醒；付款通知识别
- 更新：启动静默检查、应用内下载 APK 并调用系统安装器

## 构建

环境：Flutter 3.50+ / Dart 3.14+，Android SDK，JDK 17。

```bash
flutter pub get
flutter analyze
flutter build apk --release --target-platform android-arm64
```

应用 ID 为 `com.capulife.native`。Release 签名配置在 `android/key.properties`，该文件与 keystore 均不纳入版本控制。

## 数据与隐私

- 账号、课表、成绩、账本、待办等只写入应用私有目录。
- 贴吧登录在百度网页完成，应用只读取贴吧域名下的 Cookie 用于后续请求。
- 无障碍页面记账只在本机解析支付成功页，生成待确认账单，不保存聊天内容。
- 仓库不包含签名密钥、用户 Cookie 或真实账号数据。

## 开源协议

本项目以 **GNU General Public License v3.0** 发布，见 [LICENSE](LICENSE)。

协议核心逻辑和界面设计参考了以下 GPL-3.0 项目，详见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)：

- [TiebaFrosted](https://github.com/ashshay/TiebaFrosted)
- [TiebaLite](https://github.com/HuanCheng65/TiebaLite)
- [ControlECO](https://github.com/ArrogHie/ControlECO)

由于包含上述 GPL 代码的移植，本项目整体按 GPL-3.0 分发；二次分发 APK 时需同时提供对应源码。