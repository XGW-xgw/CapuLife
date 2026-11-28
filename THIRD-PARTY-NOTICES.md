# Third-party notices

本项目以 GNU General Public License v3.0 发布。以下项目/资源的协议与用途一并列出。

## GPL-3.0 参考与移植来源

| 项目 | 许可 | 用途 |
| --- | --- | --- |
| [TiebaFrosted](https://github.com/ashshay/TiebaFrosted) | GPL-3.0 | 贴吧协议、登录流程、ProtoWire/图片上传、部分交互与容错逻辑参考及移植 |
| [TiebaLite](https://github.com/HuanCheng65/TiebaLite) | GPL-3.0 | 贴吧客户端协议行为的原始参考（经 TiebaFrosted 转写） |
| [ControlECO](https://github.com/ArrogHie/ControlECO) | GPL-3.0 | 无障碍页面记账的解析思路、应用内更新与安装流程参考 |

这些项目均为 GPL-3.0。相关衍生代码继续按 GPL-3.0 分发。

## 字体

| 资源 | 许可 |
| --- | --- |
| Manrope (`assets/fonts/Manrope-*.ttf`) | SIL Open Font License 1.1 |
| Fraunces (`assets/fonts/Fraunces-*.ttf`) | SIL Open Font License 1.1 |

## 图标

- `assets/icons/*.svg`：Lucide icons，ISC License。

## Flutter 依赖

完整依赖见 `pubspec.lock`；主要直接依赖：

| 包 | 许可 |
| --- | --- |
| Flutter / Material | BSD-3-Clause |
| cupertino_icons | MIT |
| flutter_svg | MIT |
| flutter_lints（开发依赖） | BSD-3-Clause |

Flutter 在构建 APK 时会生成完整的依赖许可清单，可在应用内的开源许可页面查看。