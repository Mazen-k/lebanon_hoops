import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CourtBookingScreen extends StatefulWidget {
  const CourtBookingScreen({super.key});

  @override
  State<CourtBookingScreen> createState() => _CourtBookingScreenState();
}

class _CourtBookingScreenState extends State<CourtBookingScreen> {
  int _selectedDayIndex = 1; // Match selected 'Tue 15'
  int _selectedTimeIndex = 3; // Match selected '8:00 PM'
  int _selectedCourtIndex = 0;

  final List<String> _courts = [
    'MANARA COURT',
    'GHAZIR STADIUM',
    'CHIYAH STADIUM',
    'MEZHER STADIUM',
    'DIK EL MEHDI',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 128, left: 16, right: 16), // pt-20 pb-32 px-4
          child: Column(
            children: [
              _buildHeroSection(context),
              const SizedBox(height: 24), // gap-6
              _buildDetailCard(context, Icons.layers, 'Pro Surface', 'FIBA Level 1 Hardwood Maple with shock-absorption technology.', Icons.sports_basketball),
              const SizedBox(height: 24), // gap-6
              _buildDetailCard(context, Icons.wb_sunny, 'Stadium Lighting', '2000 Lux LED Broadcast Standard for night games.', Icons.flashlight_on),
              const SizedBox(height: 48), // mb-12 approx
              _buildBookingSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 256, // h-64
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _courts.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedCourtIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCourtIndex = index),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              margin: const EdgeInsets.only(right: 16),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), // rounded-xl
                border: isSelected ? Border.all(color: colorScheme.primary, width: 3) : Border.all(color: Colors.transparent, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  children: [
                    Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCfw1CFH-fZAYoLg5vgxxP5Xvw1fVbtJF47ro85tKIMoPI0CRVa3wyO6wCMM-3XisPmfRvJ3MqMSvdrPfkTC9GVp2GIBznusIBfi2dOdeLoL4HTkfSx8ULfVkNzgd86sIh464VapUlBKqI4bTpFd322GDu7twih0NJYoufYY9XsZAPz5hioK1Lxup0B9YZw1xc9mkcwI89BcT7gKpUq-20nICQE8E3UY_bC01zb_Cyj6ZMaVyCvwhVb3N5a5mVLa_WM06EIRwx4SwdS',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.onSurface.withAlpha((255 * 0.8).round()), Colors.transparent], // from-on-background/80
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24, // bottom-6
                      left: 24, // left-6
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
                            decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(8)), // bg-primary rounded-lg
                            child: const Text(
                              'HOME VENUE',
                              style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0), // text-xs uppercase
                            ),
                          ),
                          const SizedBox(height: 8), // mb-2
                          Text(
                            _courts[index],
                            style: const TextStyle(fontFamily: 'Lexend', fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, fontStyle: FontStyle.italic, letterSpacing: -2.0, height: 1.0), // text-4xl tracking-tighter
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, IconData icon, String title, String desc, IconData bgIcon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24), // p-6
      decoration: BoxDecoration(
        color: colorScheme.surface, // surface-container-lowest
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -16, // -right-4
            bottom: -16, // -bottom-4
            child: Icon(bgIcon, size: 128, color: colorScheme.onSurface.withAlpha((255 * 0.05).round())), // text-9xl opacity-5
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: colorScheme.primary), // text-primary text-4xl
              const SizedBox(height: 16), // mb-4 equivalent
              Text(
                title,
                style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface, letterSpacing: -0.5, height: 1.0), // text-xl uppercase tracking-tight
              ),
              const SizedBox(height: 4), // mt-1
              Text(
                desc,
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: colorScheme.secondary), // text-sm
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24), // p-6
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESERVE COURT',
            style: TextStyle(fontFamily: 'Lexend', fontSize: 30, fontWeight: FontWeight.w900, color: colorScheme.onSurface, fontStyle: FontStyle.italic, letterSpacing: -2.0, height: 1.0), // text-3xl font-black
          ),
          const SizedBox(height: 4),
          Text(
            'Select your date and preferred training slot.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.secondary),
          ),
          const SizedBox(height: 40), // mb-10

          // Date Picker Array
          SizedBox(
            height: 100, // accommodate scaling
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _buildDateCard(context, 0, 'Mon', '14'),
                const SizedBox(width: 12),
                _buildDateCard(context, 1, 'Tue', '15'),
                const SizedBox(width: 12),
                _buildDateCard(context, 2, 'Wed', '16'),
                const SizedBox(width: 12),
                _buildDateCard(context, 3, 'Thu', '17'),
                const SizedBox(width: 12),
                _buildDateCard(context, 4, 'Fri', '18'),
              ],
            ),
          ),
          const SizedBox(height: 24), // spacing after dates

          // Time Slots Grid Flow
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16, // gap-4
            crossAxisSpacing: 16, // gap-4
            childAspectRatio: 1.5, // approximate fit
            children: [
              _buildTimeCard(context, 0, 'Available', '5:00 PM', '60 Minutes', false),
              _buildTimeCard(context, 1, 'Booked', '6:00 PM', 'Reserved by Team A', true),
              _buildTimeCard(context, 2, 'Available', '7:00 PM', '60 Minutes', false),
              _buildTimeCard(context, 3, 'Selected', '8:00 PM', 'Premium Lighting', false),
              _buildTimeCard(context, 4, 'Available', '9:00 PM', '60 Minutes', false),
              _buildTimeCard(context, 5, 'Available', '10:00 PM', 'Night Session', false),
            ],
          ),
          const SizedBox(height: 48), // mt-12
          _buildBookingTotalBar(context),
        ],
      ),
    );
  }

  Widget _buildBookingTotalBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24), // p-6
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.1).round()), blurRadius: 20, offset: const Offset(0, 10))], // shadow-xl
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL BOOKING AMOUNT',
            style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.secondary, letterSpacing: 1.0), // text-xs uppercase tracking-widest
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$120.00',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 30, fontWeight: FontWeight.w900, color: colorScheme.onSurface, height: 1.0), // text-3xl font-black
              ),
              const SizedBox(width: 4),
              Text(
                '/session',
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.secondary), // text-sm
              ),
            ],
          ),
          const SizedBox(height: 24), // gap equivalent
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFBB0013), Color(0xFFE71520)], // court-gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, // let gradient show
                  shadowColor: Colors.transparent, // handled by container
                  padding: const EdgeInsets.symmetric(vertical: 24), // py-4 scaled
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // rounded-xl
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'RESERVE NOW',
                      style: TextStyle(fontFamily: 'Lexend', fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -2.0), // text-lg tracking-tighter uppercase
                    ),
                    SizedBox(width: 12), // gap-3
                    Icon(Icons.bolt, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(BuildContext context, int index, String day, String date) {
    bool isSelected = _selectedDayIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDayIndex = index;
        });
      },
      child: Transform.scale(
        scale: isSelected ? 1.1 : 1.0, // scale-110 active
        child: Container(
          width: 64, // w-16
          height: 80, // h-20
          margin: EdgeInsets.symmetric(vertical: isSelected ? 4 : 8), // scale buffer
          decoration: BoxDecoration(
            color: isSelected ? null : colorScheme.surface,
            gradient: isSelected ? const LinearGradient(colors: [Color(0xFFBB0013), Color(0xFFE71520)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            borderRadius: BorderRadius.circular(12), // rounded-xl
            border: isSelected ? null : Border.all(color: Colors.transparent, width: 2),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withAlpha((255 * 0.1).round()), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day,
                style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : colorScheme.secondary, letterSpacing: 0.5), // uppercase uppercase text-[10px]
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : colorScheme.onSurface, height: 1.0), // font-black text-xl 
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard(BuildContext context, int index, String status, String time, String subText, bool isBooked) {
    bool isSelected = _selectedTimeIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor = colorScheme.surface; // bg-surface-container-lowest
    Border border = Border.all(color: Colors.transparent);
    double opacity = 1.0;

    if (isBooked) {
      bgColor = colorScheme.surfaceDim;
      opacity = 0.6; // opacity-60
    } else if (isSelected) {
      bgColor = colorScheme.primary.withAlpha((255 * 0.05).round()); // bg-primary/5
      border = Border.all(color: colorScheme.primary, width: 2); // border-primary
    }

    return GestureDetector(
      onTap: () {
        if (!isBooked) {
          setState(() {
            _selectedTimeIndex = index;
          });
        }
      },
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.all(16), // p-4
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12), // rounded-xl
            border: border,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    status,
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: isBooked ? colorScheme.secondary : colorScheme.primary), // uppercase font-label
                  ),
                  Icon(
                    isBooked ? Icons.block : (isSelected ? Icons.check_circle : Icons.schedule),
                    size: 16,
                    color: isBooked ? colorScheme.secondary : (isSelected ? colorScheme.primary : colorScheme.secondary.withAlpha((255 * 0.2).round())), // opacity-20 mapped
                  )
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface, height: 1.0), // text-lg font-black
                  ),
                  const SizedBox(height: 4), // mt-1
                  Text(
                    subText,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: colorScheme.secondary), // text-xs
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
