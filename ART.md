# 美术资产来源

## 跨时空守望

机房、雪夜永昌堡及守军均由 Godot 代码绘制。机房画面使用二维多边形构建走廊、设备架和操作台，显示器扫描线实时移动。监控画面使用同一张程序绘制的雪堡底图，在其上绘制现代机柜或守军。剪枝移除机柜后，镜头和古堡布局保持一致。

- [机房绘制](SpacetimeSentinel/room_art.gd)
- [监控场景绘制](SpacetimeSentinel/camera_art.gd)
- [监控干扰与剪枝溶解效果](SpacetimeSentinel/camera.gdshader)

## 长夜守望者 · 实时三维战场

大陆行图以策划包的大地图为编辑对象，用内置图像生成工具重绘。当前贴图为 1451 × 1084，保留海岸线、区域位置和路线坐标。重绘提示要求用钢笔轮廓、少量排线和大片水粉色块，固定四区、城墙、巨骸和盘根古堡的位置，并去掉图中的文字与路线叠层。放大时 Godot 改用双三次采样保留细线，图内的路线和地区名随行图一起缩放和拖动。 [大陆行图](NightWatcher/assets/maps/00_world_overview_ink.png) · [行图材质](NightWatcher/scripts/campaign/atlas_ink.gdshader)

四张区域插画记录构图和地标。战场几何分别在 [scripts/model](NightWatcher/scripts/model) 内构建，包含巨骸与锈剑、砂岩断崖与巨肋、枯树环堡与吊桥、黑曜长墙与裂隙晶簇。

陨王巨骨的头骨、胸廓和手臂分别用 Tripo Studio 生成，在 Blender 调整姿态和尺寸后以 GLB 导入。胸廓和手臂先合并接缝处重合的顶点，再减面，保留完整的肋骨弧线和指缝。底色贴图与战场的哑光色洗、实时描边叠加。王冠沿头骨实测截面重新贴合，骨弩固定在左眼凹腔，箭矢从弩机上的挂点射出。Godot 以装配后的网格三角面生成碰撞，保留骨面之间的通路。 [装配](NightWatcher/scripts/model/FallenKing.gd) · [头骨 GLB](NightWatcher/assets/props/fallen_king/valley_tripo_cranium.glb) · [胸廓 GLB](NightWatcher/assets/props/fallen_king/valley_tripo_ribs.glb) · [手臂 GLB](NightWatcher/assets/props/fallen_king/valley_tripo_arm.glb)

黑曜长墙由连续的斜面石墙、扶壁、墙顶步道和断垛组成，石缝跟着墙面画。两道拱门都能让巡夜人穿过，身形更高的敌人会被门楣挡住。半埋裂颅的霜层、凹陷眼窝和破损金属箍沿颅骨形体绘制，眼窝保留骨弩安装点。 [长墙模型](NightWatcher/scripts/model/Obsidian.gd) · [裂颅模型](NightWatcher/scripts/model/ObsidianRelic.gd)

蚀沙古台的砂岩沿不规则层理逐层削出岩檐。遗迹双拱、半截墙和石阶共用依崖的台基，东侧用独立的断肋和椎骨表现半埋的遗骸。浅沙色块和火光铺在实际地表，近处的岩檐遮住后方地面。 [蚀沙古台模型](NightWatcher/scripts/model/Sandstone.gd)

枯木环堡的盘根沿着残墙生长，三维水面和缓坡石岸沿堡墙相接。水面上的色洗缓慢漂移，岸边用断续浅线画出水纹。水面沿场景的水域边界绘制，两座吊桥的通行由真实位置和机关状态决定。 [枯木环堡模型](NightWatcher/scripts/model/RootKeep.gd) · [水面材质](NightWatcher/scripts/model/root_keep_water.gdshader)

战场材质用大片色洗和少量铅笔排线交代结构。三维深度生成的轮廓每秒换七次笔迹，模拟手绘线条轻微游移、偶尔断开的效果。远处的低雾随场景的真实深度和高度变化，石墙、树干和前景地面彼此遮挡。 [战场材质](NightWatcher/scripts/model/battle_model.gdshader) · [实时描边](NightWatcher/scripts/model/relief_ink.gdshader)

篝火、提灯和火龛给实时三维模型打光，灯光规则沿地形网格检测遮挡。陨王遗谷的地面暖光、树根和石沿亮边随篝火火势淡出。护具、武器和敌人关节由代码构建，支持奔跑、起手、挥击和受击。夜行爬尸会先压低重心蓄力，前脚踩下时挥爪，再从前倾姿势收回。 [光照规则](NightWatcher/scripts/battle/LightManager.gd) · [环境工事](NightWatcher/scripts/model/RelicWorks.gd)

巡夜人提灯由原始文字描述在 Tripo Studio 生成，经 GLB 导入 Godot。道具包含 3,488 个三角面和一张底色贴图。它保留原始颜色贴图，使用战场共用的哑光色洗。手部挂点与提灯光源由 Godot 驱动。 [提灯模型](NightWatcher/assets/props/watch_lantern.glb)

制作时参考了 Cinderwatch 的角色运动节奏、光源层次和情境式 HUD。 [Cinderwatch](https://github.com/kevintngo/cinderwatch)

### 早期石堡描线样片

参考图用粗细变化的轮廓交代树枝、断墙和拱门的形体。石面和树皮上只画少量内线，暖光集中在篝火附近。

- [石堡模型](NightWatcher/world/fort.gd)沿用三维版的环墙、折梯、拱门、枯树和植被布局。
- [模型表面线条](NightWatcher/world/mesh_builder.gd)由少量手工安排的折线和弧线组成，贴合石面倒角、树皮曲面和拱券内缘。
- [外轮廓](NightWatcher/world/ink_outline.gdshader)由实时深度产生，保留模型之间的遮挡关系。近景剪影较重，远处描线较淡。
- [材质与光照](NightWatcher/world/ink_material.gdshader)负责层次简洁的青灰色块、篝火暖光和提灯反馈。篝火焰面放在三维场景中，可被前景物体遮挡。
