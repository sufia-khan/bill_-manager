# Payment Integration Setup

## What's Added
- Subscription service for in-app purchases
- Subscription screen with plan selection
- Settings integration with upgrade buttons
- Trial service updated to check subscriptions

## Quick Setup

### 1. Update Product IDs
Edit `lib/services/subscription_service.dart`:
```dart
static const String monthlyProductId = 'your_monthly_id';
static const String yearlyProductId = 'your_yearly_id';
static const String lifetimeProductId = 'your_lifetime_id';
```

### 2. Configure App Store (iOS)
- Go to App Store Connect
- Create 3 in-app purchases (monthly, yearly, lifetime)
- Set pricing and submit for review

### 3. Configure Play Store (Android)
- Go to Google Play Console
- Create subscriptions and products
- Set pricing and activate

### 4. Test
- iOS: Use sandbox tester account
- Android: Use internal testing track

## Features
- Monthly subscription
- Yearly subscription (best value)
- Lifetime purchase
- Restore purchases
- Subscription management

## Next Steps
1. Set up products in stores
2. Update product IDs in code
3. Test with sandbox accounts
4. Submit for review
5. Launch!
