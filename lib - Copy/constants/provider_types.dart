/// Provider ID constants and mappings for AGConnect Auth.
class AuthProviderName {
  static const int anonymous = 0;
  static const int hms = 1;
  static const int facebook = 2;
  static const int twitter = 3;
  static const int wechat = 4;
  static const int huaweiGame = 5;
  static const int qq = 6;
  static const int weibo = 7;
  static const int google = 8;
  static const int googleGame = 9;
  static const int selfBuild = 10;
  static const int phone = 11;
  static const int email = 12;
  static const int apple = 13;
  static const int alipay = 14;

  /// Returns a human-readable provider name from the ID.
  static String name(int providerId) {
    switch (providerId) {
      case anonymous:
        return 'Anonymous';
      case hms:
        return 'Huawei ID';
      case facebook:
        return 'Facebook';
      case twitter:
        return 'Twitter';
      case wechat:
        return 'WeChat';
      case huaweiGame:
        return 'Huawei Game';
      case qq:
        return 'QQ';
      case weibo:
        return 'Weibo';
      case google:
        return 'Google';
      case googleGame:
        return 'Google Play Games';
      case selfBuild:
        return 'Self-built Account';
      case phone:
        return 'Phone';
      case email:
        return 'Email';
      case apple:
        return 'Apple ID';
      case alipay:
        return 'Alipay';
      default:
        return 'Unknown Provider';
    }
  }
}
