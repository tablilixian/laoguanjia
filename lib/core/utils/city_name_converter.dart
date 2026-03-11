class CityNameConverter {
  /// 常见城市名称映射
  static const Map<String, String> _cityMap = {
    // 直辖市
    '北京': 'Beijing',
    '上海': 'Shanghai',
    '天津': 'Tianjin',
    '重庆': 'Chongqing',
    
    // 省会城市
    '广州': 'Guangzhou',
    '深圳': 'Shenzhen',
    '杭州': 'Hangzhou',
    '成都': 'Chengdu',
    '武汉': 'Wuhan',
    '西安': 'Xian',
    '南京': 'Nanjing',
    '郑州': 'Zhengzhou',
    '长沙': 'Changsha',
    '沈阳': 'Shenyang',
    '青岛': 'Qingdao',
    '宁波': 'Ningbo',
    '东莞': 'Dongguan',
    '无锡': 'Wuxi',
    '福州': 'Fuzhou',
    '厦门': 'Xiamen',
    '哈尔滨': 'Harbin',
    '济南': 'Jinan',
    '大连': 'Dalian',
    '昆明': 'Kunming',
    '合肥': 'Hefei',
    '南宁': 'Nanning',
    '南昌': 'Nanchang',
    '贵阳': 'Guiyang',
    '太原': 'Taiyuan',
    '石家庄': 'Shijiazhuang',
    '乌鲁木齐': 'Urumqi',
    '兰州': 'Lanzhou',
    '西宁': 'Xining',
    '银川': 'Yinchuan',
    '拉萨': 'Lhasa',
    
    // 其他城市
    '苏州': 'Suzhou',
    '温州': 'Wenzhou',
    '泉州': 'Quanzhou',
    '佛山': 'Foshan',
    '南通': 'Nantong',
    '烟台': 'Yantai',
    '徐州': 'Xuzhou',
    '常州': 'Changzhou',
    '潍坊': 'Weifang',
    '绍兴': 'Shaoxing',
    '台州': 'Taizhou',
    '嘉兴': 'Jiaxing',
    '金华': 'Jinhua',
    '扬州': 'Yangzhou',
    '盐城': 'Yancheng',
    '惠州': 'Huizhou',
    '保定': 'Baoding',
    '镇江': 'Zhenjiang',
    '中山': 'Zhongshan',
    '湛江': 'Zhanjiang',
    '茂名': 'Maoming',
    '珠海': 'Zhuhai',
    '江门': 'Jiangmen',
    '汕头': 'Shantou',
    '秦皇岛': 'Qinhuangdao',
    '邯郸': 'Handan',
    '邢台': 'Xingtai',
    '张家口': 'Zhangjiakou',
    '承德': 'Chengde',
    '沧州': 'Cangzhou',
    '廊坊': 'Langfang',
    '衡水': 'Hengshui',
    '唐山': 'Tangshan',
    '大同': 'Datong',
    '阳泉': 'Yangquan',
    '长治': 'Changzhi',
    '晋城': 'Jincheng',
    '朔州': 'Shuozhou',
    '晋中': 'Jinzhong',
    '运城': 'Yuncheng',
    '忻州': 'Xinzhou',
    '临汾': 'Linfen',
    '吕梁': 'Luliang',
  };
  
  /// 获取城市的标准英文名
  static String getCityName(String city) {
    // 首先检查是否在映射表中
    if (_cityMap.containsKey(city)) {
      return _cityMap[city]!;
    }
    
    // 尝试移除后缀后再检查
    String cleanedCity = city
        .replaceAll('市', '')
        .replaceAll('省', '')
        .replaceAll('自治区', '')
        .replaceAll('自治州', '')
        .replaceAll('地区', '')
        .replaceAll('特别行政区', '');
    
    if (_cityMap.containsKey(cleanedCity)) {
      return _cityMap[cleanedCity]!;
    }
    
    // 如果没有找到，返回原城市名
    return city;
  }
  
  /// 检查是否为中文城市名
  static bool isChineseCity(String city) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(city);
  }
}