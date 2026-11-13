import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/gamecenter/game_center_connection.dart';
import 'package:memory_survival/screens/settings_screen.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _productId = 'memory_survival_remove_ads';

PurchaseDetails _purchase(PurchaseStatus status) {
  final purchase = PurchaseDetails(
    productID: _productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'app_store',
    ),
    transactionDate: '0',
    status: status,
  );
  purchase.pendingCompletePurchase = true;
  if (status == PurchaseStatus.error) {
    purchase.error = IAPError(
      source: 'app_store',
      code: '2',
      message: 'SKErrorDomain Code=2',
    );
  }
  return purchase;
}

class _Store implements StoreBilling {
  final purchases = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  bool available = true;
  List<ProductDetails> products = const [];
  bool buyReturns = true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    return ProductDetailsResponse(
      productDetails: products,
      notFoundIDs: products.isEmpty ? ids.toList() : const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return buyReturns;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('IapEntitlementService', () {
    late _Store store;
    late IapEntitlementService service;

    setUp(() {
      store = _Store();
      service = IapEntitlementService(
        adRemovalProductId: _productId,
        billing: store,
      );
    });

    ProductDetails product() => ProductDetails(
      id: _productId,
      title: 'Unlock Premium',
      description: 'Remove all ads forever with one simple purchase',
      price: r'$2.99',
      rawPrice: 2.99,
      currencyCode: 'USD',
    );

    test('the button price comes from the store', () async {
      store.products = [product()];
      expect(await service.loadAdRemovalPrice(), r'$2.99');
    });

    test('a missing store explains itself without the product id', () async {
      store.available = false;
      expect(
        service.purchaseAdRemoval,
        throwsA(
          isA<PurchaseFlowException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('App Store is unavailable'),
              isNot(contains(_productId)),
              isNot(contains('Exception')),
            ),
          ),
        ),
      );
    });

    test(
      'a missing product explains itself without a Bad state error',
      () async {
        expect(
          service.purchaseAdRemoval,
          throwsA(
            isA<PurchaseFlowException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('not available'),
                isNot(contains('Bad state')),
                isNot(contains(_productId)),
              ),
            ),
          ),
        );
      },
    );

    test('an errored transaction is finished and told to the player', () async {
      await service.restore();
      final purchase = _purchase(PurchaseStatus.error);
      final message = service.purchaseErrors.first;
      store.purchases.add([purchase]);
      expect(await message, purchaseFailedMessage);
      expect(service.isAdFree, isFalse);
      expect(store.completed, [purchase]);
    });

    test(
      'a canceled transaction is finished and does not grant ad removal',
      () async {
        await service.restore();
        final purchase = _purchase(PurchaseStatus.canceled);
        store.purchases.add([purchase]);
        await Future<void>.delayed(Duration.zero);
        expect(service.isAdFree, isFalse);
        expect(store.completed, [purchase]);
      },
    );

    test('a restored transaction grants ad removal and is finished', () async {
      await service.restore();
      final purchase = _purchase(PurchaseStatus.restored);
      store.purchases.add([purchase]);
      await Future<void>.delayed(Duration.zero);
      expect(service.isAdFree, isTrue);
      expect(store.completed, [purchase]);
    });
  });

  group('Settings purchase', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    AppServices servicesFor(
      EntitlementService entitlement, {
      ConsentService? consent,
    }) {
      return AppServices(
        consent: consent ?? FakeConsentService(),
        entitlement: entitlement,
        ads: FakeAdService(),
        auth: FakePlatformGameAuthService(),
        connection: GameCenterConnection(
          auth: FakePlatformGameAuthService(),
          supported: true,
        ),
        progress: FakeGameCenterProgressService(),
        openUrl: (_) async {},
      );
    }

    testWidgets('a failed purchase shows a sentence, not an exception', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const message =
          'The App Store is unavailable right now. Please try again.';
      final services = servicesFor(
        FakeEntitlementService(purchaseFailure: message),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(services: services)),
      );
      await tester.pumpAndSettle();
      final button = find.byType(FilledButton);
      await tester.dragUntilVisible(
        button,
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.tap(button);
      await tester.pump();
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('Bad state'), findsNothing);
    });

    testWidgets(
      'ad privacy choices appear only when the message requires them',
      (tester) async {
        final hidden = servicesFor(FakeEntitlementService());
        await tester.pumpWidget(
          MaterialApp(home: SettingsScreen(services: hidden)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ad privacy choices'), findsNothing);

        final consent = FakeConsentService(privacyOptionsRequired: true);
        final shown = servicesFor(FakeEntitlementService(), consent: consent);
        await tester.pumpWidget(
          MaterialApp(home: SettingsScreen(services: shown)),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Ad privacy choices'), 200);
        await tester.tap(find.text('Ad privacy choices'));
        await tester.pumpAndSettle();
        expect(consent.privacyOptionsShown, 1);
      },
    );
  });
}
