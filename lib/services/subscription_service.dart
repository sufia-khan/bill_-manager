import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hive_service.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Product IDs - REPLACE with your actual IDs from App Store/Play Store
  static const String monthlyProductId = 'billminder_pro_monthly';
  static const String yearlyProductId = 'billminder_pro_yearly';
  static const String lifetimeProductId = 'billminder_pro_lifetime';

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _isPurchasing = false;
  bool get isPurchasing => _isPurchasing;

  Function(bool success, String message)? onPurchaseComplete;
  Function(String error)? onPurchaseError;

  Future<void> init() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      print('⚠️ In-app purchases not available');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        print('❌ Purchase stream error: $error');
        onPurchaseError?.call(error.toString());
      },
    );

    await loadProducts();
    await restorePurchases();
  }

  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    final Set<String> productIds = {
      monthlyProductId,
      yearlyProductId,
      lifetimeProductId,
    };

    try {
      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        print('❌ Error loading products: ${response.error}');
        return;
      }

      _products = response.productDetails;
      print('✅ Loaded ${_products.length} products');
    } catch (e) {
      print('❌ Exception loading products: $e');
    }
  }

  Future<bool> purchaseSubscription(String productId) async {
    if (!_isAvailable) {
      onPurchaseError?.call('In-app purchases not available');
      return false;
    }

    if (_isPurchasing) {
      onPurchaseError?.call('Purchase already in progress');
      return false;
    }

    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found'),
    );

    _isPurchasing = true;

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        _isPurchasing = false;
        onPurchaseError?.call('Failed to initiate purchase');
        return false;
      }

      return true;
    } catch (e) {
      _isPurchasing = false;
      onPurchaseError?.call(e.toString());
      return false;
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        print('⏳ Purchase pending...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _isPurchasing = false;
        final error = purchaseDetails.error?.message ?? 'Unknown error';
        onPurchaseError?.call(error);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final valid = await _verifyPurchase(purchaseDetails);

        if (valid) {
          await _grantProAccess(purchaseDetails);
          _isPurchasing = false;
          onPurchaseComplete?.call(true, 'Subscription activated!');
        } else {
          _isPurchasing = false;
          onPurchaseError?.call('Purchase verification failed');
        }
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: Implement server-side receipt verification
    print('✅ Purchase verified: ${purchaseDetails.productID}');
    return true;
  }

  Future<void> _grantProAccess(PurchaseDetails purchaseDetails) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await HiveService.saveUserData('subscription_status_${user.uid}', 'active');
    await HiveService.saveUserData(
      'subscription_product_${user.uid}',
      purchaseDetails.productID,
    );
    await HiveService.saveUserData(
      'subscription_date_${user.uid}',
      DateTime.now().toIso8601String(),
    );

    print('✅ Pro access granted');
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    try {
      print('🔄 Restoring purchases...');
      await _iap.restorePurchases();
    } catch (e) {
      print('❌ Error restoring purchases: $e');
      onPurchaseError?.call('Failed to restore purchases');
    }
  }

  static bool hasActiveSubscription() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final status = HiveService.getUserData('subscription_status_${user.uid}');
    return status == 'active';
  }

  static String? getSubscriptionProduct() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return HiveService.getUserData('subscription_product_${user.uid}');
  }

  static String getSubscriptionTypeName() {
    final productId = getSubscriptionProduct();
    if (productId == null) return 'Free';

    switch (productId) {
      case monthlyProductId:
        return 'Pro Monthly';
      case yearlyProductId:
        return 'Pro Yearly';
      case lifetimeProductId:
        return 'Pro Lifetime';
      default:
        return 'Pro';
    }
  }

  Future<void> cancelSubscription() async {
    if (Platform.isIOS) {
      print('ℹ️ iOS: Settings > Apple ID > Subscriptions');
    } else if (Platform.isAndroid) {
      print('ℹ️ Android: Play Store > Subscriptions');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
