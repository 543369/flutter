import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'pet_cover.dart';
import 'pet_profile.dart';

/// A pet's photos, independent of the selected-pet menu. Manual paging keeps
/// the image still while a person is reading the care information over it.
class PetPhotoCarousel extends StatefulWidget {
  const PetPhotoCarousel(
      {super.key,
      required this.pet,
      this.overlay = const [],
      this.indicatorBottom = 12,
      this.openPhotos = false});
  final Map<String, dynamic> pet;
  final List<Widget> overlay;
  final double indicatorBottom;
  final bool openPhotos;
  @override
  State<PetPhotoCarousel> createState() => _PetPhotoCarouselState();
}

class _PetPhotoCarouselState extends State<PetPhotoCarousel> {
  final controller = PageController();
  int current = 0;
  double dragDistance = 0;
  late List<String> photos = petPhotos(widget.pet);

  @override
  void didUpdateWidget(covariant PetPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = petPhotos(widget.pet);
    if (oldWidget.pet['id'] != widget.pet['id'] || !listEquals(photos, next)) {
      photos = next;
      current = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return GestureDetector(
        // Overlaid text is a sibling of PageView; also accept swipes begun there.
        onHorizontalDragStart:
            photos.length > 1 ? (_) => dragDistance = 0 : null,
        onHorizontalDragUpdate: photos.length > 1
            ? (details) => dragDistance += details.primaryDelta ?? 0
            : null,
        onHorizontalDragEnd: photos.length > 1
            ? (details) {
                if (!controller.hasClients || dragDistance.abs() < 30) return;
                final next = (current + (dragDistance < 0 ? 1 : -1))
                    .clamp(0, photos.length - 1);
                controller.animateToPage(next,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut);
              }
            : null,
        child: Stack(fit: StackFit.expand, children: [
          if (photos.isEmpty)
            PetCover(pet: widget.pet)
          else
            PageView.builder(
              key: const ValueKey('pet-photo-pages'),
              controller: controller,
              itemCount: photos.length,
              onPageChanged: (index) => setState(() => current = index),
              itemBuilder: (context, index) => Semantics(
                label: chinese
                    ? '宠物照片 ${index + 1}/${photos.length}'
                    : 'Pet photo ${index + 1}/${photos.length}',
                child: GestureDetector(
                  onTap: widget.openPhotos
                      ? () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                    backgroundColor: Colors.black,
                                    appBar: AppBar(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white),
                                    body: Center(
                                        child: InteractiveViewer(
                                            maxScale: 5,
                                            child: _FullPhoto(
                                                data: photos[index]))),
                                  )))
                      : null,
                  child: PetCover(pet: {
                    ...widget.pet,
                    'photos': [photos[index]]
                  }),
                ),
              ),
            ),
          ...widget.overlay,
          if (photos.length > 1)
            Positioned(
                left: 0,
                right: 0,
                bottom: widget.indicatorBottom,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var index = 0; index < photos.length; index++)
                    Semantics(
                        selected: current == index,
                        child: IconButton(
                          key: ValueKey('pet-photo-dot-$index'),
                          tooltip: chinese
                              ? '第 ${index + 1} 张照片，共 ${photos.length} 张'
                              : 'Photo ${index + 1} of ${photos.length}',
                          constraints: const BoxConstraints.tightFor(
                              width: 32, height: 32),
                          padding: EdgeInsets.zero,
                          onPressed: () => controller.animateToPage(index,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut),
                          icon: Icon(Icons.circle,
                              size: current == index ? 9 : 7,
                              color: current == index
                                  ? const Color(0xffdf6338)
                                  : const Color(0xffd9ccb6)),
                        )),
                ])),
        ]));
  }
}

class _FullPhoto extends StatelessWidget {
  const _FullPhoto({required this.data});
  final String data;
  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.broken_image_outlined, color: Colors.white);
    try {
      return Image.memory(base64Decode(data),
          fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback);
    } catch (_) {
      return fallback;
    }
  }
}
