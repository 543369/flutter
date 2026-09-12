# 爪伴 PetCare Figma 设计交接

## 设计方向

界面采用温暖、安静、可信赖的家庭陪伴感。宠物照片承担情绪表达，照护任务保持清晰、直接，避免医疗工具式的冷硬视觉。

## 建议画板

- iPhone 15：393 × 852
- 首页照护：顶部宠物主视觉、筛选、下一项照护、任务列表、底部导航
- 宠物：宠物概览、宠物卡片、添加宠物
- 家庭：家庭概览、成员、邀请与账号安全
- 登录：欢迎区、登录表单、设备模式入口

## 颜色变量

| Figma 变量 | 色值 | 用途 |
| --- | --- | --- |
| `brand/brown` | `#5B3B2E` | 主按钮、选中态 |
| `brand/orange` | `#D95E32` | 提醒、重点图标 |
| `text/primary` | `#33241F` | 标题与正文重点 |
| `text/secondary` | `#6F625C` | 说明文字 |
| `surface/base` | `#FFFDF9` | 页面背景 |
| `surface/warm` | `#FFF6E9` | 暖色卡片 |
| `surface/blue` | `#E7F1F8` | 家庭与记录卡片 |
| `border/subtle` | `#EADFD5` | 输入框和卡片描边 |

## 字体与间距

- 字体：iOS 使用 SF Pro Display，并由系统字体回退显示中文；Android 使用系统无衬线字体。
- 大标题：34 / 38，粗体。
- 页面标题：27 / 32，粗体。
- 卡片标题：20 / 26，粗体。
- 正文：16 / 23；辅助文字：14 / 20。
- 基础间距单位：4；常用间距为 8、12、16、18、24、32。
- 页面左右边距：18；卡片圆角：22；主视觉圆角：30；按钮圆角：18。

## 组件

- `Pet Hero`：宠物照片、日期、问候语、宠物切换、待照护数量、提醒与语言入口。
- `Care Filter`：待照护、已完成、记录、重复计划四种状态。
- `Next Care Card`：时间、任务、重复状态、食盆图片、完成按钮。
- `Task Tile`：完成状态、时间、宠物、逾期状态与详情入口。
- `Pet Card`：宠物头像、物种、基础信息和管理入口。
- `Family Card`：家庭成员、角色与邀请入口。
- `Bottom Navigation`：照护、宠物、家庭三个目的地。

## Figma 连接步骤

1. 在 Codex 中安装并授权 Figma 连接器。
2. 指定一个已有 Figma 文件，或要求新建 `爪伴 PetCare Mobile` 文件。
3. 用本文件中的变量建立 Figma Variables，并创建 393 × 852 的页面画板。
4. 将 Flutter 页面截图和组件拆分同步到对应画板；组件命名与上方组件名称保持一致。
5. 在 Figma Dev Mode 中把变量名映射到 `mobile/lib/app/petcare_app.dart` 的主题值。

## 代码映射

- 全局主题：`mobile/lib/app/petcare_app.dart`
- 页面容器与底部导航：`mobile/lib/app/home_shell.dart`
- 首页照护：`mobile/lib/features/care/care_view.dart`
- 宠物页：`mobile/lib/features/pets/pet_module.dart`
- 家庭页：`mobile/lib/features/family/family_module.dart`
- 图片资源：`mobile/assets/images/`
