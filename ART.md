# 美术资产来源

## 跨时空守望

机房、雪夜永昌堡及守军均由 Godot 代码绘制。机房画面使用二维多边形构建走廊、设备架和操作台，显示器扫描线实时移动。监控画面使用同一张程序绘制的雪堡底图，在其上绘制现代机柜或守军。剪枝移除机柜后，镜头和古堡布局保持一致。

- [机房绘制](SpacetimeSentinel/room_art.gd)
- [监控场景绘制](SpacetimeSentinel/camera_art.gd)
- [监控干扰与剪枝溶解效果](SpacetimeSentinel/camera.gdshader)

## 长夜守望者 · 实时三维战场

大陆行图以策划包的大地图为编辑对象，用内置图像生成工具重绘。当前贴图为 1451 × 1084，保留海岸线、区域位置和路线坐标。重绘提示要求用钢笔轮廓、少量排线和大片水粉色块，固定四区、城墙、巨骸和盘根古堡的位置，并去掉图中的文字与路线叠层。图内的路线和地区名由 Godot 绘制，随行图一起缩放和拖动。 [大陆行图](NightWatcher/assets/maps/00_world_overview_ink.png)

四张区域插画记录构图和地标，保存在工程作为美术参考。战场几何分别在 [scripts/model](NightWatcher/scripts/model) 内构建，包含巨骸与锈剑、砂岩断崖与巨肋、枯树环堡与吊桥、黑曜长墙与裂隙晶簇。陨王头骨、胸廓和手臂是独立三维部件，碰撞基于各部件和地形的实际网格。

[战场着色器](NightWatcher/scripts/model/battle_model.gdshader) 给模型叠加色洗与铅笔纹理。深度描边随模型遮挡。篝火、提灯和火龛给实时三维模型打光，[LightManager](NightWatcher/scripts/battle/LightManager.gd) 沿着实际地形网格检测光线是否被挡住。陨王遗谷的地面暖光、树根和石沿亮边随篝火火势淡出。护具、武器和敌人关节由代码构建，配合奔跑、挥击、受击和短暂停顿。环境工事的实物模型在 [RelicWorks](NightWatcher/scripts/model/RelicWorks.gd) 中绘制。

巡夜人提灯由原始文字描述在 Tripo Studio 生成，经 GLB 导入 Godot。道具包含 3,488 个三角面和一张底色贴图。它保留原始颜色贴图，使用战场共用的哑光色洗。手部挂点与提灯光源由 Godot 驱动。 [提灯模型](NightWatcher/assets/props/watch_lantern.glb)

制作时参考了 Cinderwatch 的角色运动节奏、光源层次和情境式 HUD。 [Cinderwatch](https://github.com/kevintngo/cinderwatch)

### 早期石堡描线样片

参考图用粗细变化的轮廓交代树枝、断墙和拱门的形体。石面和树皮上只画少量内线，暖光集中在篝火附近。

- [石堡模型](NightWatcher/world/fort.gd)沿用三维版的环墙、折梯、拱门、枯树和植被布局。
- [模型表面线条](NightWatcher/world/mesh_builder.gd)由少量手工安排的折线和弧线组成，贴合石面倒角、树皮曲面和拱券内缘。
- [外轮廓](NightWatcher/world/ink_outline.gdshader)由实时深度产生，保留模型之间的遮挡关系。近景剪影较重，远处描线较淡。
- [材质与光照](NightWatcher/world/ink_material.gdshader)负责层次简洁的青灰色块、篝火暖光和提灯反馈。篝火焰面放在三维场景中，可被前景物体遮挡。
