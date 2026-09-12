import 'package:flutter/material.dart';
import 'package:petcare/api.dart';
import 'package:petcare/main.dart';
import 'package:petcare/reminders.dart';

class PreviewApi extends CareApi {
  PreviewApi() {
    token = 'design-preview';
  }

  late List<Map<String, dynamic>> previewTasks = _tasks();

  static String _at(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute)
        .toUtc()
        .toIso8601String();
  }

  static List<Map<String, dynamic>> _tasks() => [
        {
          'id': 'meal',
          'petId': 'doubao',
          'petName': '豆包',
          'title': '午间喂食',
          'completed': false,
          'dueAt': _at(12, 0),
          'planId': 'daily-meal'
        },
        {
          'id': 'walk',
          'petId': 'doubao',
          'petName': '豆包',
          'title': '出门散步',
          'completed': false,
          'dueAt': _at(18, 30),
          'planId': 'daily-walk'
        },
        {
          'id': 'breakfast',
          'petId': 'doubao',
          'petName': '豆包',
          'title': '早餐',
          'completed': true,
          'dueAt': _at(8, 10),
          'planId': 'daily-breakfast'
        },
        {
          'id': 'water',
          'petId': 'doubao',
          'petName': '豆包',
          'title': '换水',
          'completed': true,
          'dueAt': _at(8, 25),
          'planId': 'daily-water'
        },
      ];

  @override
  Future<void> restore() async {}

  @override
  Future<Map<String, dynamic>> dashboard() async => {
        'pets': [
          {'id': 'doubao', 'name': '豆包', 'species': 'dog'}
        ],
        'tasks': previewTasks,
        'history': [
          {
            'id': 'h1',
            'taskId': 'breakfast',
            'action': 'COMPLETED',
            'at': _at(8, 10),
            'actor': '妈妈',
            'title': '妈妈喂过早餐了',
            'petName': '豆包'
          },
          {
            'id': 'h2',
            'taskId': 'water',
            'action': 'COMPLETED',
            'at': _at(8, 25),
            'actor': '年糕',
            'title': '换了新鲜的水',
            'petName': '年糕'
          }
        ],
        'plans': [],
        'me': '你',
        'members': 2,
      };

  @override
  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (method == 'PATCH' && path.startsWith('/tasks/')) {
      final id = path.substring('/tasks/'.length);
      previewTasks = previewTasks
          .map((task) => task['id'] == id
              ? {...task, 'completed': body?['completed'] == true}
              : task)
          .toList();
      return body;
    }
    return null;
  }
}

class PreviewReminders extends ReminderService {
  @override
  Future<void> initialize(VoidCallback onTap) async {
    ready = true;
  }

  @override
  Future<void> sync(List<Map<String, dynamic>> tasks,
      {required bool chinese}) async {}

  @override
  Future<String> deviceZone() async => 'Asia/Shanghai';
}

void main() => runApp(PetCareApp(
      api: PreviewApi(),
      reminders: PreviewReminders(),
    ));
