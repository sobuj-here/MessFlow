import 'package:flutter/material.dart';

class LanguageService {
  static final ValueNotifier<String> languageNotifier = ValueNotifier<String>('en');

  static bool get isBangla => languageNotifier.value == 'bn';

  static Future<void> init() async {
    
    languageNotifier.value = 'en';
  }

  static void changeLanguage(String langCode) {
    languageNotifier.value = langCode;
  }

  static String tr(String key) {
    final lang = languageNotifier.value;
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'MessFlow',
      'invite_code': 'Invite Code',
      'tap_to_copy': 'Tap to Copy',
      'copied': 'copied to clipboard!',
      'daily_operations': 'Daily Operations',
      'bazaar': 'Bazaar Expenses',
      'bazaar_sub': 'Daily shopping list',
      'meals': 'Daily Meals',
      'meals_sub': 'Daily meal entries',
      'payments': 'Payments & Funds',
      'payments_sub': 'Send deposits & rent',
      'live_sheet': 'Live Mess Sheet',
      'live_sheet_sub': 'Balances and dues',
      'extra_costs': 'Extra Shared Costs',
      'extra_costs_sub': 'Cook bill, paper bill, etc.',
      'history': 'Past Months History',
      'history_sub': 'Archived month records',
      'assign_manager': 'Assign Manager',
      'room_rent': 'Room Rent',
      'settings_title': 'Settings & Profile',
      'edit_profile': 'Edit Profile',
      'your_name': 'Your Name',
      'photo_url': 'Photo URL',
      'cancel': 'Cancel',
      'save_changes': 'Save Changes',
      'members_dir': 'Mess Members Directory',
      'role': 'Role',
      'admin_only': 'Admin Only',
      'view_members_phone': 'View Members Contact List',
      'preferences': 'PREFERENCES',
      'dark_mode': 'Dark Mode',
      'dark_mode_sub': 'Switch to Dark Theme',
      'light_mode_sub': 'Switch to Light Theme',
      'language': 'Language',
      'account': 'ACCOUNT',
      'logout': 'Logout',
      'logout_confirm_title': 'Confirm Sign Out',
      'logout_confirm_msg': 'Are you sure you want to sign out from MessFlow?',
      'live_meal_rate': 'Live Meal Rate',
      'total_bazaar': 'Total Bazaar',
      'total_meals': 'Total Meals',
      'cash_in_hand': 'Cash in Hand',
      'individual_balances': 'Individual Member Balances',
      'auto_meal_chart': 'Auto Meal Chart',
    },
    'bn': {
      'app_title': 'মেসফ্লো',
      'invite_code': 'ইনভাইট কোড',
      'tap_to_copy': 'কপি করতে চাপুন',
      'copied': 'ক্লিপবোর্ডে কপি করা হয়েছে!',
      'daily_operations': 'দৈনিক কার্যক্রম',
      'bazaar': 'বাজার খরচ',
      'bazaar_sub': 'প্রতিদিনের বাজার তালিকা',
      'meals': 'দৈনিক মিল',
      'meals_sub': 'প্রতিদিনের খাবারের এন্ট্রি',
      'payments': 'পেমেন্ট ও জমা ফান্ড',
      'payments_sub': 'মেসের জমা ও ভাড়া প্রদান',
      'live_sheet': 'লাইভ মেস শিট',
      'live_sheet_sub': 'কার কত জমা ও বাকি',
      'extra_costs': 'অতিরিক্ত খরচ সমূহ',
      'extra_costs_sub': 'খালা বিল, ওয়াইফাই, ইত্যাদি',
      'history': 'পুরোনো মাসের হিস্ট্রি',
      'history_sub': 'সংরক্ষিত পূর্বের হিসাব',
      'assign_manager': 'ম্যানেজার নিয়োগ',
      'room_rent': 'রুম ও সিট ভাড়া',
      'settings_title': 'সেটিংস ও প্রোফাইল',
      'edit_profile': 'প্রোফাইল পরিবর্তন',
      'your_name': 'আপনার নাম',
      'photo_url': 'ছবির লিঙ্ক (URL)',
      'cancel': 'বাতিল',
      'save_changes': 'সংরক্ষণ করুন',
      'members_dir': 'মেসের সদস্যদের তালিকা',
      'role': 'দায়িত্ব',
      'admin_only': 'শুধু অ্যাডমিন',
      'view_members_phone': 'সদস্যদের ফোন নম্বর দেখুন',
      'preferences': 'পছন্দসমূহ (PREFERENCES)',
      'dark_mode': 'ডার্ক মোড',
      'dark_mode_sub': 'ডার্ক থিম চালু করুন',
      'light_mode_sub': 'লাইট থিম চালু করুন',
      'language': 'ভাষা পরিবর্তন (Language)',
      'account': 'অ্যাকাউন্ট',
      'logout': 'লগআউট',
      'logout_confirm_title': 'লগআউট নিশ্চিতকরণ',
      'logout_confirm_msg': 'আপনি কি সত্যি মেসফ্লো থেকে বের হতে চান?',
      'live_meal_rate': 'বর্তমান মিল রেট',
      'total_bazaar': 'মোট বাজার',
      'total_meals': 'মোট মিল',
      'cash_in_hand': 'অবশিষ্ট ফান্ড',
      'individual_balances': 'সদস্যদের ব্যক্তিগত ব্যালেন্স',
      'auto_meal_chart': 'দৈনিক অটো মিল চার্ট',
    },
  };
}