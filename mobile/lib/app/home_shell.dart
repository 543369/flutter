import '../core/theme/app_spacing.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/care_api.dart';
import '../features/auth/auth_panel.dart';
import '../features/care/reminder_service.dart';
import '../features/care/care_view.dart';
import '../features/care/care_pages.dart';
import '../features/pets/pet_module.dart';
import '../features/family/family_module.dart';
import '../core/widgets/brand_motion.dart';

class CareHome extends StatefulWidget {
  const CareHome(
      {super.key, required this.api, required this.onLocale, this.reminders});
  final CareApi api;
  final ReminderService? reminders;
  final ValueChanged<Locale> onLocale;
  @override
  State<CareHome> createState() => CareHomeState();
}

class CareHomeState extends State<CareHome> with WidgetsBindingObserver {
  late final ReminderService reminders = widget.reminders ?? ReminderService();
  // Keep pushed care pages in sync with mutations and background dashboard updates.
  final careChanges = ValueNotifier<int>(0);
  void updateUi(VoidCallback action) {
    final hadData = data != null;
    setState(action);
    if (hadData && data == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    careChanges.value++;
  }

  final pendingTaskIds = <String>{};
  final detailTaskIds = <String, int>{};
  String? pendingNotification;
  bool routingNotification = false;
  DateTime? lastSyncedAt;
  bool taskBusy(String id) => busy || pendingTaskIds.contains(id);
  Timer? refreshTimer;
  bool syncing = false;
  final submittingTasks = <String>{};
  final taskWrites = <String, Completer<void>>{};
  String? pendingNotification;
  bool pendingNotificationTap = false;
  Completer<void>? syncDone;
  String? reminderError;
  String? selectedPetId;
  bool loading = true, busy = false;
  String? error;
  bool accessExpired = false;
  int tab = 0;
  Map<String, dynamic>? data;
  bool get zh => Localizations.localeOf(context).languageCode == 'zh';
  String t(String cn, String en) => zh ? cn : en;
  List<Map<String, dynamic>> get pets => (data?['pets'] as List? ?? [])
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();
  List<Map<String, dynamic>> get tasks => (data?['tasks'] as List? ?? [])
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();
  Map<String, dynamic>? get selectedPet {
    if (pets.isEmpty) return null;
    return pets.cast<Map<String, dynamic>>().firstWhere(
        (pet) => pet['id'] == selectedPetId,
        orElse: () => pets.first);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restore();
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        updateUi(() {});
        refreshQuietly();
      }
    });
  }

  Future<void> restore() async {
    try {
      await widget.api.restore();
      if (widget.api.token != null) data = await widget.api.dashboard();
    } on ApiError catch (e) {
      if (e.status == 401) {
        await widget.api.clearSession();
        data = null;
      } else if (e.code == 'ACCESS_EXPIRED') {
        accessExpired = true;
        data = null;
      } else {
        error = 'connection';
      }
    } catch (_) {
      error = 'connection';
    }
    try {
      await reminders.initialize((taskId) {
        pendingNotification = taskId;
        pendingNotificationTap = true;
        if (!loading) openNotificationTask();
      });
      if (data != null || widget.api.token == null) await syncReminders();
    } catch (_) {
      reminderError = 'unavailable';
    }
    if (mounted) {
      updateUi(() => loading = false);
      if (pendingNotificationTap) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => openNotificationTask());
      }
    }
  }

  Future<void> openNotificationTask() async {
    final id = pendingNotification;
    pendingNotification = null;
    pendingNotificationTap = false;
    if (!mounted) return;
    if (id == null) {
      updateUi(() {
        tab = 0;
        careFilter = 'pending';
      });
      await refreshQuietly();
      return;
    }
    try {
      final task = Map<String, dynamic>.from(
          await widget.api.request('GET', '/tasks/$id') as Map);
      if (!mounted) return;
      updateUi(() {
        tab = 0;
        selectedPetId = task['petId'] as String;
        final current = tasks.where((t) => t['id'] != id).toList()..add(task);
        data?['tasks'] = current;
      });
      await openTaskDetails(task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message(e))));
      }
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    careChanges.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateUi(() {});
      refreshQuietly();
    }
  }

  Future<void> syncReminders() async {
    if (!mounted) return;
    try {
      await reminders.sync(
          widget.api.token == null
              ? []
              : (data?['reminderTasks'] as List? ?? tasks)
                  .map((t) => Map<String, dynamic>.from(t as Map))
                  .toList(),
          chinese: zh);
      reminderError = null;
    } catch (_) {
      reminderError = 'unavailable';
    }
  }

  Future<void> refreshQuietly() async {
    if (!mounted ||
        loading ||
        busy ||
        syncing ||
        submittingTasks.isNotEmpty ||
        widget.api.token == null) {
      return;
    }
    syncing = true;
    syncDone = Completer<void>();
    try {
      final next = await loadDashboard();
      if (mounted) {
        updateUi(() {
          data = next;
          lastSyncedAt = DateTime.now();
          accessExpired = false;
          error = null;
        });
        await syncReminders();
      }
    } on ApiError catch (e) {
      if (e.status == 401) {
        await widget.api.clearSession();
        if (mounted) {
          updateUi(() => data = null);
          await syncReminders();
        }
      } else if (e.code == 'ACCESS_EXPIRED' && mounted) {
        updateUi(() {
          accessExpired = true;
          data = null;
        });
        await syncReminders();
      } else if (mounted) {
        updateUi(() => error = 'connection');
      }
    } catch (_) {
      if (mounted) updateUi(() => error = 'connection');
    } finally {
      syncing = false;
      syncDone?.complete();
      if (mounted) {
        updateUi(() {});
        routeNotification();
      }
    }
  }

  Future<void> toggleReminders(bool value) async {
    if (busy || pendingTaskIds.isNotEmpty) return;
    updateUi(() => busy = true);
    try {
      await syncDone?.future;
      if (!mounted) return;
      if (!reminders.ready) {
        await reminders.initialize((taskId) {
          pendingNotification = taskId;
          pendingNotificationTap = true;
          openNotificationTask();
        });
      }
      final granted = await reminders.setEnabled(value);
      await syncReminders();
      if (!mounted) return;
      if (value && !granted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('通知权限未开启，请在系统设置中允许通知。',
                'Notifications are disabled. Allow them in system settings.'))));
      }
    } catch (_) {
      reminderError = 'unavailable';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(message(const ApiError(0, 'REMINDERS_UNAVAILABLE')))));
      }
    } finally {
      if (mounted) updateUi(() => busy = false);
    }
  }

  bool can(String permission) {
    final access = data?['access'] as Map?;
    if (access == null) return true;
    if (access['role'] == 'ADMIN') return true;
    return permission != 'ADMIN' &&
        (access['permissions'] as String? ?? '')
            .split(',')
            .contains(permission);
  }

  String message(Object e) {
    if (e is ApiError) {
      if (e.code == 'ACCESS_EXPIRED') {
        return t('临时照护权限已到期，请联系家庭管理员续期。',
            'Your access has expired. Ask a household admin to renew it.');
      }
      if (e.code == 'PERMISSION_DENIED') {
        return t('当前角色没有此操作权限，请联系家庭管理员。',
            'Your role cannot perform this action. Contact a household admin.');
      }
      if (e.code == 'LAST_ADMIN') {
        return t('请先指定另一位管理员，再退出或调整自己的角色。',
            'Assign another administrator before leaving or changing your role.');
      }
      if (e.status == 413) {
        return t('家庭共享空间已满，请到家庭权益查看用量，或删除不需要的照片、健康附件。',
            'Household storage is full. Review usage in Household benefits, or delete unwanted photos or health attachments.');
      }
      if (e.status == 403) {
        return t('当前家庭暂未开放此权益。',
            'This benefit is not available for your household.');
      }
      if (e.code == 'REMINDERS_UNAVAILABLE') {
        return t('无法设置提醒，请检查系统通知权限后重试。',
            'Could not set up reminders. Check system notification permissions and retry.');
      }
      if (e.status == 401) {
        return t('设备身份失效，请检查后端环境。',
            'Device session expired. Check the server environment.');
      }
      if (e.code == 'TASK_NOT_PENDING') {
        return t('此安排状态已变化，请刷新后重试。',
            'This task has changed. Refresh and try again.');
      }
      if (e.status == 409) {
        return t('仅没有宠物的独立家庭可加入其他家庭。',
            'Only an empty, single-member household can join another.');
      }
      if (e.status == 404) {
        return t('记录不存在，或邀请码已失效。', 'Record not found, or invitation expired.');
      }
      if (e.status == 400) return t('请检查输入内容。', 'Please check your input.');
      if (e.code == 'HTTPS_REQUIRED') {
        return t(
            '正式版本需要 HTTPS 服务地址。', 'Release builds require an HTTPS server.');
      }
    }
    return t('连接失败，请检查网络及 API 地址后重试。',
        'Connection failed. Check your network and API URL, then retry.');
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy || pendingTaskIds.isNotEmpty) return;
    updateUi(() => busy = true);
    await Future.wait(taskWrites.values.map((c) => c.future));
    await syncDone?.future;
    if (!mounted) return;
    bool saved = false;
    try {
      await action();
      saved = true;
      final next =
          widget.api.token == null ? null : await widget.api.dashboard();
      if (mounted) {
        updateUi(() {
          data = next;
          lastSyncedAt = DateTime.now();
          accessExpired = false;
          error = null;
        });
        await syncReminders();
      }
    } catch (e) {
      if (e is ApiError && e.code == 'ACCESS_EXPIRED' && mounted) {
        updateUi(() {
          accessExpired = true;
          data = null;
        });
        await syncReminders();
      }
      if (e is ApiError && e.status == 401) {
        await widget.api.clearSession();
        if (mounted) {
          updateUi(() => data = null);
          await syncReminders();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(saved
                ? t('操作已保存，但列表更新失败，请下拉刷新。',
                    'Saved, but the list could not refresh. Pull to retry.')
                : message(e))));
      }
    } finally {
      if (mounted) updateUi(() => busy = false);
    }
  }

  Future<void> bindAccount() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(
              appBar: AppBar(title: Text(t('绑定邮箱账号', 'Create an account'))),
              body: SafeArea(
                  child: AuthPanel(
                      api: widget.api,
                      binding: true,
                      onAuthenticated: () async {
                        Navigator.of(context).pop();
                      })),
            )));
    if (mounted) await perform(() async {});
  }

  Future<void> logout() async {
    if (!await confirm(
        t('退出登录？', 'Sign out?'),
        t('本机停止提醒，账号和家庭记录保留。',
            'Reminders on this device stop. Your account and household records remain.'))) {
      return;
    }
    await perform(widget.api.logout);
  }

  Future<bool> confirm(String title, String detail) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(title),
                content: Text(detail),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(t('取消', 'Cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(t('确认', 'Confirm'))),
                ],
              )) ??
      false;
  String dateLabel(DateTime date) =>
      '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  Widget empty(String title, String detail, IconData icon) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center),
      ]));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: data == null || tab == 0
          ? null
          : AppBar(
              title: const BrandWordmark(),
              actions: [
                IconButton(
                  tooltip: t('切换语言', 'Switch language'),
                  onPressed: () => widget.onLocale(Locale(zh ? 'en' : 'zh')),
                  icon: const Icon(Icons.language),
                ),
                if (data != null)
                  IconButton(
                    tooltip: t('刷新', 'Refresh'),
                    onPressed: busy ? null : () => perform(() async {}),
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: GentleSwitch(
              child: loading
                  ? const SizedBox.expand(
                      key: ValueKey('loading'),
                      child: PawLoading(),
                    )
                  : Stack(
                      key: const ValueKey('content'),
                      children: [
                        Positioned.fill(
                          child: data == null
                              ? welcome()
                              : GentleSwitch(
                                  child: RefreshIndicator(
                                    key: ValueKey(tab),
                                    onRefresh: () => perform(() async {}),
                                    child: tab == 0
                                        ? careScrollView()
                                        : ListView(
                                            key:
                                                PageStorageKey('home-tab-$tab'),
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            padding: AppSpacing.pageInsets,
                                            children: tab == 1
                                                ? petView()
                                                : familyView(),
                                          ),
                                  ),
                                ),
                        ),
                        if (busy)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: data == null
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => updateUi(() => tab = v),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  selectedIcon: const Icon(Icons.check_circle_rounded),
                  label: t('照护', 'Care'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.pets_outlined),
                  selectedIcon: const Icon(Icons.pets),
                  label: t('宠物', 'Pets'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.people_outline_rounded),
                  selectedIcon: const Icon(Icons.people_rounded),
                  label: t('家庭', 'Family'),
                ),
              ],
            ),
    );
  }

  Widget welcome() => accessExpired
      ? Center(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_off_outlined, size: 48),
                const SizedBox(height: 18),
                Text(t('临时照护权限已到期', 'Care access has expired'),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(t('联系家庭管理员续期，或退出这个家庭。',
                    'Ask an administrator to renew access, or leave this home.')),
                TextButton(
                    onPressed: busy ? null : () => perform(() async {}),
                    child: Text(t('检查权限', 'Check access'))),
                const SizedBox(height: AppSpacing.inline),
                OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => perform(() async {
                              await widget.api.request('POST', '/family/leave');
                            }),
                    child: Text(t('退出当前家庭', 'Leave household'))),
                const SizedBox(height: AppSpacing.inline),
                TextButton(
                    onPressed: busy ? null : () => perform(widget.api.logout),
                    child: Text(t('退出登录', 'Sign out'))),
              ])))
      : widget.api.token != null && error != null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(t('暂时无法同步家庭数据', 'Unable to sync household data')),
                    const SizedBox(height: 12),
                    Text(t('检查网络后重试。', 'Check your connection and retry.')),
                    FilledButton(
                        onPressed: busy ? null : () => perform(() async {}),
                        child: Text(t('重试', 'Retry'))),
                  ])))
          : AuthPanel(
              api: widget.api,
              onAuthenticated: () async {
                await perform(() async {});
              });
}
