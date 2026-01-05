import 'package:flutter/material.dart';
import 'package:muzo/services/ytm_home.dart';
import 'package:muzo/widgets/home_item_widget.dart';

class HomeSectionWidget extends StatelessWidget {
  final HomeSection section;

  const HomeSectionWidget({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    if (section.items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        SizedBox(
          height: 240, // Increased to prevent overflow (160 image + text)
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              return HomeItemWidget(item: section.items[index]);
            },
          ),
        ),
      ],
    );
  }
}
