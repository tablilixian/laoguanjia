class AppConstants {
  // App Info
  static const String appName = '家庭管理器';
  static const String appVersion = '1.0.0';

  // Supabase - 请替换为你的实际配置
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Database Tables
  static const String tableHouseholds = 'households';
  static const String tableMembers = 'members';
  static const String tableTasks = 'tasks';
  static const String tableShoppingLists = 'shopping_lists';
  static const String tableShoppingItems = 'shopping_items';
  static const String tableEvents = 'events';
  static const String tableBills = 'bills';
  static const String tableAssets = 'assets';

  // Task Status
  static const String taskStatusPending = 'pending';
  static const String taskStatusCompleted = 'completed';

  // Task Recurrence
  static const String recurrenceNone = 'none';
  static const String recurrenceDaily = 'daily';
  static const String recurrenceWeekly = 'weekly';
  static const String recurrenceMonthly = 'monthly';

  // Member Role
  static const String roleAdmin = 'admin';
  static const String roleMember = 'member';

  // Bill Category
  static const List<String> billCategories = [
    '水电',
    '燃气',
    '网络',
    '房租',
    '物业',
    '保险',
    '其他',
  ];

  // Asset Category
  static const List<String> assetCategories = [
    '家电',
    '家具',
    '电子产品',
    '交通工具',
    '其他',
  ];
}
