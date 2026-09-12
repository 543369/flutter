import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/care_api.dart';
import '../features/auth/auth_panel.dart';
import '../features/care/reminder_service.dart';
import '../features/care/care_actions.dart';
import '../features/care/care_view.dart';
import '../features/pets/pet_module.dart';
import '../features/family/family_module.dart';

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
    setState(action);
    careChanges.value++;
  }

  Timer? refreshTimer;
  bool syncing = false;
  Completer<void>? syncDone;
  String? reminderError;
  String careFilter = 'pending';
  String? selectedPetId;
  bool loading = true, busy = false;
  String? error;
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
      } else {
        error = 'connection';
      }
    } catch (_) {
      error = 'connection';
    }
    try {
      await reminders.initialize(() {
        if (mounted) {
          updateUi(() {
            tab = 0;
            careFilter = 'pending';
          });
          refreshQuietly();
        }
      });
      if (data != null || widget.api.token == null) await syncReminders();
    } catch (_) {
      reminderError = 'unavailable';
    }
    if (mounted) updateUi(() => loading = false);
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
    if (state == AppLifecycleState.resumed) refreshQuietly();
  }

  Future<void> syncReminders() async {
    if (!mounted) return;
    try {
      await reminders.sync(widget.api.token == null ? [] : tasks, chinese: zh);
      reminderError = null;
    } catch (_) {
      reminderError = 'unavailable';
    }
  }

  Future<void> refreshQuietly() async {
    if (!mounted || loading || busy || syncing || widget.api.token == null) {
      return;
    }
    syncing = true;
    syncDone = Completer<void>();
    try {
      final next = await widget.api.dashboard();
      if (mounted) {
        updateUi(() {
          data = next;
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
      } else if (mounted) {
        updateUi(() => error = 'connection');
      }
    } catch (_) {
      if (mounted) updateUi(() => error = 'connection');
    } finally {
      syncing = false;
      syncDone?.complete();
      if (mounted) updateUi(() {});
    }
  }

  Future<void> toggleReminders(bool value) async {
    if (busy) return;
    updateUi(() => busy = true);
    try {
      await syncDone?.future;
      if (!mounted) return;
      if (!reminders.ready) {
        await reminders.initialize(() {
          if (mounted) {
            updateUi(() {
              tab = 0;
              careFilter = 'pending';
            });
            refreshQuietly();
          }
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

  String message(Object e) {
    if (e is ApiError) {
      if (e.code == 'REMINDERS_UNAVAILABLE') {
        return t('无法设置提醒，请检查系统通知权限后重试。',
            'Could not set up reminders. Check system notification permissions and retry.');
      }
      if (e.status == 401) {
        return t('设备身份失效，请检查后端环境。',
            'Device session expired. Check the server environment.');
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
    if (busy) return;
    updateUi(() => busy = true);
    await syncDone?.future;
    if (!mounted) return;
    try {
      await action();
      final next =
          widget.api.token == null ? null : await widget.api.dashboard();
      if (mounted) {
        updateUi(() {
          data = next;
          error = null;
        });
        await syncReminders();
      }
    } catch (e) {
      if (e is ApiError && e.status == 401) {
        await widget.api.clearSession();
        if (mounted) {
          updateUi(() => data = null);
          await syncReminders();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message(e))));
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
          : AppBar(title: Text(t('爪伴', 'PetCare')), actions: [
              IconButton(
                  tooltip: t('切换语言', 'Switch language'),
                  onPressed: () => widget.onLocale(Locale(zh ? 'en' : 'zh')),
                  icon: const Icon(Icons.language)),
              if (data != null)
                IconButton(
                    tooltip: t('刷新', 'Refresh'),
                    onPressed: busy ? null : () => perform(() async {}),
                    icon: const Icon(Icons.refresh)),
            ]),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                if (busy) const LinearProgressIndicator(),
                Expanded(
                    child: data == null
                        ? welcome()
                        : RefreshIndicator(
                            onRefresh: () => perform(() async {}),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: tab == 0
                                  ? const EdgeInsets.only(bottom: 24)
                                  : const EdgeInsets.fromLTRB(18, 14, 18, 104),
                              children: tab == 0
                                  ? careView()
                                  : tab == 1
                                      ? petView()
                                      : familyView(),
                            ))),
              ]),
      ))),
      bottomNavigationBar: data == null
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => updateUi(() => tab = v),
              destinations: [
                  NavigationDestination(
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      selectedIcon: const Icon(Icons.check_circle_rounded),
                      label: t('照护', 'Care')),
                  NavigationDestination(
                      icon: const Icon(Icons.pets_outlined),
                      selectedIcon: const Icon(Icons.pets),
                      label: t('宠物', 'Pets')),
                  NavigationDestination(
                      icon: const Icon(Icons.people_outline_rounded),
                      selectedIcon: const Icon(Icons.people_rounded),
                      label: t('家庭', 'Family')),
                ]),
      floatingActionButton: data == null || tab == 2 || tab == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: busy
                  ? null
                  : tab == 0
                      ? addTask
                      : addPet,
              icon: const Icon(Icons.add),
              label: Text(
                  tab == 0 ? t('安排照护', 'Plan care') : t('添加宠物', 'Add pet'))),
    );
  }

  Widget welcome() => AuthPanel(
      api: widget.api,
      onAuthenticated: () async {
        await perform(() async {});
      });
}
