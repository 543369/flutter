import 'package:flutter/material.dart';
import 'package:petcare/api.dart';
import 'package:petcare/main.dart';
import 'package:petcare/reminders.dart';

class PreviewApi extends CareApi {
  PreviewApi() {
    token = 'design-preview';
  }

  final previewEvents = <Map<String, dynamic>>[];
  late List<Map<String, dynamic>> previewTasks = _tasks();
  final health = <Map<String, dynamic>>[
    {
      'id': 'weight',
      'kind': 'WEIGHT',
      'title': '本周体重',
      'notes': '精神和食欲都不错。',
      'happenedOn': '2026-09-16',
      'weightKg': 8.2,
      'folder': '',
      'photos': <String>[],
      'createdAt': '2026-09-16T08:00:00Z',
      'updatedAt': '2026-09-16T08:00:00Z',
    },
    {
      'id': 'visit',
      'kind': 'VISIT',
      'title': '年度体检',
      'notes': '检查记录已整理，日常继续观察。',
      'happenedOn': '2026-09-10',
      'weightKg': null,
      'folder': '',
      'photos': <String>[],
      'createdAt': '2026-09-10T08:00:00Z',
      'updatedAt': '2026-09-10T08:00:00Z',
    },
  ];

  static String _at(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).toUtc().toIso8601String();
  }

  static List<Map<String, dynamic>> _tasks() => [
        {
          'id': 'meal',
          'petId': 'doubao',
          'petName': '豆包',
          'title': '午间喂食',
          'careType': 'FEEDING',
          'completed': false,
          'dueAt': _at(12, 0),
          'planId': 'daily-meal',
        },
        {
          'id': 'walk',
          'petId': 'doubao',
          'petName': '豆包',
          'title': '出门散步',
          'careType': 'WALK',
          'completed': false,
          'dueAt': _at(18, 30),
          'planId': 'daily-walk',
        },
        {
          'id': 'breakfast',
          'petId': 'doubao',
          'petName': '豆包',
          'title': '早餐',
          'careType': 'FEEDING',
          'completed': true,
          'dueAt': _at(8, 10),
          'planId': 'daily-breakfast',
        },
        {
          'id': 'water',
          'petId': 'doubao',
          'petName': '豆包',
          'title': '换水',
          'careType': 'WATER',
          'completed': true,
          'dueAt': _at(8, 25),
          'planId': 'daily-water',
        },
      ];

  @override
  Future<void> restore() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
  }

  @override
  Future<Map<String, dynamic>> dashboard() async => {
        'pets': [
          {
            'id': 'doubao',
            'name': '豆包',
            'species': 'dog',
            'birthDate': '2023-04-12',
            'biography': '喜欢散步，也喜欢在你身边打盹。',
            'createdAt': '2026-01-01T00:00:00Z',
          },
          {
            'id': 'niangao',
            'name': '年糕',
            'species': 'cat',
            'birthDate': '2024-02-20',
            'biography': '午后的窗台是最喜欢的地方。',
          },
        ],
        'tasks': previewTasks.where((t) => t['cancelled'] != true).toList(),
        'history': [
          ...previewEvents,
          {
            'id': 'h1',
            'taskId': 'breakfast',
            'action': 'COMPLETED',
            'at': _at(8, 10),
            'actor': '妈妈',
            'title': '妈妈喂过早餐了',
            'petName': '豆包',
          },
          {
            'id': 'h2',
            'taskId': 'water',
            'action': 'COMPLETED',
            'at': _at(8, 25),
            'actor': '年糕',
            'title': '换了新鲜的水',
            'petName': '年糕',
          },
        ],
        'plans': [],
        'memberProfiles': [
          {'id': 'me', 'name': '你', 'isMe': true},
          {'id': 'mom', 'name': '妈妈', 'isMe': false},
        ],
        'me': '你',
        'members': 2,
      };

  @override
  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final uri = Uri.parse(path);
    final segments = uri.pathSegments;
    if (method == 'GET' && uri.path == '/tasks') {
      return {
        'items': previewTasks
            .where((t) =>
                t['cancelled'] != true &&
                t['petId'] == uri.queryParameters['petId'])
            .toList(),
        'hasMore': false
      };
    }
    if (method == 'GET' && uri.path == '/care-history') {
      final data = await dashboard();
      return {'items': data['history'], 'hasMore': false};
    }
    if (method == 'POST' && path == '/tasks') {
      final id = 'preview-${DateTime.now().microsecondsSinceEpoch}';
      final pets = (await dashboard())['pets'] as List;
      previewTasks.add({
        ...body!,
        'id': id,
        'completed': false,
        'petName': pets.firstWhere((p) => p['id'] == body['petId'])['name']
      });
      return {'id': id};
    }
    if (segments.length >= 2 && segments.first == 'tasks') {
      final task = previewTasks.firstWhere((t) => t['id'] == segments[1]);
      if (method == 'GET') return task;
      if (segments.last == 'time') {
        task['dueAt'] = body!['dueAt'];
      } else if (segments.last == 'dismiss') {
        task['cancelled'] = true;
      } else if (segments.last == 'assignment') {
        task['assignedTo'] = body!['memberId'];
      } else {
        task['completed'] = body!['completed'];
      }
      final event = {
        'id': 'event-${DateTime.now().microsecondsSinceEpoch}',
        'taskId': task['id'],
        'petId': task['petId'],
        'petName': task['petName'],
        'title': task['title'],
        'actor': '你',
        'at': DateTime.now().toUtc().toIso8601String(),
        'action': segments.last == 'time'
            ? 'RESCHEDULED'
            : body?['action'] ??
                (task['completed'] == true ? 'COMPLETED' : 'REOPENED')
      };
      previewEvents.insert(0, event);
      task['lastEvent'] = event;
      return task;
    }
    if ((method == 'POST' || method == 'PATCH') &&
        segments.length >= 3 &&
        segments[2] == 'health') {
      final id = segments.length == 4
          ? segments.last
          : 'health-${DateTime.now().microsecondsSinceEpoch}';
      health.removeWhere((r) => r['id'] == id);
      health.insert(0, {
        ...body!,
        'id': id,
        'createdAt': DateTime.now().toUtc().toIso8601String()
      });
      return {'id': id};
    }
    if (method == 'GET' && segments.length >= 3 && segments[2] == 'health') {
      if (segments.length == 3) {
        final kind = uri.queryParameters['kind'] ?? '';
        final items =
            health.where((r) => kind.isEmpty || r['kind'] == kind).toList();
        return {
          'items': items,
          'hasMore': false,
          'total': items.length,
          'advanced': false,
          'attachmentLimit': 2,
        };
      }
      return health.firstWhere((r) => r['id'] == segments.last);
    }
    if (method == 'GET' && path.contains('/memories?')) {
      return {'items': <Map<String, dynamic>>[], 'total': 0, 'hasMore': false};
    }
    if (method == 'GET' && path == '/profile') {
      return {
        'id': 'preview-user',
        'name': '你',
        'account': 'preview@example.com',
        'birthDate': null,
        'phone': null,
        'createdAt': '2026-01-01T00:00:00Z',
      };
    }
    if (method == 'GET' && path == '/benefits') {
      return {
        'tier': 'FREE',
        'usedBytes': 10485760,
        'limitBytes': 104857600,
        'baseLimitBytes': 104857600,
        'photoCount': 0,
        'billingEnabled': false,
        'canExport': false,
        'canReport': false,
      };
    }
    if (method == 'GET' && path == '/family/members') {
      return {
        'items': [
          {
            'id': 'me',
            'name': '你',
            'role': 'ADMIN',
            'isMe': true,
            'permissions': ['CARE', 'HEALTH', 'MEMORIES', 'PETS', 'REPORTS'],
          },
          {
            'id': 'mom',
            'name': '妈妈',
            'role': 'MEMBER',
            'isMe': false,
            'permissions': ['CARE', 'HEALTH', 'MEMORIES', 'PETS', 'REPORTS'],
          },
        ],
        'canManage': false,
        'advanced': false,
      };
    }
    if (method == 'GET' && path.startsWith('/family/weekly?')) {
      return {
        'advanced': false,
        'due': 14,
        'completed': 12,
        'missed': 2,
        'completionRate': 85.7,
        'unassigned': 0,
        'pets': [
          {'name': '豆包', 'due': 14, 'completed': 12, 'missed': 2},
        ],
        'members': [
          {'name': '你', 'assigned': 7, 'completed': 6},
          {'name': '妈妈', 'assigned': 7, 'completed': 6},
        ],
        'missedTasks': <Map<String, dynamic>>[],
        'trends': <Map<String, dynamic>>[],
      };
    }
    if (method == 'PATCH' && path.startsWith('/tasks/')) {
      final id = path.substring('/tasks/'.length);
      previewTasks = previewTasks
          .map(
            (task) => task['id'] == id
                ? {...task, 'completed': body?['completed'] == true}
                : task,
          )
          .toList();
      return body;
    }
    throw const ApiError(400, 'PREVIEW_ONLY');
  }
}

class PreviewReminders extends ReminderService {
  @override
  Future<bool> setEnabled(bool value) async {
    enabled = value;
    return value;
  }

  @override
  Future<void> initialize(ValueChanged<String?> onTap) async {
    ready = true;
  }

  @override
  Future<void> sync(
    List<Map<String, dynamic>> tasks, {
    required bool chinese,
  }) async {}

  @override
  Future<String> deviceZone() async => 'Asia/Shanghai';
}

void main() => runApp(
      PetCareApp(
        initialLocale: const Locale('zh'),
        api: PreviewApi(),
        reminders: PreviewReminders(),
      ),
    );
