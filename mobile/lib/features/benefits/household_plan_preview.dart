import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

/// Plan overview for channels where purchasing is not available.
/// Reference prices are illustrative; checkout always uses store product prices.
class HouseholdPlanPreview extends StatelessWidget {
  const HouseholdPlanPreview({super.key, required this.translate});
  final String Function(String, String) translate;
  String t(String zh, String en) => translate(zh, en);

  Widget plan(BuildContext context, {required bool annual}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.dialogInsets,
      decoration: BoxDecoration(
        color: annual ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: annual ? colors.primary : colors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            spacing: AppSpacing.inline,
            runSpacing: AppSpacing.inline,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    annual
                        ? t('长久相伴', 'Lasting Together')
                        : t('暖心陪伴', 'Warm Companionship'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.tight),
                Text(
                    annual
                        ? t('连续包年', 'Annual subscription')
                        : t('连续包月', 'Monthly subscription'),
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ]),
        const SizedBox(height: AppSpacing.content),
        Text(t('国内参考价', 'China reference price'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.tight),
        Text(annual ? '¥128' : '¥15',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.tight),
        Text(annual
            ? t('每家庭／年', 'per household / year')
            : t('每家庭／月', 'per household / month')),
        const SizedBox(height: AppSpacing.inline),
        Text(
            annual
                ? t('海外参考价 US\$29.99／年', 'Overseas reference US\$29.99 / year')
                : t('海外参考价 US\$3.99／月', 'Overseas reference US\$3.99 / month'),
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.inline),
        Text(
            annual
                ? t('每年自动续费，可取消续订',
                    'Renews automatically each year. Cancel renewal anytime.')
                : t('每月自动续费，可取消续订',
                    'Renews automatically each month. Cancel renewal anytime.'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.section),
        FilledButton(onPressed: null, child: Text(t('即将开放', 'Coming soon'))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('一份会员，全家共享', 'One membership for your household'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.inline),
          Text(t(
              '家人和毛孩子，共享同一份照护空间。', 'A shared care space for family and pets.')),
          const SizedBox(height: AppSpacing.content),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth >= 560
                ? (constraints.maxWidth - AppSpacing.content) / 2
                : constraints.maxWidth;
            return Wrap(
                spacing: AppSpacing.content,
                runSpacing: AppSpacing.content,
                children: [
                  SizedBox(width: width, child: plan(context, annual: false)),
                  SizedBox(width: width, child: plan(context, annual: true)),
                ]);
          }),
          const SizedBox(height: AppSpacing.content),
          Text(
              t('连续包月、连续包年享相同权益', 'The same benefits with either subscription'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.inline),
          for (final item in [
            t('故事不限篇数，图片计入家庭空间',
                'Unlimited stories; photos count towards household storage'),
            t('1 GB 家庭共享照片空间', '1 GB of shared family photo storage'),
            t('每条健康记录最多 12 张图片附件',
                'Up to 12 image attachments per health record'),
            t('回忆录 PDF 与年度报告导出', 'Memory book PDFs and annual report exports'),
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.inline),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: AppSpacing.inline),
                      Expanded(child: Text(item)),
                    ])),
          const SizedBox(height: AppSpacing.inline),
          Text(
              t('两种套餐均为自动续费订阅，并非一次性购买。取消续订后，权益保留至已付周期结束。通过 Google Play 购买的订阅可在 Google Play 的订阅管理中取消。',
                  'Both plans renew automatically and are not one-time purchases. After cancellation, benefits remain until the paid period ends. Google Play subscriptions can be cancelled in Google Play subscription settings.'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.inline),
          Text(
              t('基础照护记录、基础共享与授权管理保持免费。以上仅为配置参考价，当前版本暂未开放购买；正式购买将直接展示商店返回的当地币种、实际价格和订阅周期。',
                  'Basic care records, sharing and authorization remain free. These are configuration reference prices only. Purchases are not available in this version. Actual prices, currency and subscription periods come directly from the store.'),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
