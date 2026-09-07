import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  static const _prefsKey = 'rhea_trips_mini_moo_2026_v1';

  static const _cream = Color(0xFFF5F0E7);
  static const _paper = Color(0xFFFFFDF9);
  static const _ink = Color(0xFF28231F);
  static const _muted = Color(0xFF756D64);
  static const _line = Color(0xFFDED3C5);
  static const _brown = Color(0xFF7B4B2E);
  static const _tan = Color(0xFFC99D69);
  static const _soft = Color(0xFFF1E6D8);
  static const _greenSoft = Color(0xFFEDF4E9);
  static const _greenInk = Color(0xFF3E563F);
  static const _warning = Color(0xFFFFF0DC);
  static const _warningInk = Color(0xFF68401F);

  final Set<String> _completed = <String>{};
  final _satHotelController = TextEditingController();
  final _satHotelAddressController = TextEditingController();
  final _notesController = TextEditingController();

  TimeOfDay _saturdayDeparture = const TimeOfDay(hour: 8, minute: 0);
  double _fuel = 130;
  double _saturdayStay = 180;
  double _food = 120;
  double _extras = 40;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _satHotelController.dispose();
    _satHotelAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final completed = (data['completed'] as List?)?.whereType<String>() ?? const <String>[];
        final departure = data['saturdayDeparture'] as String?;
        final parts = departure?.split(':');
        setState(() {
          _completed
            ..clear()
            ..addAll(completed);
          if (parts != null && parts.length == 2) {
            _saturdayDeparture = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 8,
              minute: int.tryParse(parts[1]) ?? 0,
            );
          }
          _fuel = (data['fuel'] as num?)?.toDouble() ?? 130;
          _saturdayStay = (data['saturdayStay'] as num?)?.toDouble() ?? 180;
          _food = (data['food'] as num?)?.toDouble() ?? 120;
          _extras = (data['extras'] as num?)?.toDouble() ?? 40;
          _satHotelController.text = data['satHotel'] as String? ?? '';
          _satHotelAddressController.text = data['satHotelAddress'] as String? ?? '';
          _notesController.text = data['notes'] as String? ?? '';
        });
      } catch (_) {
        // Keep defaults if an older/corrupt local value cannot be decoded.
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'completed': _completed.toList(),
        'saturdayDeparture':
            '${_saturdayDeparture.hour.toString().padLeft(2, '0')}:${_saturdayDeparture.minute.toString().padLeft(2, '0')}',
        'fuel': _fuel,
        'saturdayStay': _saturdayStay,
        'food': _food,
        'extras': _extras,
        'satHotel': _satHotelController.text,
        'satHotelAddress': _satHotelAddressController.text,
        'notes': _notesController.text,
      }),
    );
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() {
      if (value) {
        _completed.add(key);
      } else {
        _completed.remove(key);
      }
    });
    await _save();
  }

  Future<void> _pickDeparture() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _saturdayDeparture,
    );
    if (picked == null) return;
    setState(() => _saturdayDeparture = picked);
    await _save();
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  String _timeWithOffset(int minutes) {
    final base = _saturdayDeparture.hour * 60 + _saturdayDeparture.minute;
    final total = (base + minutes) % (24 * 60);
    final hour = total ~/ 60;
    final minute = total % 60;
    final suffix = hour >= 12 ? 'pm' : 'am';
    final twelveHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelveHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  String _formatMoney(double value) => '\$${value.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: _cream,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            _TripHero(onOpenAirbnb: () => _open(_airbnbUrl)),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              decoration: BoxDecoration(
                color: _paper,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: _brown,
                  borderRadius: BorderRadius.all(Radius.circular(13)),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: _muted,
                labelStyle: TextStyle(fontWeight: FontWeight.w900),
                tabs: [
                  Tab(text: 'Itinerary'),
                  Tab(text: 'Bookings'),
                  Tab(text: 'Budget'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildItinerary(),
                  _buildBookings(),
                  _buildBudget(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItinerary() {
    final completedStops = _itineraryKeys.where(_completed.contains).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _SummaryRow(
          items: const [
            _SummaryItem('3 days', '12–14 Sep 2026'),
            _SummaryItem('~309 km', 'Blenheim → Christchurch'),
            _SummaryItem('11:30 am', 'Mini Moo Sunday'),
          ],
        ),
        const SizedBox(height: 12),
        _ProgressCard(done: completedStops, total: _itineraryKeys.length),
        const SizedBox(height: 14),
        _SectionHeader(
          title: 'Saturday 12 September',
          subtitle: 'Blenheim → Kaikōura → Christchurch',
          trailing: OutlinedButton.icon(
            onPressed: _pickDeparture,
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text('Leave ${_formatTimeOfDay(_saturdayDeparture)}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brown,
              side: const BorderSide(color: _tan),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Notice(
          text:
              'Relaxed road-trip day. The Mini Moo encounter is on Sunday, so Saturday can stay flexible.',
        ),
        const SizedBox(height: 12),
        _TimelineCard(
          time: _timeWithOffset(0),
          title: 'Leave Blenheim',
          subtitle: 'SH1 south toward Kaikōura',
          tag: 'START',
          body:
              'Start with fuel/charge sorted and head south. The first planned break is Kaikōura.',
          checked: _completed.contains('sat_leave'),
          onChanged: (value) => _toggle('sat_leave', value),
          actions: [
            _LinkAction(
              label: 'Directions',
              onTap: () => _open(
                'https://www.google.com/maps/dir/?api=1&origin=Blenheim,+New+Zealand&destination=Kaikoura,+New+Zealand',
              ),
            ),
          ],
        ),
        _TimelineCard(
          time: _timeWithOffset(105),
          title: 'Kaikōura coffee / brunch',
          subtitle: 'Stretch, eat, then continue south',
          tag: '45–60 MIN',
          body:
              'Keep this as the proper break on the drive. You can make it longer if the weather is good.',
          checked: _completed.contains('kaikoura'),
          onChanged: (value) => _toggle('kaikoura', value),
          actions: [
            _LinkAction(
              label: 'Kaikōura cafés',
              onTap: () => _open(
                'https://www.google.com/maps/search/?api=1&query=Kaikoura+New+Zealand+cafes',
              ),
            ),
          ],
        ),
        _TimelineCard(
          time: _timeWithOffset(165),
          title: 'Kaikōura → Christchurch',
          subtitle: 'Continue on SH1 through North Canterbury',
          tag: 'ROAD',
          body:
              'Allow roughly 2½ hours plus any extra comfort stop you want on the way.',
          checked: _completed.contains('leave_kaikoura'),
          onChanged: (value) => _toggle('leave_kaikoura', value),
          actions: [
            _LinkAction(
              label: 'Route',
              onTap: () => _open(
                'https://www.google.com/maps/dir/?api=1&origin=Kaikoura,+New+Zealand&destination=Christchurch,+New+Zealand',
              ),
            ),
          ],
        ),
        _TimelineCard(
          time: _timeWithOffset(315),
          title: 'Arrive Christchurch',
          subtitle: 'Saturday-night stay still to be chosen',
          tag: 'OVERNIGHT',
          body:
              'Check in, have an easy evening, and keep Sunday morning unhurried.',
          checked: _completed.contains('sat_arrive'),
          onChanged: (value) => _toggle('sat_arrive', value),
        ),
        const SizedBox(height: 22),
        const _SectionHeader(
          title: 'Sunday 13 September',
          subtitle: 'Orana Wildlife Park + Mini Moo + Airbnb',
        ),
        const SizedBox(height: 10),
        const _Notice(
          warning: true,
          text:
              'Mini Moo starts at 11:30 am. Your booking says participants must arrive at least 45 minutes early to collect tickets and complete the waiver.',
        ),
        const SizedBox(height: 12),
        _TimelineCard(
          time: '9:20 am',
          title: 'Leave Christchurch accommodation',
          subtitle: 'Aim to reach Orana at opening',
          tag: 'SUNDAY',
          body: 'Orana Wildlife Park is at 793 McLeans Island Road.',
          checked: _completed.contains('sun_leave'),
          onChanged: (value) => _toggle('sun_leave', value),
          actions: [
            _LinkAction(
              label: 'Directions',
              onTap: () => _open(
                'https://www.google.com/maps/dir/?api=1&destination=Orana+Wildlife+Park,+793+McLeans+Island+Road,+Christchurch',
              ),
            ),
          ],
        ),
        _TimelineCard(
          time: '10:00 am',
          title: 'Arrive at Orana',
          subtitle: 'Admission, tickets and waiver',
          tag: 'CHECK IN',
          body:
              'Sort general park admission separately, collect encounter tickets and complete the waiver with plenty of time to spare.',
          checked: _completed.contains('orana_checkin'),
          onChanged: (value) => _toggle('orana_checkin', value),
          actions: [
            _LinkAction(
              label: 'Orana store',
              onTap: () => _open('https://store.oranawildlifepark.co.nz/'),
            ),
          ],
        ),
        _TimelineCard(
          time: '11:30 am',
          title: 'MINI MOO ENCOUNTER',
          subtitle: '2 adults · NZ\$79 total · approx. 20 minutes',
          tag: 'MAIN EVENT',
          feature: true,
          body:
              'Meet Barry, Orana’s miniature Belted Galloway/Highland cross. Brush his coat, feed pellets and give him pats with the keeper.',
          checked: _completed.contains('mini_moo'),
          onChanged: (value) => _toggle('mini_moo', value),
          actions: [
            _LinkAction(
              label: 'Mini Moo booking',
              filled: true,
              onTap: () => _open(
                'https://store.oranawildlifepark.co.nz/#/AdmissionCategory/MiniMooEncounter',
              ),
            ),
          ],
        ),
        _TimelineCard(
          time: '12:00 pm',
          title: 'Enjoy the rest of Orana',
          subtitle: 'Presentations, lunch and free exploring',
          tag: 'AFTERNOON',
          body:
              'Stay as long as you like, then leave enough time for a relaxed drive to your Sunday-night Airbnb.',
          checked: _completed.contains('orana_day'),
          onChanged: (value) => _toggle('orana_day', value),
        ),
        _TimelineCard(
          time: 'After Orana',
          title: 'Check into Sunday-night Airbnb',
          subtitle: '13 Sep → 14 Sep',
          tag: 'BOOKED PLAN',
          feature: true,
          body:
              'Use the Airbnb listing for the host’s exact address, check-in time and arrival instructions.',
          checked: _completed.contains('airbnb_checkin'),
          onChanged: (value) => _toggle('airbnb_checkin', value),
          actions: [
            _LinkAction(
              label: 'Open Airbnb',
              filled: true,
              onTap: () => _open(_airbnbUrl),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionHeader(
          title: 'Monday 14 September',
          subtitle: 'Airbnb checkout → Blenheim',
        ),
        const SizedBox(height: 10),
        _TimelineCard(
          time: 'Morning',
          title: 'Check out of Airbnb',
          subtitle: 'Use the host’s confirmed checkout time',
          tag: 'CHECK OUT',
          body:
              'Pack up, check the property instructions, then start the trip north toward Blenheim.',
          checked: _completed.contains('airbnb_checkout'),
          onChanged: (value) => _toggle('airbnb_checkout', value),
          actions: [
            _LinkAction(label: 'Airbnb', onTap: () => _open(_airbnbUrl)),
          ],
        ),
        _TimelineCard(
          time: 'Flexible',
          title: 'Christchurch → Kaikōura → Blenheim',
          subtitle: 'Return north with a Kaikōura break',
          tag: 'HOME',
          body:
              'Make the return drive at your own pace and stop in Kaikōura again if you want lunch or a walk.',
          checked: _completed.contains('home'),
          onChanged: (value) => _toggle('home', value),
          actions: [
            _LinkAction(
              label: 'Route home',
              onTap: () => _open(
                'https://www.google.com/maps/dir/?api=1&origin=Christchurch,+New+Zealand&destination=Blenheim,+New+Zealand&waypoints=Kaikoura,+New+Zealand',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBookings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const _SectionHeader(
          title: 'Bookings',
          subtitle: 'Everything needed for the weekend in one place',
        ),
        const SizedBox(height: 12),
        _BookingCard(
          icon: Icons.pets_rounded,
          title: 'Mini Moo Encounter',
          status: 'PLAN CONFIRMED',
          rows: const [
            ('Date', 'Sunday 13 September 2026'),
            ('Time', '11:30 am'),
            ('Guests', '2 adults'),
            ('Encounter price', 'NZ\$79 total'),
            ('Admission', 'Separate park admission required'),
          ],
          primaryLabel: 'Open Mini Moo',
          onPrimary: () => _open(
            'https://store.oranawildlifepark.co.nz/#/AdmissionCategory/MiniMooEncounter',
          ),
        ),
        const SizedBox(height: 12),
        _BookingCard(
          icon: Icons.house_rounded,
          title: 'Sunday-night Airbnb',
          status: '13 → 14 SEP',
          rows: const [
            ('Check-in', 'Sunday 13 September 2026'),
            ('Check-out', 'Monday 14 September 2026'),
            ('Guests', '1 adult in the listing link'),
            ('Address', 'Open Airbnb for host-confirmed details'),
          ],
          primaryLabel: 'Open Airbnb',
          onPrimary: () => _open(_airbnbUrl),
        ),
        const SizedBox(height: 12),
        _EditableBookingCard(
          hotelController: _satHotelController,
          addressController: _satHotelAddressController,
          onChanged: _save,
          onOpenMap: () {
            final query = _satHotelAddressController.text.trim().isNotEmpty
                ? _satHotelAddressController.text.trim()
                : _satHotelController.text.trim();
            if (query.isNotEmpty) {
              _open(
                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
              );
            }
          },
        ),
        const SizedBox(height: 14),
        const _SectionHeader(
          title: 'Trip checklist',
          subtitle: 'Saved on this device',
        ),
        const SizedBox(height: 8),
        ...[
          ('fuel_ready', 'Fuel / EV charge sorted'),
          ('sat_stay_booked', 'Saturday-night Christchurch accommodation booked'),
          ('moo_booking_ready', 'Mini Moo booking/tickets ready'),
          ('park_admission', 'Orana general admission sorted'),
          ('closed_shoes', 'Closed-toe footwear packed'),
          ('camera', 'Phone / camera charged'),
          ('airbnb_details', 'Airbnb check-in instructions saved'),
        ].map(
          (item) => _ChecklistTile(
            label: item.$2,
            value: _completed.contains(item.$1),
            onChanged: (value) => _toggle(item.$1, value),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _notesController,
          minLines: 4,
          maxLines: 8,
          onChanged: (_) => _save(),
          style: const TextStyle(color: _ink),
          decoration: InputDecoration(
            labelText: 'Trip notes',
            labelStyle: const TextStyle(color: _muted),
            hintText: 'Booking reference, packing notes, dinner ideas…',
            hintStyle: const TextStyle(color: _muted),
            filled: true,
            fillColor: _paper,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _brown, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudget() {
    const fixed = 158.0; // Mini Moo + two adult park admissions.
    final total = fixed + _fuel + _saturdayStay + _food + _extras;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const _SectionHeader(
          title: 'Weekend budget',
          subtitle: 'Editable planning amounts for two adults',
        ),
        const SizedBox(height: 12),
        _BudgetHero(total: total),
        const SizedBox(height: 12),
        _BudgetLine(label: 'Mini Moo tickets', value: 'NZ\$79', fixed: true),
        const _BudgetLine(
          label: 'Orana admission × 2',
          value: 'NZ\$79',
          fixed: true,
        ),
        _BudgetEditor(
          label: 'Return fuel / travel',
          value: _fuel,
          onChanged: (value) {
            setState(() => _fuel = value);
            _save();
          },
        ),
        _BudgetEditor(
          label: 'Saturday-night accommodation',
          value: _saturdayStay,
          onChanged: (value) {
            setState(() => _saturdayStay = value);
            _save();
          },
        ),
        _BudgetEditor(
          label: 'Food / coffees',
          value: _food,
          onChanged: (value) {
            setState(() => _food = value);
            _save();
          },
        ),
        _BudgetEditor(
          label: 'Other / shopping',
          value: _extras,
          onChanged: (value) {
            setState(() => _extras = value);
            _save();
          },
        ),
        const SizedBox(height: 12),
        const _Notice(
          text:
              'The Airbnb price is not included yet because the listing total was not provided. Add it to Other, or we can add a dedicated Airbnb amount once booked.',
        ),
      ],
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final suffix = time.hour >= 12 ? 'pm' : 'am';
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$h:${time.minute.toString().padLeft(2, '0')} $suffix';
  }

  static const _itineraryKeys = [
    'sat_leave',
    'kaikoura',
    'leave_kaikoura',
    'sat_arrive',
    'sun_leave',
    'orana_checkin',
    'mini_moo',
    'orana_day',
    'airbnb_checkin',
    'airbnb_checkout',
    'home',
  ];

  static const _airbnbUrl =
      'https://www.airbnb.co.nz/rooms/1251971271821187559?adults=1&check_in=2026-09-13&check_out=2026-09-14';
}

class _TripHero extends StatelessWidget {
  const _TripHero({required this.onOpenAirbnb});

  final VoidCallback onOpenAirbnb;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2622), Color(0xFF5C3B29), Color(0xFF8C5836)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MINI MOO WEEKEND · 12–14 SEPTEMBER 2026',
                style: TextStyle(
                  color: Color(0xFFDBC6B6),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Blenheim → Christchurch → Orana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Saturday road trip, Sunday Mini Moo, Sunday-night Airbnb, then home Monday.',
                style: TextStyle(color: Color(0xFFE9DED7), height: 1.45),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(icon: Icons.pets_rounded, label: 'Mini Moo 11:30 am'),
                  _HeroChip(icon: Icons.house_rounded, label: 'Airbnb 13–14 Sep'),
                  _HeroChip(icon: Icons.route_rounded, label: 'Blenheim start'),
                ],
              ),
            ],
          );
          if (compact) return text;
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: onOpenAirbnb,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Airbnb'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF4E8),
                  foregroundColor: const Color(0xFF5C3B29),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFFFDFC4)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.items});
  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final childWidth = width < 620 ? width : (width - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: childWidth,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _TripsScreenState._paper,
                      border: Border.all(color: _TripsScreenState._line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.value,
                          style: const TextStyle(
                            color: _TripsScreenState._ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: _TripsScreenState._muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.value, this.label);
  final String value;
  final String label;
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _TripsScreenState._paper,
        border: Border.all(color: _TripsScreenState._line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Trip progress',
                style: TextStyle(
                  color: _TripsScreenState._ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '$done / $total',
                style: const TextStyle(
                  color: _TripsScreenState._brown,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFE9DFD2),
              color: _TripsScreenState._brown,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _TripsScreenState._ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _TripsScreenState._muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.warning = false});
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: warning
            ? _TripsScreenState._warning
            : _TripsScreenState._greenSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: warning
              ? const Color(0xFFEBCB9F)
              : const Color(0xFFCADAC6),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: warning
              ? _TripsScreenState._warningInk
              : _TripsScreenState._greenInk,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.body,
    required this.checked,
    required this.onChanged,
    this.feature = false,
    this.actions = const [],
  });

  final String time;
  final String title;
  final String subtitle;
  final String tag;
  final String body;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final bool feature;
  final List<_LinkAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final card = Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: feature
                  ? const Color(0xFFFFFAF3)
                  : _TripsScreenState._paper,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: feature
                    ? const Color(0xFFCFA578)
                    : _TripsScreenState._line,
                width: feature ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: _TripsScreenState._ink,
                              fontSize: feature ? 18 : 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: _TripsScreenState._muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _TripsScreenState._soft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF6D4127),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  body,
                  style: const TextStyle(
                    color: _TripsScreenState._ink,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: actions
                        .map(
                          (action) => action.filled
                              ? FilledButton(
                                  onPressed: action.onTap,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _TripsScreenState._brown,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                  ),
                                  child: Text(action.label),
                                )
                              : OutlinedButton(
                                  onPressed: action.onTap,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _TripsScreenState._brown,
                                    side: const BorderSide(
                                      color: _TripsScreenState._line,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                  ),
                                  child: Text(action.label),
                                ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: checked,
                  onChanged: (value) => onChanged(value ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: _TripsScreenState._brown,
                  title: const Text(
                    'Done',
                    style: TextStyle(
                      color: _TripsScreenState._muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 5),
                  child: Text(
                    time,
                    style: const TextStyle(
                      color: _TripsScreenState._brown,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                card,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    time,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _TripsScreenState._brown,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Expanded(child: card),
            ],
          );
        },
      ),
    );
  }
}

class _LinkAction {
  const _LinkAction({required this.label, required this.onTap, this.filled = false});
  final String label;
  final VoidCallback onTap;
  final bool filled;
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.rows,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String status;
  final List<(String, String)> rows;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _TripsScreenState._paper,
        border: Border.all(color: _TripsScreenState._line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _TripsScreenState._soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _TripsScreenState._brown),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _TripsScreenState._ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                status,
                style: const TextStyle(
                  color: _TripsScreenState._brown,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: _TripsScreenState._muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        color: _TripsScreenState._ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPrimary,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(primaryLabel),
            style: FilledButton.styleFrom(
              backgroundColor: _TripsScreenState._brown,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableBookingCard extends StatelessWidget {
  const _EditableBookingCard({
    required this.hotelController,
    required this.addressController,
    required this.onChanged,
    required this.onOpenMap,
  });

  final TextEditingController hotelController;
  final TextEditingController addressController;
  final VoidCallback onChanged;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label, String hint) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _TripsScreenState._muted),
      hintStyle: const TextStyle(color: _TripsScreenState._muted),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _TripsScreenState._line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _TripsScreenState._brown, width: 2),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _TripsScreenState._paper,
        border: Border.all(color: _TripsScreenState._line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Saturday-night accommodation',
            style: TextStyle(
              color: _TripsScreenState._ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '12 → 13 September · still to choose',
            style: TextStyle(color: _TripsScreenState._muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: hotelController,
            onChanged: (_) => onChanged(),
            style: const TextStyle(color: _TripsScreenState._ink),
            decoration: decoration('Hotel / motel', 'Enter accommodation name'),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: addressController,
            onChanged: (_) => onChanged(),
            style: const TextStyle(color: _TripsScreenState._ink),
            decoration: decoration('Address', 'Enter address when booked'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpenMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open in Maps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _TripsScreenState._brown,
              side: const BorderSide(color: _TripsScreenState._line),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: _TripsScreenState._paper,
        border: Border.all(color: _TripsScreenState._line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        activeColor: _TripsScreenState._brown,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          label,
          style: const TextStyle(
            color: _TripsScreenState._ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BudgetHero extends StatelessWidget {
  const _BudgetHero({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C3B29), Color(0xFF8C5836)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLANNED TOTAL',
                  style: TextStyle(
                    color: Color(0xFFDBC6B6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Current weekend estimate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'NZ\$${total.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine({required this.label, required this.value, this.fixed = false});
  final String label;
  final String value;
  final bool fixed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _TripsScreenState._paper,
        border: Border.all(color: _TripsScreenState._line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _TripsScreenState._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (fixed)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'FIXED',
                style: TextStyle(
                  color: _TripsScreenState._muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          Text(
            value,
            style: const TextStyle(
              color: _TripsScreenState._brown,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetEditor extends StatelessWidget {
  const _BudgetEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _TripsScreenState._paper,
        border: Border.all(color: _TripsScreenState._line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _TripsScreenState._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Text(
            'NZ\$',
            style: TextStyle(
              color: _TripsScreenState._muted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 86,
            child: TextFormField(
              key: ValueKey('$label-$value'),
              initialValue: value.toStringAsFixed(0),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _TripsScreenState._ink,
                fontWeight: FontWeight.w900,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onChanged: (raw) {
                final parsed = double.tryParse(raw);
                if (parsed != null && parsed >= 0) onChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}
