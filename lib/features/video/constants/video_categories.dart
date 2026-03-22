/// 视频分类
enum VideoCategory {
  all('全部', null),
  nature('自然', 'nature'),
  animals('动物', 'animals'),
  people('人物', 'people'),
  places('风景', 'places'),
  travel('旅行', 'travel'),
  food('美食', 'food'),
  sports('运动', 'sports'),
  music('音乐', 'music'),
  science('科技', 'science'),
  business('商务', 'business'),
  background('背景', 'backgrounds');

  const VideoCategory(this.label, this.apiValue);

  final String label; // 显示名称
  final String? apiValue; // API 参数值（null 表示全部）
}

/// Tab 类型
enum VideoTab {
  popular('热门', 'popular'),
  latest('最新', 'latest');

  const VideoTab(this.label, this.orderValue);

  final String label;
  final String? orderValue;
}
