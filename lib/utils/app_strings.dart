import '../controllers/app_settings_controller.dart';

class AppStrings {
  static bool get isBangla => AppSettingsController.instance.language == 'bn';

  static String tr({required String en, required String bn}) {
    return isBangla ? bn : en;
  }

  
  static String get appName => tr(en: 'MessFlow', bn: 'মেসফ্লো');
  static String get appSubtitle => tr(en: 'Smart Mess & Meal Management', bn: 'স্মার্ট মেস ও মিল ব্যবস্থাপনা');
  static String get cancel => tr(en: 'Cancel', bn: 'বাতিল');
  static String get save => tr(en: 'Save', bn: 'সংরক্ষণ');
  static String get submit => tr(en: 'Submit', bn: 'জমা দিন');
  static String get comingSoon => tr(en: 'Feature coming soon', bn: 'ফিচারটি শীঘ্রই আসছে');

  
  static String get roleAdmin => tr(en: 'Mess Admin', bn: 'মেস অ্যাডমিন');
  static String get roleManager => tr(en: 'Month Manager', bn: 'চলতি ম্যানেজার');
  static String get roleMember => tr(en: 'Mess Member', bn: 'মেস সদস্য');

  
  static String get liveMealRate => tr(en: 'Live Meal Rate', bn: 'বর্তমান মিল রেট');
  static String get totalMeals => tr(en: 'Total Meals', bn: 'মোট মিল');
  static String get totalBazaar => tr(en: 'Total Bazaar', bn: 'মোট বাজার');
  static String get adminPanel => tr(en: 'Admin Management', bn: 'অ্যাডমিন ব্যবস্থাপনা');
  static String get assignManager => tr(en: 'Assign Manager', bn: 'ম্যানেজার নিয়োগ');
  static String get roomRentSheet => tr(en: 'Room Rent Sheet', bn: 'রুম ভাড়া শিট');
  static String get dailyOperations => tr(en: 'Daily Operations', bn: 'দৈনন্দিন মেস হিসাব');
  static String get notInMess => tr(en: 'You are not joined in any mess yet', bn: 'আপনি এখনো কোনো মেসে যুক্ত হননি');
  static String get notInMessSubtitle => tr(en: 'Ask your mess admin for an invite', bn: 'মেসে যুক্ত হতে মেস অ্যাডমিনের সাহায্য নিন');

  
  static String get bazaarTitle => tr(en: 'Bazaar Records', bn: 'বাজারের খরচ');
  static String get bazaarSubtitle => tr(en: 'Daily shopping and expenses', bn: 'দৈনিক বাজারের হিসাব');
  static String get mealTitle => tr(en: 'Daily Meals', bn: 'ডেইলি মিল');
  static String get mealSubtitle => tr(en: 'Track breakfast, lunch, and dinner', bn: 'সকাল, দুপুর ও রাতের মিল হিসাব');
  static String get paymentTitle => tr(en: 'Payments & Funds', bn: 'টাকা জমা ও পেমেন্ট');
  static String get paymentSubtitle => tr(en: 'Send deposit to manager or admin', bn: 'ম্যানেজার বা অ্যাডমিনকে টাকা পাঠান');
  static String get sheetTitle => tr(en: 'Live Mess Sheet', bn: 'লাইভ মেস শিট');
  static String get sheetSubtitle => tr(en: 'Current balances and dues', bn: 'চলতি মাসের আয়-ব্যয় ও বাকি');
  static String get extraCostTitle => tr(en: 'Extra Shared Costs', bn: 'অতিরিক্ত খরচ');
  static String get extraCostSubtitle => tr(en: 'Cook bill, paper bill, etc.', bn: 'খালা বিল, পেপার বিল ও অন্যান্য');
  static String get chatTitle => tr(en: 'Notice & Group Chat', bn: 'নোটিশ ও গ্রুপ চ্যাট');
  static String get chatSubtitle => tr(en: 'Group messaging for members', bn: 'সদস্যদের আলোচনা ও ঘোষণা');
  static String get archiveTitle => tr(en: 'Past Months Archive', bn: 'আগের মাসের ইতিহাস');
  static String get archiveSubtitle => tr(en: 'Archived records of previous months', bn: 'বিগত মাসগুলোর চূড়ান্ত হিসাব');
}