import 'package:flutter/material.dart';

import 'web_spacing.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tight = useTightWebSpacing(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF151B29),
        borderRadius: BorderRadius.circular(tight ? 14 : 22),
        border: Border.all(color: const Color(0xFF34405F)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: tight ? 12 : 22,
            offset: Offset(0, tight ? 4 : 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(tight ? 12 : 18),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: IconTheme.merge(
            data: const IconThemeData(color: Color(0xFF8396C7)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: tight ? 20 : 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F8DF7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    SizedBox(width: tight ? 8 : 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tight ? 10 : 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
