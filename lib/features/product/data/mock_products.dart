import 'package:flutter/material.dart';

import 'models/product_item.dart';

const List<ProductItem> kMockProducts = [
  ProductItem(
    id: '1',
    title: 'Fresh Apples',
    subtitle: '1kg | Farm Fresh',
    price: 149,
    rating: 4.7,
    color: Color(0xFFFFD9D9),
  ),
  ProductItem(
    id: '2',
    title: 'Almond Milk',
    subtitle: '500ml | Unsweetened',
    price: 79,
    rating: 4.4,
    color: Color(0xFFDDF4FF),
  ),
  ProductItem(
    id: '3',
    title: 'Organic Bread',
    subtitle: 'Multigrain | Soft',
    price: 69,
    rating: 4.6,
    color: Color(0xFFE8FFE1),
  ),
  ProductItem(
    id: '4',
    title: 'Cold Coffee',
    subtitle: '250ml | Chilled',
    price: 99,
    rating: 4.5,
    color: Color(0xFFFFF0CC),
  ),
  ProductItem(
    id: '5',
    title: 'Basmati Rice',
    subtitle: '5kg | Premium',
    price: 499,
    rating: 4.8,
    color: Color(0xFFF3E8FF),
  ),
  ProductItem(
    id: '6',
    title: 'Face Wash',
    subtitle: '100ml | Gentle',
    price: 199,
    rating: 4.3,
    color: Color(0xFFE7F7FF),
  ),
];
