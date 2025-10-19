class Currency {
  final String code;
  final String name;
  final String symbol;
  final String locale;

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.locale,
  });

  static const List<Currency> currencies = [
    Currency(code: 'USD', name: 'US Dollar', symbol: '\$', locale: 'en_US'),
    Currency(code: 'EUR', name: 'Euro', symbol: '€', locale: 'de_DE'),
    Currency(code: 'GBP', name: 'British Pound', symbol: '£', locale: 'en_GB'),
    Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥', locale: 'ja_JP'),
    Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', locale: 'zh_CN'),
    Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹', locale: 'en_IN'),
    Currency(
      code: 'AUD',
      name: 'Australian Dollar',
      symbol: 'A\$',
      locale: 'en_AU',
    ),
    Currency(
      code: 'CAD',
      name: 'Canadian Dollar',
      symbol: 'C\$',
      locale: 'en_CA',
    ),
    Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', locale: 'de_CH'),
    Currency(code: 'SEK', name: 'Swedish Krona', symbol: 'kr', locale: 'sv_SE'),
    Currency(
      code: 'NZD',
      name: 'New Zealand Dollar',
      symbol: 'NZ\$',
      locale: 'en_NZ',
    ),
    Currency(
      code: 'SGD',
      name: 'Singapore Dollar',
      symbol: 'S\$',
      locale: 'en_SG',
    ),
    Currency(
      code: 'HKD',
      name: 'Hong Kong Dollar',
      symbol: 'HK\$',
      locale: 'zh_HK',
    ),
    Currency(
      code: 'NOK',
      name: 'Norwegian Krone',
      symbol: 'kr',
      locale: 'nb_NO',
    ),
    Currency(
      code: 'KRW',
      name: 'South Korean Won',
      symbol: '₩',
      locale: 'ko_KR',
    ),
    Currency(code: 'TRY', name: 'Turkish Lira', symbol: '₺', locale: 'tr_TR'),
    Currency(code: 'RUB', name: 'Russian Ruble', symbol: '₽', locale: 'ru_RU'),
    Currency(
      code: 'BRL',
      name: 'Brazilian Real',
      symbol: 'R\$',
      locale: 'pt_BR',
    ),
    Currency(
      code: 'ZAR',
      name: 'South African Rand',
      symbol: 'R',
      locale: 'en_ZA',
    ),
    Currency(
      code: 'MXN',
      name: 'Mexican Peso',
      symbol: 'Mex\$',
      locale: 'es_MX',
    ),
    Currency(
      code: 'IDR',
      name: 'Indonesian Rupiah',
      symbol: 'Rp',
      locale: 'id_ID',
    ),
    Currency(
      code: 'MYR',
      name: 'Malaysian Ringgit',
      symbol: 'RM',
      locale: 'ms_MY',
    ),
    Currency(
      code: 'PHP',
      name: 'Philippine Peso',
      symbol: '₱',
      locale: 'en_PH',
    ),
    Currency(code: 'THB', name: 'Thai Baht', symbol: '฿', locale: 'th_TH'),
    Currency(
      code: 'VND',
      name: 'Vietnamese Dong',
      symbol: '₫',
      locale: 'vi_VN',
    ),
    Currency(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', locale: 'ar_AE'),
    Currency(code: 'SAR', name: 'Saudi Riyal', symbol: 'ر.س', locale: 'ar_SA'),
    Currency(
      code: 'EGP',
      name: 'Egyptian Pound',
      symbol: 'E£',
      locale: 'ar_EG',
    ),
    Currency(
      code: 'PKR',
      name: 'Pakistani Rupee',
      symbol: '₨',
      locale: 'en_PK',
    ),
    Currency(
      code: 'BDT',
      name: 'Bangladeshi Taka',
      symbol: '৳',
      locale: 'bn_BD',
    ),
    Currency(code: 'PLN', name: 'Polish Zloty', symbol: 'zł', locale: 'pl_PL'),
    Currency(code: 'CZK', name: 'Czech Koruna', symbol: 'Kč', locale: 'cs_CZ'),
    Currency(
      code: 'HUF',
      name: 'Hungarian Forint',
      symbol: 'Ft',
      locale: 'hu_HU',
    ),
    Currency(code: 'DKK', name: 'Danish Krone', symbol: 'kr', locale: 'da_DK'),
    Currency(code: 'ILS', name: 'Israeli Shekel', symbol: '₪', locale: 'he_IL'),
    Currency(
      code: 'CLP',
      name: 'Chilean Peso',
      symbol: 'CLP\$',
      locale: 'es_CL',
    ),
    Currency(
      code: 'ARS',
      name: 'Argentine Peso',
      symbol: 'AR\$',
      locale: 'es_AR',
    ),
    Currency(
      code: 'COP',
      name: 'Colombian Peso',
      symbol: 'COL\$',
      locale: 'es_CO',
    ),
    Currency(code: 'PEN', name: 'Peruvian Sol', symbol: 'S/', locale: 'es_PE'),
    Currency(code: 'NGN', name: 'Nigerian Naira', symbol: '₦', locale: 'en_NG'),
    Currency(
      code: 'KES',
      name: 'Kenyan Shilling',
      symbol: 'KSh',
      locale: 'en_KE',
    ),
    Currency(
      code: 'GHS',
      name: 'Ghanaian Cedi',
      symbol: 'GH₵',
      locale: 'en_GH',
    ),
    Currency(
      code: 'UAH',
      name: 'Ukrainian Hryvnia',
      symbol: '₴',
      locale: 'uk_UA',
    ),
    Currency(code: 'RON', name: 'Romanian Leu', symbol: 'lei', locale: 'ro_RO'),
    Currency(code: 'BGN', name: 'Bulgarian Lev', symbol: 'лв', locale: 'bg_BG'),
  ];

  static Currency getByCode(String code) {
    return currencies.firstWhere(
      (currency) => currency.code == code,
      orElse: () => currencies[0], // Default to USD
    );
  }
}
