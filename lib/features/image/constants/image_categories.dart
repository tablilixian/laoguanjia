/// 图片分类
enum ImageCategory {
  all('全部', null),
  backgrounds('背景', 'backgrounds'),
  fashion('时尚', 'fashion'),
  nature('自然', 'nature'),
  science('科学', 'science'),
  education('教育', 'education'),
  feelings('情感', 'feelings'),
  health('健康', 'health'),
  people('人物', 'people'),
  religion('宗教', 'religion'),
  places('风景', 'places'),
  animals('动物', 'animals'),
  industry('工业', 'industry'),
  computer('电脑', 'computer'),
  food('美食', 'food'),
  sports('运动', 'sports'),
  transportation('交通', 'transportation'),
  travel('旅行', 'travel'),
  buildings('建筑', 'buildings'),
  business('商务', 'business'),
  music('音乐', 'music');

  const ImageCategory(this.label, this.apiValue);

  final String label;
  final String? apiValue;
}

/// Tab 类型
enum ImageTab {
  popular('热门', 'popular'),
  latest('最新', 'latest');

  const ImageTab(this.label, this.orderValue);

  final String label;
  final String? orderValue;
}
