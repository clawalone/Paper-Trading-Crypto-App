import 'package:flutter/material.dart';
import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:animated_list_plus/transitions.dart';

void main() {
  ImplicitlyAnimatedList<int>(
    items: [1, 2, 3],
    areItemsTheSame: (a, b) => a == b,
    itemBuilder: (context, animation, item, index) {
      return SizeFadeTransition(
        animation: animation,
        child: Text(item.toString()),
      );
    },
  );
}
