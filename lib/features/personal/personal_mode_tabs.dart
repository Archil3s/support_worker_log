import 'package:flutter/material.dart';

import '../trips/trips_screen.dart';
import 'personal_screen.dart';

class PersonalModeTabs extends StatelessWidget {
  const PersonalModeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF151B29),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF34405F)),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF20283B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4F8DF7)),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF8396C7),
              labelStyle: const TextStyle(fontWeight: FontWeight.w900),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(
                  icon: Icon(Icons.person_outline_rounded, size: 19),
                  text: 'Personal',
                ),
                Tab(
                  icon: Icon(Icons.luggage_outlined, size: 19),
                  text: 'Trips',
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                PersonalScreen(),
                TripsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
