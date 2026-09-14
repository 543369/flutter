import 'dart:convert';
import 'package:flutter/material.dart';

class PetCover extends StatelessWidget {
  const PetCover({super.key, required this.pet});
  final Map<String, dynamic> pet;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => pet['species'] == 'other'
        ? const ColoredBox(
            color: Color(0xffffefcc),
            child: Center(
                child: Icon(Icons.pets_rounded,
                    size: 64, color: Color(0xff97664b))))
        : Image.asset(
            pet['species'] == 'cat'
                ? 'assets/images/petcare_cat_cover.jpg'
                : 'assets/images/petcare_shiba_hero.png',
            fit: BoxFit.cover,
            alignment: pet['species'] == 'cat'
                ? Alignment.center
                : Alignment.centerRight);
    final value = pet['photoData'] as String?;
    if (value == null || value.isEmpty) return fallback();
    try {
      return Image.memory(base64Decode(value),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback());
    } catch (_) {
      return fallback();
    }
  }
}
