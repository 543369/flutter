import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/care_api.dart';

class PlayBilling {
  static const channel = String.fromEnvironment('DISTRIBUTION_CHANNEL');
  static const publicKey = String.fromEnvironment('REVENUECAT_GOOGLE_API_KEY');
  static bool get available =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      channel == 'google_play' &&
      publicKey.startsWith('goog_');

  static Future<void> identify(String userId) async {
    if (!available) throw StateError('Google Play billing is not configured');
    if (!await Purchases.isConfigured) {
      await Purchases.configure(
          PurchasesConfiguration(publicKey)..appUserID = userId);
    } else if (await Purchases.appUserID != userId) {
      await Purchases.logIn(userId);
    }
  }
}

class RevenueCatPage extends StatefulWidget {
  const RevenueCatPage({super.key, required this.api, required this.translate});
  final CareApi api;
  final String Function(String, String) translate;
  @override
  State<RevenueCatPage> createState() => _RevenueCatPageState();
}

class _RevenueCatPageState extends State<RevenueCatPage> {
  List<Package> packages = [];
  Map<String, dynamic>? session;
  bool busy = true, active = false;
  String? message;
  String t(String zh, String en) => widget.translate(zh, en);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<Map<String, dynamic>> getSession() async => Map<String, dynamic>.from(
      await widget.api.request('POST', '/billing/revenuecat/session') as Map);

  Future<void> load() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (!PlayBilling.available) throw StateError('Not configured');
      final result = await getSession();
      if (result['enabled'] != true) throw StateError('Not enabled');
      await PlayBilling.identify(result['appUserId'] as String);
      final offerings = await Purchases.getOfferings();
      final offering = offerings.all[result['offeringId']];
      final allowed = Set<String>.from(result['products'] as List);
      final status = Map<String, dynamic>.from(
          await widget.api.request('POST', '/billing/revenuecat/sync') as Map);
      if (!mounted) return;
      setState(() {
        session = result;
        active = status['tier'] == 'FAMILY';
        packages = offering?.availablePackages
                .where((p) =>
                    allowed.contains(p.storeProduct.identifier) &&
                    p.storeProduct.subscriptionPeriod != null)
                .toList() ??
            [];
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          message = e is ApiError && e.code == 'REGISTER_BEFORE_PURCHASE'
              ? t('请先注册或登录可找回的账号，再购买会员。',
                  'Register or sign in to a recoverable account before purchasing.')
              : e is ApiError && e.status == 403
                  ? t('请由家庭管理员购买会员。',
                      'A household administrator must purchase membership.')
                  : t('会员购买暂不可用，请稍后重试。',
                      'Membership purchases are unavailable. Please try again later.');
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> transact({Package? package}) async {
    if (busy || session == null) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final latest = await getSession();
      if (latest['enabled'] != true ||
          latest['appUserId'] != session!['appUserId'] ||
          (package != null &&
              (latest['sameHousehold'] != true ||
                  latest['canPurchase'] != true))) {
        throw StateError('Account changed');
      }
      await PlayBilling.identify(latest['appUserId'] as String);
      if (package == null) {
        await Purchases.restorePurchases();
      } else {
        await Purchases.purchase(PurchaseParams.package(package));
      }
      // Never grant family benefits from SDK success or client entitlement data.
      final status = Map<String, dynamic>.from(
          await widget.api.request('POST', '/billing/revenuecat/sync') as Map);
      if (!mounted) return;
      setState(() {
        active = status['tier'] == 'FAMILY';
        message = active
            ? t('家庭会员权益已确认。', 'Your household membership is confirmed.')
            : t('暂未确认当前家庭的有效会员。若已扣款，请稍后刷新状态，不要重复购买。',
                'No active membership confirmed for this household yet. If charged, refresh later instead of purchasing again.');
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      setState(() => message = code == PurchasesErrorCode.purchaseCancelledError
          ? t('已取消购买。', 'Purchase cancelled.')
          : t('交易尚未确认，请检查 Google Play 订单后刷新状态。',
              'Transaction not confirmed. Check your Google Play orders, then refresh.'));
    } catch (_) {
      if (mounted) {
        setState(() => message = t('暂时无法确认结果。若已扣款，请刷新状态或恢复购买，不要重复付款。',
            'Unable to confirm the result. If charged, refresh or restore purchases instead of paying again.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> manage() async {
    bool opened = false;
    try {
      opened = await launchUrl(
          Uri.parse('https://play.google.com/store/account/subscriptions'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      // Some devices do not have an application that can open this link.
    }
    if (!opened && mounted) {
      setState(() => message = t('请在 Google Play → 付款和订阅中管理会员。',
          'Manage membership in Google Play → Payments & subscriptions.'));
    }
  }

  String renewalPeriod(String? period) {
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(period ?? '');
    if (match == null) return t('续费周期：$period', 'Renewal period: $period');
    final count = match.group(1)!;
    final unit = match.group(2)!;
    final zh = {'D': '天', 'W': '周', 'M': '个月', 'Y': '年'}[unit]!;
    final en = {'D': 'day', 'W': 'week', 'M': 'month', 'Y': 'year'}[unit]!;
    return t('每 $count $zh 自动续费',
        'Renews every $count $en${count == '1' ? '' : 's'}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('家庭会员', 'Household membership'))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Text(t('一人购买，全家共享', 'One membership for your household'),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(t(
                    '会员关联到首次进入购买页时的家庭，换家庭不会自动转移。由 Google Play 收款；订阅会按商店确认页所示周期自动续费，可在 Google Play 取消。',
                    'Membership is linked to the household when billing is first set up and does not move automatically. Google Play handles payment. Subscriptions renew automatically as shown on the store confirmation screen; cancel in Google Play.')),
                const SizedBox(height: 16),
                if (session?['sandbox'] == true)
                  Text(t('测试环境 · 不代表生产会员',
                      'Test environment · Not a production membership')),
                if (busy) const LinearProgressIndicator(),
                if (message != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(message!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary))),
                if (active)
                  Text(t('当前家庭已享有会员权益。',
                      'Your household already has membership benefits.')),
                if (session?['sameHousehold'] == false)
                  Text(t('此账号的购买关系属于原家庭，请先管理原订阅。',
                      'This account is linked to its original household. Manage the existing subscription first.')),
                if (!busy && session != null && packages.isEmpty)
                  Text(t('套餐尚未开放。', 'No plans are currently available.')),
                for (final package in packages)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(package.storeProduct.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(package.storeProduct.description),
                                Text(package.storeProduct.priceString,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                Text(renewalPeriod(
                                    package.storeProduct.subscriptionPeriod)),
                                const SizedBox(height: 10),
                                FilledButton(
                                    onPressed: busy ||
                                            active ||
                                            session?['canPurchase'] != true ||
                                            session?['sameHousehold'] != true
                                        ? null
                                        : () => transact(package: package),
                                    child: Text(t('通过 Google Play 订阅',
                                        'Subscribe with Google Play'))),
                              ]))),
                TextButton(
                    onPressed:
                        busy || session == null ? null : () => transact(),
                    child: Text(t('恢复购买', 'Restore purchases'))),
                TextButton(
                    onPressed: busy ? null : load,
                    child: Text(t('刷新状态', 'Refresh status'))),
                TextButton(
                    onPressed: busy ? null : manage,
                    child: Text(t('管理／取消订阅', 'Manage / cancel subscription'))),
              ]))));
}
