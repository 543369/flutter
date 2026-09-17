import '../../core/images/photo_cache.dart';
import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../app/home_shell.dart';
import '../../core/widgets/profile_dialog.dart';
import 'pet_module.dart';
import '../benefits/benefits_page.dart';

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class MemoryPhoto extends StatelessWidget {
  const MemoryPhoto({super.key, required this.data, this.fit = BoxFit.cover});
  final String data;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => const ColoredBox(
        color: Color(0xfff4ece4),
        child: Center(child: Icon(Icons.image_not_supported_outlined)));
    try {
      return Image.memory(PhotoCache.shared.decode(data),
          fit: fit, errorBuilder: (_, __, ___) => fallback());
    } catch (_) {
      return fallback();
    }
  }
}

class PetMemoriesPage extends StatefulWidget {
  const PetMemoriesPage({super.key, required this.home, required this.petId});
  final CareHomeState home;
  final String petId;
  @override
  State<PetMemoriesPage> createState() => _PetMemoriesPageState();
}

class _PetMemoriesPageState extends State<PetMemoriesPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = false, hasMore = false;
  int total = 0;
  String? error;
  String t(String zh, String en) => widget.home.t(zh, en);
  String get path => '/pets/${widget.petId}/memories';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.home.widget.api
          .request('GET', '$path?offset=${more ? items.length : 0}');
      if (!mounted) return;
      setState(() {
        final next = (result['items'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        items = more ? [...items, ...next] : next;
        total = result['total'] as int;
        hasMore = result['hasMore'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(String id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MemoryDetailPage(
            home: widget.home, petId: widget.petId, memoryId: id)));
    if (mounted) await load();
  }

  Future<void> create() async {
    final id = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MemoryEditor(home: widget.home, petId: widget.petId));
    if (id != null && mounted) {
      await widget.home.refreshQuietly();
      if (mounted) await open(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet =
        widget.home.pets.where((p) => p['id'] == widget.petId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(t('回忆录', 'Memories')), actions: [
        IconButton(
            tooltip: t('导出回忆录', 'Export memory book'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => BenefitsPage(
                    home: widget.home, initialPetId: widget.petId)))),
      ]),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
                padding: AppSpacing.dialogInsets,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                      padding: const EdgeInsets.all(AppSpacing.section),
                      decoration: BoxDecoration(
                          color: const Color(0xffffeadf),
                          borderRadius: BorderRadius.circular(26)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_stories_outlined,
                                color: Color(0xffbb6046), size: 32),
                            const SizedBox(height: AppSpacing.item),
                            Text(
                                t('和${pet?['name'] ?? '你'}的故事',
                                    'Our story with ${pet?['name'] ?? 'you'}'),
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: AppSpacing.inline),
                            Text(t('一张照片，一件小事，都是值得珍藏的日子。',
                                'A photo, a small moment, a day worth remembering.')),
                            const SizedBox(height: AppSpacing.content),
                            FilledButton.icon(
                                key: const ValueKey('create-memory'),
                                onPressed: create,
                                icon: const Icon(Icons.add_rounded),
                                label: Text(t('写一篇回忆', 'Write a memory'))),
                          ])),
                  const SizedBox(height: AppSpacing.section),
                  Text(t('珍藏的 $total 个瞬间', '$total moments to keep'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.content),
                  if (loading && items.isEmpty)
                    const Center(child: CircularProgressIndicator()),
                  if (error != null) ...[
                    Text(error!),
                    TextButton(
                        onPressed: () => load(more: items.isNotEmpty),
                        child: Text(t('重试', 'Retry')))
                  ],
                  if (!loading && error == null && items.isEmpty)
                    widget.home.empty(
                        t('第一篇故事，留给今天', 'Let today be the first story'),
                        t('第一次见面、一起散步，或只是它睡着的样子。',
                            'The first hello, a walk together, or a sleepy afternoon.'),
                        Icons.favorite_border_rounded),
                  for (final item in items)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Material(
                          color: const Color(0xfffaf1e7),
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                              onTap: () => open(item['id'] as String),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item['coverData'] != null)
                                      AspectRatio(
                                          aspectRatio: 1.65,
                                          child: MemoryPhoto(
                                              data:
                                                  item['coverData'] as String)),
                                    Padding(
                                        padding: AppSpacing.cardInsets,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(item['happenedOn'] as String,
                                                  style: const TextStyle(
                                                      color: Color(0xffa05e46),
                                                      fontSize: 12)),
                                              const SizedBox(
                                                  height: AppSpacing.inline),
                                              Text(item['title'] as String,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge),
                                              const SizedBox(
                                                  height: AppSpacing.inline),
                                              Text(item['story'] as String,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              const SizedBox(
                                                  height: AppSpacing.item),
                                              Row(children: [
                                                Expanded(
                                                    child: Text(
                                                        item['author']
                                                                as String? ??
                                                            t('家人',
                                                                'Family member'),
                                                        style: const TextStyle(
                                                            fontSize: 12))),
                                                if ((item['photoCount']
                                                            as int? ??
                                                        0) >
                                                    0) ...[
                                                  const Icon(
                                                      Icons
                                                          .photo_library_outlined,
                                                      size: 16),
                                                  const SizedBox(
                                                      width: AppSpacing.tight),
                                                  Text('${item['photoCount']}')
                                                ],
                                                const SizedBox(
                                                    width: AppSpacing.item),
                                                const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 18)
                                              ]),
                                            ])),
                                  ])),
                        )),
                  if (hasMore)
                    TextButton(
                        onPressed: loading ? null : () => load(more: true),
                        child: Text(t('查看更多回忆', 'More memories'))),
                ])),
      ))),
    );
  }
}

class MemoryEditor extends StatefulWidget {
  const MemoryEditor(
      {super.key,
      required this.home,
      required this.petId,
      this.memory,
      this.photoPicker});
  final CareHomeState home;
  final String petId;
  final Map<String, dynamic>? memory;
  final Future<String?> Function()? photoPicker;
  @override
  State<MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends State<MemoryEditor> {
  late final title =
      TextEditingController(text: widget.memory?['title'] as String?);
  late final story =
      TextEditingController(text: widget.memory?['story'] as String?);
  late DateTime date =
      DateTime.tryParse(widget.memory?['happenedOn'] as String? ?? '') ??
          DateTime.now();
  late List<String> photos =
      List<String>.from(widget.memory?['photos'] as List? ?? []);
  bool saving = false, picking = false;
  String? error;
  String t(String zh, String en) => widget.home.t(zh, en);
  @override
  void dispose() {
    title.dispose();
    story.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    if (photos.length >= 6 || picking) return;
    setState(() => picking = true);
    try {
      final photo = await (widget.photoPicker ?? widget.home.pickPetPhoto)();
      if (mounted && photo != null) setState(() => photos.add(photo));
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (saving ||
        picking ||
        title.text.trim().isEmpty ||
        story.text.trim().isEmpty) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.home.widget.api.request(
          widget.memory == null ? 'POST' : 'PATCH',
          '/pets/${widget.petId}/memories${widget.memory == null ? '' : '/${widget.memory!['id']}'}',
          {
            'title': title.text.trim(),
            'story': story.text.trim(),
            'happenedOn': _day(date),
            'photos': photos,
          });
      if (mounted) Navigator.of(context).pop(result['id'] as String);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = widget.home.message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ProfileDialog(
        title: widget.memory == null
            ? t('写一篇回忆', 'Write a memory')
            : t('编辑回忆', 'Edit memory'),
        subtitle: t('把故事和照片，留在它的专属回忆录里。',
            'Keep the story and photos in their own memory book.'),
        saveLabel: t('保存回忆', 'Save memory'),
        cancelLabel: t('取消', 'Cancel'),
        saving: saving || picking,
        error: error,
        onSave: title.text.trim().isEmpty || story.text.trim().isEmpty
            ? null
            : save,
        children: [
          TextField(
              key: const ValueKey('memory-title'),
              controller: title,
              maxLength: 120,
              enabled: !saving,
              decoration: InputDecoration(
                  labelText: t('给回忆起个名字', 'Title'),
                  hintText: t('第一次一起去海边', 'Our first trip to the beach')),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.item),
          OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now());
                      if (selected != null && mounted) {
                        setState(() => date = selected);
                      }
                    },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(_day(date))),
          const SizedBox(height: AppSpacing.content),
          TextField(
              key: const ValueKey('memory-story'),
              controller: story,
              minLines: 5,
              maxLines: 10,
              maxLength: 5000,
              enabled: !saving,
              decoration: InputDecoration(
                  labelText: t('这一天的故事', 'The story'),
                  hintText: t('发生了什么？那一刻的心情如何？',
                      'What happened? How did that moment feel?')),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.inline),
          Text(t('照片 · ${photos.length}/6', 'Photos · ${photos.length}/6'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.inline),
          Wrap(
              spacing: AppSpacing.inline,
              runSpacing: AppSpacing.inline,
              children: [
                for (final entry in photos.indexed)
                  SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(fit: StackFit.expand, children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: MemoryPhoto(data: entry.$2)),
                        Align(
                            alignment: Alignment.topRight,
                            child: IconButton.filledTonal(
                                tooltip: t('移除照片', 'Remove photo'),
                                constraints: const BoxConstraints.tightFor(
                                    width: 30, height: 30),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded, size: 17),
                                onPressed: saving
                                    ? null
                                    : () => setState(
                                        () => photos.removeAt(entry.$1))))
                      ])),
              ]),
          const SizedBox(height: AppSpacing.item),
          const SizedBox(height: AppSpacing.item),
          OutlinedButton.icon(
              onPressed: saving || picking || photos.length >= 6 ? null : pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(t('添加照片', 'Add photo'))),
          const SizedBox(height: AppSpacing.inline),
          Text(t('只有你的家庭成员可以查看和编辑这些回忆。',
              'Only your household can view and edit these memories.')),
        ],
      );
}

class MemoryDetailPage extends StatefulWidget {
  const MemoryDetailPage(
      {super.key,
      required this.home,
      required this.petId,
      required this.memoryId});
  final CareHomeState home;
  final String petId, memoryId;
  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  Map<String, dynamic>? memory;
  bool loading = true;
  String? error;
  String t(String zh, String en) => widget.home.t(zh, en);
  String get path => '/pets/${widget.petId}/memories/${widget.memoryId}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.home.widget.api.request('GET', path);
      if (mounted) {
        setState(() => memory = Map<String, dynamic>.from(result as Map));
      }
    } catch (e) {
      if (mounted) setState(() => error = widget.home.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit() async {
    final saved = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MemoryEditor(
            home: widget.home, petId: widget.petId, memory: memory));
    if (saved != null && mounted) await load();
  }

  Future<void> delete() async {
    if (!await widget.home.confirm(
        t('删除这篇回忆？', 'Delete this memory?'),
        t('这篇故事及照片将从家庭回忆录中删除。',
            'This story and its photos will be deleted from your household’s memories.'))) {
      return;
    }
    if (!mounted) return;
    setState(() => loading = true);
    try {
      await widget.home.widget.api.request('DELETE', path);
      await widget.home.refreshQuietly();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = widget.home.message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('回忆详情', 'Memory details')), actions: [
          if (memory != null)
            IconButton(
                onPressed: loading ? null : edit,
                tooltip: t('编辑回忆', 'Edit memory'),
                icon: const Icon(Icons.edit_outlined)),
        ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: AppSpacing.pageInsets, children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(error!),
              TextButton(onPressed: load, child: Text(t('重试', 'Retry')))
            ],
            if (memory != null) ...[
              Text(memory!['happenedOn'] as String,
                  style: const TextStyle(color: Color(0xffb15f44))),
              const SizedBox(height: AppSpacing.item),
              Text(memory!['title'] as String,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.item),
              Text(t('由 ${memory!['author'] ?? '家人'} 记录',
                  'Recorded by ${memory!['author'] ?? 'a family member'}')),
              const SizedBox(height: AppSpacing.section),
              SelectableText(memory!['story'] as String,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.8)),
              const SizedBox(height: AppSpacing.section),
              for (final photo in memory!['photos'] as List)
                Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                    backgroundColor: Colors.black,
                                    appBar: AppBar(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white),
                                    body: Center(
                                        child: InteractiveViewer(
                                            minScale: 1,
                                            maxScale: 5,
                                            child: MemoryPhoto(
                                                data: photo,
                                                fit: BoxFit.contain)))))),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child:
                                AspectRatio(aspectRatio: 1.2, child: MemoryPhoto(data: photo as String))))),
              const SizedBox(height: AppSpacing.item),
              Text(
                  t('创建于 ${widget.home.dateLabel(DateTime.parse(memory!['createdAt'] as String).toLocal())}',
                      'Created ${widget.home.dateLabel(DateTime.parse(memory!['createdAt'] as String).toLocal())}'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.section),
              TextButton.icon(
                  onPressed: loading ? null : delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(t('删除回忆', 'Delete memory'))),
            ],
          ]),
        ))),
      );
}
