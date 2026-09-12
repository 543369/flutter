# 照护类型配图

使用内置 imagegen 工具生成，成品保存于 `mobile/assets/images/`，各图缩放为 512 px JPEG 供移动端使用。喂食继续使用原有 `petcare_food_bowl.png`。

| 类型 | 文件 | 画面 |
| --- | --- | --- |
| 驱虫 | `care_deworming.jpg` | 滴剂与密封药片包装 |
| 疫苗 | `care_vaccine.jpg` | 疫苗瓶与带盖注射器 |
| 散步 | `care_walk.jpg` | 牵引绳与项圈 |
| 洗护 | `care_grooming.jpg` | 宠物梳与毛巾 |
| 自定义 | `care_custom.jpg` | 笔记本与铅笔 |

统一生成提示词：

> Use case: product-mockup. Asset type: a single square illustration for a warm premium pet-care mobile app. Style: photorealistic miniature studio product photography, matte cream ceramics, warm caramel and muted sky blue accents, soft shadows, seamless solid warm off-white #fffdf9 background. Center the objects, entire subject fits inside central 70% with generous margins. Front three-quarter view, no frame, no text, no letters, no brands, no watermark.

每次调用附加的主体提示词：

- Deworming: A small cream veterinary pet spot-on treatment pipette with a simple brown paw emblem, next to one small sealed silver blister pack. This represents pet deworming.
- Vaccine: A small vaccine glass vial with a blank pale-blue label featuring a tiny paw emblem, next to a capped veterinary syringe. No exposed needle. This represents pet vaccination.
- Walk: A neatly coiled caramel fabric dog leash with a polished metal clip, next to a soft cream collar. This represents walking a pet.
- Grooming: A cream pet grooming brush with wooden handle and a folded soft sky-blue towel. This represents pet grooming.
- Custom: A small open cream notebook with blank pages and one simple paw mark on the cover, alongside a caramel pencil. This represents a custom pet-care task.
