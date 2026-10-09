import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare/core/network/care_api.dart';
import 'package:petcare/features/benefits/revenuecat_page.dart';

// Run with DISTRIBUTION_CHANNEL=google_play and a goog_ test-only public key.
class BillingApi extends CareApi {
  bool guest = false, paid = false, sameHousehold = true;
  int syncCalls = 0;
  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (path.endsWith('/session')) {
      if (guest) throw const ApiError(409, 'REGISTER_BEFORE_PURCHASE');
      return {
        'enabled': true,
        'appUserId': 'test-buyer',
        'offeringId': 'default',
        'products': ['family:monthly'],
        'sameHousehold': sameHousehold,
        'canPurchase': true,
        'sandbox': true,
      };
    }
    if (path.endsWith('/sync')) {
      syncCalls++;
      return {'tier': paid ? 'FAMILY' : 'FREE'};
    }
    throw StateError('Unexpected endpoint: $path');
  }
}

Map<String, Object?> package(String product) => {
      'identifier': product,
      'packageType': 'MONTHLY',
      'presentedOfferingContext': {'offeringIdentifier': 'default'},
      'product': {
        'identifier': product,
        'title': product,
        'description': 'Household plan',
        'price': 2.99,
        'priceString': r'$2.99',
        'currencyCode': 'USD',
        'subscriptionPeriod': 'P1M',
        'productCategory': 'SUBSCRIPTION',
      },
    };
final customer = {
  'originalAppUserId': 'test-buyer',
  'entitlements': {'all': {}, 'active': {}, 'verification': 'NOT_REQUESTED'},
  'activeSubscriptions': ['family:monthly'],
  'allPurchasedProductIdentifiers': ['family:monthly'],
  'allExpirationDates': {},
  'allPurchaseDates': {},
  'nonSubscriptionTransactions': [],
  'firstSeen': '2026-01-01T00:00:00Z',
  'requestDate': '2026-01-01T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  const channel = MethodChannel('purchases_flutter');
  final enabled = PlayBilling.channel == 'google_play' &&
      PlayBilling.publicKey.startsWith('goog_');
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isConfigured':
          return false;
        case 'setupPurchases':
          return null;
        case 'getOfferings':
          return {
            'all': {
              'default': {
                'identifier': 'default',
                'serverDescription': 'Plans',
                'metadata': {},
                'availablePackages': [
                  package('family:monthly'),
                  package('unapproved')
                ],
              }
            }
          };
        case 'purchasePackage':
          return {
            'customerInfo': customer,
            'transaction': {
              'transactionIdentifier': 'test-transaction',
              'productIdentifier': 'family:monthly',
              'purchaseDate': '2026-01-01T00:00:00Z'
            },
          };
        case 'restorePurchases':
          return customer;
        default:
          throw StateError('Unexpected SDK method: ${call.method}');
      }
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Future<void> show(WidgetTester tester, BillingApi api) async {
    await tester.pumpWidget(
        MaterialApp(home: RevenueCatPage(api: api, translate: (zh, en) => en)));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final button = find.text(text);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'SDK purchase success waits for server; restore confirms benefits',
      (tester) async {
    final api = BillingApi();
    await show(tester, api);
    expect(find.text('unapproved'), findsNothing);
    expect(find.text('Renews every 1 month'), findsOneWidget);
    await tap(tester, 'Subscribe with Google Play');
    expect(calls, contains('purchasePackage'));
    expect(api.syncCalls, 2);
    expect(find.text('Your household membership is confirmed.'), findsNothing);
    expect(find.textContaining('If charged, refresh later'), findsOneWidget);
    api.paid = true;
    await tap(tester, 'Restore purchases');
    expect(calls, contains('restorePurchases'));
    expect(
        find.text('Your household membership is confirmed.'), findsOneWidget);
  },
      skip: !enabled,
      variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('guest never initializes the payment SDK', (tester) async {
    await show(tester, BillingApi()..guest = true);
    expect(find.textContaining('Register or sign in'), findsOneWidget);
    expect(calls, isEmpty);
  },
      skip: !enabled,
      variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('household change before payment stops store purchase',
      (tester) async {
    final api = BillingApi();
    await show(tester, api);
    api.sameHousehold = false;
    await tap(tester, 'Subscribe with Google Play');
    expect(calls, isNot(contains('purchasePackage')));
    expect(api.syncCalls, 1);
  },
      skip: !enabled,
      variant: TargetPlatformVariant.only(TargetPlatform.android));
}
