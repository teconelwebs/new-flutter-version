import 'package:flutter/material.dart';

class ProductItem {
  const ProductItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.rating,
    required this.color,
    this.imageUrl = '',
    this.slug = '',
    this.brand = '',
    this.durationMinutes = 0,
    this.videoUrl,
    this.videoLink,
  });

  final String id;
  final String title;
  final String subtitle;
  final double price;
  final double rating;
  final Color color;
  final String imageUrl;
  final String slug;
  final String brand;
  final int durationMinutes;
  final String? videoUrl;
  final String? videoLink;
}
