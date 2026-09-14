# 宠物回忆录与家庭页

2026-09-14 实现记录。

## 使用入口

宠物页使用照片卡片，点击卡片进入档案，再点击「它的回忆录」。每篇回忆包含标题、故事、发生日期和最多 6 张照片；可以查看详情、放大图片、编辑和删除。服务端自动记录创建时间，编辑不改变创建时间。

宠物卡片优先显示该宠物上传的照片；没有照片或照片无法读取时，猫、狗分别使用默认摄影封面，其他宠物使用宠物图标。默认图仅是界面素材，不会写入宠物档案或自动添加到回忆录。

## 宠物照片轮播（最多 5 张）

宠物档案支持添加、移除最多 5 张照片，并通过「设为封面」将照片移到首位。首页和档案详情可左右滑动或点击圆点查看当前宠物的照片；名字下拉菜单用于切换宠物。轮播保持手动切换，避免阅读照护信息时背景自行变化。单张或无图时不显示分页圆点。

`POST /api/pets` 和 `PATCH /api/pets/{petId}` 接受有序 `photos` Base64 数组，最多 5 项、每项最多 1,500,000 字符；第一项同步为兼容字段 `photoData`。`GET /api/dashboard` 返回 `photos` 和封面，卡片与头像只使用封面。显式提交 `photos: []` 清空照片。

数据库迁移 `V9__pet_photo_gallery.sql` 将原有单图迁移为首张照片。旧客户端未提交 `photos` 时，文字更新保留相册；若提交非空 `photoData`，只替换首图并保留后续照片。旧客户端的空 `photoData` 不会清空已有相册，清空应使用新接口的 `photos: []`。服务端验证照片上限和 Base64，更新失败回滚整个档案变更。

新增验证：`mobile/test/pet_gallery_test.dart` 与 `scripts/pet_gallery_smoke_test.py`；可用 `PETCARE_QA_GALLERY=1` 运行已有截图脚本查看 5 张照片状态。此限制针对宠物档案照片，回忆录每篇仍最多 6 张。

家庭页展示真实成员、宠物与回忆数量，提供邀请、加入家庭和最近照护动态。账号安全、提醒与隐私设置集中在下方。

## 接口

所有路径都带 `/api` 前缀，并要求已登录的家庭成员身份。

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/pets/{petId}/memories?offset=0` | 每页 12 篇，按发生日期、创建时间倒序；返回 `items/total/hasMore` |
| POST | `/pets/{petId}/memories` | 创建回忆，返回 `201 {id}` |
| GET | `/pets/{petId}/memories/{memoryId}` | 故事全文、照片、作者和时间 |
| PATCH | `/pets/{petId}/memories/{memoryId}` | 保存完整编辑后的内容与照片列表 |
| DELETE | `/pets/{petId}/memories/{memoryId}` | 删除故事及图片，返回 204 |

POST/PATCH 请求字段：

```json
{
  "title": "第一次一起去海边",
  "story": "那天它追着海浪跑了很久。",
  "happenedOn": "2026-09-12",
  "photos": []
}
```

- 标题必填，最多 120 字；故事必填，最多 5000 字；发生日期不能晚于今天。
- `photos` 为 Base64 字符串数组，最多 6 张，每个字符串最多 1,500,000 字符。客户端沿用宠物照片选择与 JPEG 压缩流程。可以不附图。
- 列表只返回首图 `coverData` 与 `photoCount`，详情返回全部 `photos`。数据库 V8 增加故事与照片表；目前图片随 JSON 保存到 MySQL，没有接入外部图床。
- 所有家庭成员可以查看、编辑和删除家庭内的回忆。其他家庭和错误的宠物路径均返回 404。无效照片引发的失败会回滚整笔写入，包括编辑前的故事和照片。
- 删除宠物会级联删除其回忆和照片；成员离开后共享故事保留，最后一位成员删除账号时家庭数据随之删除。
- `/dashboard` 新增各宠物的 `memoryCount` 和家庭 `memberProfiles`（名称、ID、是否本人），不返回其他成员邮箱。

## 验证与截图

- `mobile/test/memory_test.dart`：创建 → 详情 → 编辑 → 删除；附加/移除图片；失败后保留输入并重试；两种屏宽下邀请入口。
- `scripts/memory_smoke_test.py`：实际 HTTP/MySQL 图片往返、验证回滚、分页、家庭共享和隔离、创建时间不变、删除级联。只创建临时测试家庭，结束后清理。
- `mobile/tool/memories_visual_qa_test.dart`：可选的中文 Flutter 渲染截图脚本，需通过 `PETCARE_QA_FONT` 指定本机 CJK 字体。
- [视觉检查与截图](../design-qa.md)。界面测试使用注入的照片选择器；系统文件选择器的手动操作不属于自动测试覆盖范围。

运行示例（先启动本地 API）：

```sh
API_BASE_URL=http://127.0.0.1:18080 python3 scripts/memory_smoke_test.py
cd mobile
flutter test test/memory_test.dart
PETCARE_QA_FONT=/path/to/PingFang.ttc flutter test tool/memories_visual_qa_test.dart
```
