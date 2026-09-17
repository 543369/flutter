import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import 'care_pages.dart';

class CareHistoryPage extends StatefulWidget {
  const CareHistoryPage({super.key, required this.home, required this.petId});
  final CareHomeState home;
  final String? petId;
  @override
  State<CareHistoryPage> createState() => _CareHistoryPageState();
}

class _CareHistoryPageState extends State<CareHistoryPage> {
  final items = <Map<String, dynamic>>[];
  String cursor = '';
  bool loading = false, more = true;
  String? error;
  String t(String z, String e) => widget.home.t(z, e);
  @override
  void initState() {
    super.initState();
    if (widget.petId == null) {
      more = false;
    } else {
      load(reset: true);
    }
  }

  Future<void> load({bool reset = false}) async {
    if (loading || widget.petId == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final path = Uri(path: '/care/history', queryParameters: {
        'petId': widget.petId!,
        if (!reset && cursor.isNotEmpty) 'cursor': cursor,
      });
      final result =
          await widget.home.widget.api.request('GET', path.toString());
      if (!mounted) return;
      setState(() {
        if (reset) items.clear();
        final ids = items.map((v) => v['id']).toSet();
        items.addAll((result['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .where((v) => !ids.contains(v['id'])));
        cursor = result['nextCursor'] as String;
        more = result['hasMore'] as bool;
      });
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(t('照护记录', 'Care history')),
            leading: IconButton(
                tooltip: t('返回今天', 'Back to today'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context))),
        body: RefreshIndicator(
            onRefresh: () => load(reset: true),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return Column(children: [
                    if (loading) const LinearProgressIndicator(),
                    if (error != null) Text(error!),
                    if (!loading && error == null && items.isEmpty)
                      Text(t('还没有照护记录', 'No care history yet')),
                    if (!loading && (more || error != null))
                      TextButton(
                          onPressed: () => load(),
                          child: Text(error != null
                              ? t('重试', 'Retry')
                              : t('加载更多', 'Load more'))),
                  ]);
                }
                final event = items[index];
                return Card(
                    child: ListTile(
                  title: Text(event['title'] as String),
                  subtitle: Text(
                      '${widget.home.eventAction(event)} · ${widget.home.dateLabel(DateTime.parse(event['at'] as String).toLocal())}\n${event['petName']} · ${event['actor'] ?? t('已退出的家人', 'Former member')}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.home.openRecordDetails(event),
                ));
              },
            )),
      );
}
