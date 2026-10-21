import '../core/theme/app_spacing.dart';
import 'dart:async';
import '../core/sync/push_service.dart';
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
  late final PushService push = PushService(widget.api, refreshQuietly);
  String? pushError;
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
  DateTime? lastSyncedAt;
  bool taskBusy(String id) => busy || submittingTasks.contains(id);
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
  String careFilter = 'pending';
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
    widget.api.offlineCare.addListener(offlineChanged);
    restore();
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        updateUi(() {});
        refreshQuietly();
      }
    });
  }

  void offlineChanged() {
    if (!mounted) return;
    final snapshot = widget.api.offlineCare.snapshot;
    updateUi(() {
      if (data != null &&
          snapshot != null &&
          data!['householdId'] == snapshot['householdId']) {
        for (final key in ['tasks', 'history', 'reminderTasks']) {
          data![key] = snapshot[key];
        }
      }
    });
  }

  String syncReason(String? code) => switch (code) {
        'SYNC_CONFLICT' || 'TASK_NOT_PENDING' => t('家人已修改此事项，请核对最新记录。',
            'This task changed on another device. Review the latest record.'),
        'HOUSEHOLD_CHANGED' => t('所属家庭已变化，旧家庭操作不会上传。',
            'Your household changed. Changes for the previous household will not upload.'),
        'ACCESS_EXPIRED' || 'PERMISSION_DENIED' => t('当前照护权限不足，请联系家庭管理员。',
            'Ask an administrator to restore your care access.'),
        'INVALID_CARE_TIME' => t('安排时间已过，请核对后重新改期。',
            'The selected time has passed. Choose a new time.'),
        _ => t('此操作暂时无法同步，请核对最新记录后重新操作。',
            'This change could not sync. Review the current record before trying again.'),
      };

  String syncAction(Map body) => switch (body['action']) {
        'COMPLETE' => t('完成照护', 'Complete care'),
        'REOPEN' => t('撤销完成', 'Undo completion'),
        'RESCHEDULE' => t('改期至 ', 'Reschedule to ') +
            dateLabel(DateTime.parse(body['dueAt'] as String).toLocal()),
        'ASSIGN' => t('调整照护人', 'Change caregiver'),
        'SKIP' => t('跳过本次', 'Skip occurrence'),
        'CANCEL' => t('取消本次', 'Cancel occurrence'),
        _ => t('编辑照护', 'Edit care'),
      };

  Future<void> startPush() async {
    try {
      await push.start();
      if (mounted) updateUi(() => pushError = null);
    } catch (_) {
      if (mounted) updateUi(() => pushError = 'unavailable');
    }
  }

  Future<void> openSyncQueue() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (pageContext) => ListenableBuilder(
            listenable: widget.api.offlineCare,
            builder: (context, _) {
              final queue = widget.api.offlineCare;
              final groups = <String, Map<String, dynamic>>{};
              for (final op in queue.operations) {
                groups.putIfAbsent(
                    (op['body'] as Map)['taskId'] as String, () => op);
              }
              return Scaffold(
                  appBar: AppBar(title: Text(t('待同步操作', 'Pending changes'))),
                  body: ListView(padding: AppSpacing.pageInsets, children: [
                    Text(t('联网后自动同步。有冲突的操作会暂停，保留本机操作供你核对，不覆盖家人的修改。',
                        'Changes sync when online. Conflicts pause for review without overwriting another family member.')),
                    TextButton(
                        onPressed: () => refreshQuietly(),
                        child: Text(t('立即重试同步', 'Retry sync now'))),
                    if (groups.isEmpty) Text(t('全部已同步', 'All changes synced')),
                    for (final entry in groups.entries)
                      Card(
                          child: ListTile(
                        title: Text(entry.value['title'] as String? ?? ''),
                        subtitle: Text([
                          for (final op in queue.operations.where((op) =>
                              (op['body'] as Map)['taskId'] == entry.key))
                            syncAction(op['body'] as Map),
                          if (entry.value['error'] == null)
                            t('等待联网同步', 'Waiting to sync')
                          else
                            syncReason(entry.value['error'] as String),
                        ].join('\n')),
                        trailing: TextButton(
                          onPressed: busy || syncing
                              ? null
                              : () async {
                                  if (!await confirm(
                                      t('放弃此事项的待同步修改？',
                                          'Discard pending changes for this task?'),
                                      t('此事项尚未同步的本机操作会被移除，服务端记录保留。',
                                          'Pending local changes for this task are removed. Server records are kept.'))) {
                                    return;
                                  }
                                  await queue.discard(entry.key);
                                  if (mounted) {
                                    updateUi(() => data = queue.snapshot);
                                    await syncReminders();
                                    await refreshQuietly();
                                  }
                                },
                          child: Text(t('放弃本机修改', 'Discard local changes')),
                        ),
                      )),
                  ]));
            })));
  }

  final _photoLoads = <String>{};
  final _photoFailures = <String>{};
  String photoKey(Map<String, dynamic> pet) =>
      '${widget.api.token}:${pet['id']}:${pet['photoRevision']}';

  void loadPhotosInBackground({bool retry = false}) {
    if (retry) _photoFailures.clear();
    for (final pet in pets) {
      final key = photoKey(pet);
      if (pet['photosPending'] != true ||
          _photoLoads.contains(key) ||
          _photoFailures.contains(key)) {
        continue;
      }
      unawaited(loadPhoto(pet));
    }
  }

  Future<bool> loadPhoto(Map<String, dynamic> pet) async {
    final key = photoKey(pet);
    if (!_photoLoads.add(key)) return false;
    final session = widget.api.token;
    try {
      final photos = await widget.api.loadPetPhotos(pet);
      if (!mounted || session != widget.api.token) return false;
      final current = pets
          .where((p) =>
              p['id'] == pet['id'] &&
              p['photoRevision'] == pet['photoRevision'])
          .firstOrNull;
      if (current == null) return false;
      updateUi(() {
        data!['pets'] = pets
            .map((p) => p['id'] == pet['id']
                ? {
                    ...p,
                    'photos': photos['photos'],
                    'photoData': photos['photoData'],
                    'photosPending': false
                  }
                : p)
            .toList();
        _photoFailures.remove(key);
      });
      return true;
    } catch (_) {
      if (mounted && session == widget.api.token) {
        updateUi(() => _photoFailures.add(key));
      }
      return false;
    } finally {
      _photoLoads.remove(key);
      if (mounted) updateUi(() {});
    }
  }

  Future<void> restore() async {
    try {
      await widget.api.restore();
      if (widget.api.token != null) data = await widget.api.dashboard();
    } on ApiError catch (e) {
      if (e.status == 401) {
        await widget.api.clearSession(preservePending: true);
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
      loadPhotosInBackground();
      unawaited(startPush());
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
      final result = Map<String, dynamic>.from(
          await widget.api.request('GET', '/tasks/$id') as Map);
      final task = Map<String, dynamic>.from(result['task'] as Map);
      if (!mounted) return;
      updateUi(() {
        tab = 0;
        selectedPetId = task['petId'] as String;
      });
      mergeCare(result);
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
    push.dispose();
    widget.api.offlineCare.removeListener(offlineChanged);
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

  Future<Map<String, dynamic>> loadDashboard() async {
    final next = await widget.api.dashboard();
    final loaded = (next['tasks'] as List).cast<Map>();
    final ids = loaded.map((task) => task['id']).toSet();
    next['tasks'] = [
      ...loaded,
      ...tasks.where((task) =>
          detailTaskIds.containsKey(task['id']) && !ids.contains(task['id']))
    ];
    return next;
  }

  void mergeCare(Map<String, dynamic> result) {
    final task = Map<String, dynamic>.from((result['task'] ?? result) as Map);
    final events = (result['events'] as List? ?? []).cast<Map>();
    final eventIds = events.map((event) => event['id']).toSet();
    updateUi(() {
      data?['tasks'] = [
        ...tasks.where((item) => item['id'] != task['id']),
        task
      ];
      data?['history'] = [
        ...events,
        ...(data?['history'] as List? ?? [])
            .where((event) => !eventIds.contains(event['id']))
      ];
      if (result['reminderTasks'] is List) {
        data?['reminderTasks'] = result['reminderTasks'];
      } else if (data?['reminderTasks'] is List) {
        data!['reminderTasks'] = [
          ...(data!['reminderTasks'] as List)
              .where((item) => item['id'] != task['id']),
          task
        ];
      }
    });
  }

  Future<bool> mutateCare(String key, String path, Map<String, dynamic> body,
      {String method = 'PATCH'}) async {
    if (busy || submittingTasks.contains(key)) return false;
    final previous = taskWrites.values.map((write) => write.future).toList();
    final write = Completer<void>();
    taskWrites[key] = write;
    updateUi(() => submittingTasks.add(key));
    try {
      await syncDone?.future;
      await Future.wait(previous);
      if (!mounted) return false;
      final task = tasks.where((v) => v['id'] == key).firstOrNull;
      final action = path.endsWith('/schedule') || path.endsWith('/time')
          ? 'RESCHEDULE'
          : path.endsWith('/assignment')
              ? 'ASSIGN'
              : body['action'] == 'SKIPPED'
                  ? 'SKIP'
                  : 'CANCEL';
      final result = task == null
          ? await widget.api.request(method, path, body)
          : await widget.api.writeCareTask(task, action, method, path, body);
      if (!mounted) return false;
      mergeCare(Map<String, dynamic>.from(result as Map));
      await syncReminders();
      return true;
    } finally {
      taskWrites.remove(key);
      write.complete();
      if (mounted) updateUi(() => submittingTasks.remove(key));
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
          if (!widget.api.offlineCare.offline) lastSyncedAt = DateTime.now();
          accessExpired = false;
          error = null;
        });
        loadPhotosInBackground();
        unawaited(startPush());
        await syncReminders();
      }
    } on ApiError catch (e) {
      if (e.status == 401) {
        await widget.api.clearSession(preservePending: true);
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
        unawaited(startPush());
        if (pendingNotificationTap) openNotificationTask();
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
      if (granted) unawaited(startPush());
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
      if (const {
        'SYNC_PENDING',
        'SYNC_CONFLICT',
        'SYNC_REFRESH_REQUIRED',
        'HOUSEHOLD_CHANGED',
        'DEPENDENCY_MISSING',
        'OPERATION_REUSED',
        'SYNC_QUEUE_FULL'
      }.contains(e.code)) {
        return t('有待同步或冲突的本机操作，请在待同步操作中查看。',
            'Review pending changes or conflicts in Pending changes.');
      }
      if (e.code == 'ACCESS_EXPIRED') {
        return t('临时照护权限已到期，请联系家庭管理员续期。',
            'Your access has expired. Ask a household admin to renew it.');
      }
      if (e.code == 'PERMISSION_DENIED') {
        return t('当前角色没有此操作权限，请联系家庭管理员。',
            'Your role cannot perform this action. Contact a household admin.');
      }
      if (e.code == 'USE_LEAVE_HOUSEHOLD') {
        return t('请使用退出家庭；最后一位管理员需先移交管理权。',
            'Use Leave household. The last administrator must first transfer administration.');
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
      if (e.code == 'SUBJECT_OWNER_HAS_PROFILES') {
        return t('请先删除你创建的家人照护档案，再退出或移除成员。',
            'Remove the human profiles created by this member before leaving or removing them.');
      }
      if (e.code == 'SUBJECT_ACCESS_DENIED' ||
          e.code == 'SUBJECT_CONSENT_REVOKED') {
        return t('该照护对象未授权访问或授权已撤回，请刷新。',
            'Access is not granted or was revoked. Refresh the app.');
      }
      if (e.code == 'SUBJECT_CONSENT_REQUIRED') {
        return t('请确认已获得保存资料的必要授权。',
            'Confirm authorization to store this information.');
      }
      if (e.code == 'INVALID_SUBJECT_SCENARIO') {
        return t('请选择有效的家人阶段和至少一种照护场景。',
            'Choose a valid life stage and at least one care scenario.');
      }
      if (e.code == 'INVALID_SUBJECT_CARE_TYPE') {
        return t('请选择适用于该照护对象的类型。',
            'Choose a care type available for this profile.');
      }
      if (e.code == 'MEDICATION_REQUIRES_LOG') {
        return t('用药请通过专门的用药记录填写实际结果。',
            'Use the medication record to enter the actual outcome.');
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
          if (!widget.api.offlineCare.offline) lastSyncedAt = DateTime.now();
          accessExpired = false;
          error = null;
        });
        loadPhotosInBackground();
        unawaited(startPush());
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
        await widget.api.clearSession(preservePending: true);
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
                                  child: Column(children: [
                                    if (widget.api.offlineCare.pendingCount >
                                            0 ||
                                        widget.api.offlineCare.offline)
                                      MaterialBanner(
                                        content: Text(t(
                                            widget.api.offlineCare.offline
                                                ? '当前离线 · ${widget.api.offlineCare.pendingCount} 项待同步'
                                                : '${widget.api.offlineCare.pendingCount} 项待同步',
                                            '${widget.api.offlineCare.offline ? 'Offline · ' : ''}${widget.api.offlineCare.pendingCount} changes waiting to sync')),
                                        actions: [
                                          TextButton(
                                              onPressed: openSyncQueue,
                                              child: Text(t('查看', 'Review')))
                                        ],
                                      ),
                                    if (pushError != null)
                                      TextButton(
                                          onPressed: startPush,
                                          child: Text(t('远程同步连接失败，点击重试',
                                              'Remote sync unavailable. Retry'))),
                                    Expanded(
                                        child: RefreshIndicator(
                                      key: ValueKey(tab),
                                      onRefresh: () => perform(() async {}),
                                      child: tab == 0
                                          ? careScrollView()
                                          : ListView(
                                              key: PageStorageKey(
                                                  'home-tab-$tab'),
                                              physics:
                                                  const AlwaysScrollableScrollPhysics(),
                                              padding: AppSpacing.pageInsets,
                                              children: tab == 1
                                                  ? petView()
                                                  : familyView(),
                                            ),
                                    )),
                                  ]),
                                ),
                        ),
                        if (data != null &&
                            pets.any((p) =>
                                p['photosPending'] == true &&
                                _photoFailures.contains(photoKey(p))))
                          Positioned(
                            bottom: 8,
                            left: 12,
                            right: 12,
                            child: Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(t('照片加载失败，其他功能可正常使用',
                                          'Photos unavailable. Other features still work.'))),
                                  TextButton(
                                      onPressed: () {
                                        updateUi(() => _photoFailures.clear());
                                        loadPhotosInBackground(retry: true);
                                      },
                                      child: Text(t('重试照片', 'Retry photos'))),
                                ]),
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
                  label: t('照护对象', 'Profiles'),
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
