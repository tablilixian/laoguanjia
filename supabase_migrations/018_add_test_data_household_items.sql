-- ============================================================
-- 测试数据 - Household Items 模块
-- 使用说明：在 Supabase SQL 编辑器中执行
-- 注意：需要将下面的 household_id 替换为实际的家庭 ID
-- ============================================================

-- 先查询 households 表获取 household_id
-- SELECT id, name FROM households;

-- ============================================================
-- 1. 插入位置数据（层级结构）
-- ============================================================

-- 客厅
INSERT INTO item_locations (household_id, name, description, icon, color, depth, path, sort_order) VALUES
('your-household-id-uuid', '客厅', '家庭活动中心', '🛋️', '#795548', 0, 'living-room', 1),
-- 客厅的子位置
('your-household-id-uuid', '电视柜', '客厅电视柜', '📺', '#2196F3', 1, 'living-room.tv-cabinet', 1),
('your-household-id-uuid', '沙发', '客厅沙发', '🛋️', '#FF9800', 1, 'living-room.sofa', 2),

-- 厨房
('your-household-id-uuid', '厨房', '烹饪区域', '🍳', '#FF5722', 0, 'kitchen', 2),
-- 厨房的子位置
('your-household-id-uuid', '橱柜', '厨房橱柜', '🚪', '#9C27B0', 1, 'kitchen.cabinet', 1),
('your-household-id-uuid', '冰箱', '冷藏食物', '🧊', '#00BCD4', 1, 'kitchen.fridge', 2),

-- 主卧
('your-household-id-uuid', '主卧', '主卧室', '🛏️', '#E91E63', 0, 'master-bedroom', 3),
-- 主卧的子位置
('your-household-id-uuid', '衣柜', '主卧衣柜', '🚪', '#3F51B5', 1, 'master-bedroom.closet', 1),
('your-household-id-uuid', '床头柜', '床头柜', '🗄️', '#795548', 1, 'master-bedroom.nightstand', 2),

-- 次卧
('your-household-id-uuid', '次卧', '客房/儿童房', '🛏️', '#4CAF50', 0, 'guest-bedroom', 4),

-- 浴室
('your-household-id-uuid', '浴室', '卫生间', '🚿', '#00BCD4', 0, 'bathroom', 5),

-- 书房
('your-household-id-uuid', '书房', '工作学习区域', '📚', '#3F51B5', 0, 'study-room', 6);

-- ============================================================
-- 2. 插入标签数据
-- ============================================================

INSERT INTO item_tags (household_id, name, color, category) VALUES
-- 季节类
('your-household-id-uuid', '春装', '#4CAF50', 'season'),
('your-household-id-uuid', '夏装', '#FF9800', 'season'),
('your-household-id-uuid', '秋装', '#795548', 'season'),
('your-household-id-uuid', '冬装', '#2196F3', 'season'),
-- 颜色类
('your-household-id-uuid', '深色', '#424242', 'color'),
('your-household-id-uuid', '浅色', '#9E9E9E', 'color'),
('your-household-id-uuid', '彩色', '#E91E63', 'color'),
-- 状态类
('your-household-id-uuid', '需要维修', '#F44336', 'status'),
('your-household-id-uuid', '新品', '#4CAF50', 'status'),
('your-household-id-uuid', '待处理', '#FF9800', 'status'),
('your-household-id-uuid', '待丢弃', '#795548', 'status'),
('your-household-id-uuid', '已借出', '#9C27B0', 'status');

-- ============================================================
-- 3. 插入物品数据
-- ============================================================

-- 家电类
INSERT INTO household_items (household_id, name, description, item_type, location_id, quantity, brand, model, condition, purchase_price, notes) VALUES
('your-household-id-uuid', 'TCL 电视', '55寸智能电视', 'appliance', (SELECT id FROM item_locations WHERE path = 'living-room.tv-cabinet'), 1, 'TCL', '55P12', 'good', 2999.00, '2024年双11购买'),
('your-household-id-uuid', '美的空调', '客厅立式空调', 'appliance', (SELECT id FROM item_locations WHERE path = 'living-room'), 1, '美的', 'KFR-72LW', 'good', 4500.00, '制热效果不错'),
('your-household-id-uuid', '西门子冰箱', '对开门冰箱', 'appliance', (SELECT id FROM item_locations WHERE path = 'kitchen.fridge'), 1, '西门子', 'BCD-608W', 'good', 8000.00, '容积很大'),
('your-household-id-uuid', '小米扫地机器人', '智能扫拖一体', 'appliance', (SELECT id FROM item_locations WHERE path = 'living-room'), 1, '小米', 'M30S', 'new', 3500.00, '刚买不久'),

-- 家具类
('your-household-id-uuid', '真皮沙发', 'L型真皮沙发', 'furniture', (SELECT id FROM item_locations WHERE path = 'living-room.sofa'), 1, '顾家', 'L型', 'good', 12000.00, '很舒服'),
('your-household-id-uuid', '实木书桌', '橡木书桌', 'furniture', (SELECT id FROM item_locations WHERE path = 'study-room'), 1, '宜家', 'BEKANT', 'good', 2000.00, '简约风格'),
('your-household-id-uuid', '双人床', '1.8米双人床', 'furniture', (SELECT id FROM item_locations WHERE path = 'master-bedroom'), 1, '慕思', '经典款', 'good', 6000.00, '睡感很好'),

-- 衣物类
('your-household-id-uuid', '羽绒服', '黑色中长款', 'clothing', (SELECT id FROM item_locations WHERE path = 'master-bedroom.closet'), 2, '波司登', '经典', 'good', 1500.00, '冬天穿'),
('your-household-id-uuid', 'T恤', '纯棉白T恤', 'clothing', (SELECT id FROM item_locations WHERE path = 'master-bedroom.closet'), 5, '优衣库', 'UT', 'good', 99.00, '夏装'),
('your-household-id-uuid', '牛仔裤', '蓝色直筒裤', 'clothing', (SELECT id FROM item_locations WHERE path = 'master-bedroom.closet'), 3, 'Levi''s', '501', 'good', 800.00, NULL),

-- 餐具类
('your-household-id-uuid', '骨瓷餐具套装', '36件套', 'tableware', (SELECT id FROM item_locations WHERE path = 'kitchen.cabinet'), 1, '康宁', 'VS-36', 'good', 1200.00, '结婚时买的'),
('your-household-id-uuid', '不锈钢炒锅', '32cm炒锅', 'tableware', (SELECT id FROM item_locations WHERE path = 'kitchen.cabinet'), 1, '苏泊尔', 'TP1601E', 'good', 300.00, NULL),

-- 工具类
('your-household-id-uuid', '电钻', '充电式电钻', 'tool', (SELECT id FROM item_locations WHERE path = 'kitchen'), 1, '博世', 'GSR12V-30', 'good', 800.00, '家用足够'),
('your-household-id-uuid', '工具箱', '基础工具套装', 'tool', (SELECT id FROM item_locations WHERE path = 'kitchen.cabinet'), 1, '史丹利', 'STMT71652', 'good', 500.00, NULL),

-- 书籍类
('your-household-id-uuid', '三体', '科幻小说', 'book', (SELECT id FROM item_locations WHERE path = 'study-room'), 1, '重庆出版社', '典藏版', 'good', 68.00, '已看完'),
('your-household-id-uuid', '人类简史', '历史科普', 'book', (SELECT id FROM item_locations WHERE path = 'study-room'), 1, '中信出版社', '精装版', 'good', 68.00, '值得反复阅读'),
('your-household-id-uuid', '金字塔原理', '商务写作', 'book', (SELECT id FROM item_locations WHERE path = 'study-room'), 1, '民主与建设出版社', '新版', 'fair', 59.00, '工作参考'),

-- 日用品类
('your-household-id-uuid', '戴森吸尘器', 'V15吸尘器', 'daily', (SELECT id FROM item_locations WHERE path = 'living-room'), 1, '戴森', 'V15 Detect', 'good', 5000.00, '清洁神器'),
('your-household-id-uuid', '小米空气净化器', '卧室用', 'daily', (SELECT id FROM item_locations WHERE path = 'master-bedroom'), 1, '小米', '4 Pro', 'good', 1500.00, '除甲醛'),

-- 运动器材类
('your-household-id-uuid', '跑步机', '家用折叠跑步机', 'sports', (SELECT id FROM item_locations WHERE path = 'living-room'), 1, '舒华', 'SH-T9119A', 'good', 4000.00, '疫情买的'),
('your-household-id-uuid', '瑜伽垫', '加厚隔音垫', 'sports', (SELECT id FROM item_locations WHERE path = 'living-room'), 1, 'Keep', 'NBR材质', 'good', 200.00, NULL),

-- 装饰品类
('your-household-id-uuid', '落地灯', '北欧风格', 'decoration', (SELECT id FROM item_locations WHERE path = 'living-room.sofa'), 1, 'IKEA', '勒纳普', 'good', 499.00, '氛围灯'),
('your-household-id-uuid', '绿植', '龟背竹', 'decoration', (SELECT id FROM item_locations WHERE path = 'living-room'), 3, NULL, NULL, 'good', 150.00, '好养'),

-- 玩具类
('your-household-id-uuid', 'Switch', 'OLED版', 'toy', (SELECT id FROM item_locations WHERE path = 'living-room.tv-cabinet'), 1, '任天堂', 'OLED', 'good', 2500.00, '游戏机'),
('your-household-id-uuid', '乐高积木', '城市系列', 'toy', (SELECT id FROM item_locations WHERE path = 'master-bedroom.nightstand'), 1, 'LEGO', '10297', 'good', 600.00, '宇航员'),

-- 药品类
('your-household-id-uuid', '创可贴', '防水型', 'medicine', (SELECT id FROM item_locations WHERE path = 'bathroom'), 10, '云南白药', '防水型', 'good', 5.00, NULL),
('your-household-id-uuid', '维生素C', '补充维C', 'medicine', (SELECT id FROM item_locations WHERE path = 'bathroom'), 2, '汤臣倍健', '咀嚼片', 'good', 120.00, NULL);

-- ============================================================
-- 4. 插入物品标签关联
-- ============================================================

-- 为部分衣物添加季节和颜色标签
INSERT INTO item_tag_relations (item_id, tag_id)
SELECT 
    (SELECT id FROM household_items WHERE name = '羽绒服'),
    (SELECT id FROM item_tags WHERE name = '冬装')
WHERE EXISTS (SELECT 1 FROM household_items WHERE name = '羽绒服');

INSERT INTO item_tag_relations (item_id, tag_id)
SELECT 
    (SELECT id FROM household_items WHERE name = '羽绒服'),
    (SELECT id FROM item_tags WHERE name = '深色')
WHERE EXISTS (SELECT 1 FROM household_items WHERE name = '羽绒服');

INSERT INTO item_tag_relations (item_id, tag_id)
SELECT 
    (SELECT id FROM household_items WHERE name = 'T恤'),
    (SELECT id FROM item_tags WHERE name = '夏装')
WHERE EXISTS (SELECT 1 FROM household_items WHERE name = 'T恤');

-- 为跑步机添加待丢弃标签（示例）
INSERT INTO item_tag_relations (item_id, tag_id)
SELECT 
    (SELECT id FROM household_items WHERE name = '跑步机'),
    (SELECT id FROM item_tags WHERE name = '待处理')
WHERE EXISTS (SELECT 1 FROM household_items WHERE name = '跑步机');

-- ============================================================
-- 验证数据插入成功
-- ============================================================
-- SELECT '位置数量:', COUNT(*) FROM item_locations WHERE household_id = 'your-household-id-uuid';
-- SELECT '标签数量:', COUNT(*) FROM item_tags WHERE household_id = 'your-household-id-uuid';
-- SELECT '物品数量:', COUNT(*) FROM household_items WHERE household_id = 'your-household-id-uuid';
