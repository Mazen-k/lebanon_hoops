import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class UpcomingGame {
  final String dateStr;
  final String homeTeam;
  final String awayTeam;
  final String venue;

  UpcomingGame(this.dateStr, this.homeTeam, this.awayTeam, this.venue);
}

class TicketTier {
  final String name;
  final double price;
  final String desc;

  TicketTier(this.name, this.price, this.desc);
}

class TicketSelectionScreen extends StatefulWidget {
  const TicketSelectionScreen({super.key});

  @override
  State<TicketSelectionScreen> createState() => _TicketSelectionScreenState();
}

class _TicketSelectionScreenState extends State<TicketSelectionScreen> {
  final List<UpcomingGame> _games = [
    UpcomingGame('FRI, OCT 24 • 8:30 PM', 'SAGESSE SC', 'AL RIYADI', 'Ghazir Club Stadium'),
    UpcomingGame('TUE, OCT 28 • 7:00 PM', 'AL RIYADI', 'BEIRUT CLUB', 'Saeb Salam Arena'),
    UpcomingGame('SAT, NOV 2 • 6:00 PM', 'HOMENETMEN', 'AL RIYADI', 'Mezher Stadium'),
  ];

  final List<TicketTier> _tiers = [
    TicketTier('REGULAR', 15.0, 'Upper bowl seating'),
    TicketTier('VIP', 45.0, 'Lower bowl, court access'),
    TicketTier('VVIP', 120.0, 'Courtside seating, lounge access'),
  ];

  int _selectedGameIndex = 0;
  int _selectedTierIndex = 0;
  int _ticketQuantity = 1;

  double get _totalPrice => _tiers[_selectedTierIndex].price * _ticketQuantity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 140, left: 24, right: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 28),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 24,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('UPCOMING GAMES'),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _games.length,
                itemBuilder: (context, index) => _buildGameCard(index, _games[index]),
              ),
            ),
            const SizedBox(height: 48),

            _buildSectionHeader('TICKET TYPE'),
            const SizedBox(height: 16),
            Column(
              children: _tiers.asMap().entries.map((e) => _buildTierCard(e.key, e.value)).toList(),
            ),
            const SizedBox(height: 48),

            _buildSectionHeader('QUANTITY'),
            const SizedBox(height: 16),
            _buildQuantitySelector(),
          ],
        ),
      ),
      ),
      bottomSheet: _buildCheckoutBottomBar(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontFamily: 'Lexend', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.onSurface, fontStyle: FontStyle.italic, letterSpacing: -0.5),
        ),
      ],
    );
  }

  Widget _buildGameCard(int index, UpcomingGame game) {
    bool isSelected = _selectedGameIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedGameIndex = index),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: AppColors.outlineVariant.withAlpha((255 * 0.2).round())),
          boxShadow: [
            if (isSelected) BoxShadow(color: AppColors.primary.withAlpha((255 * 0.3).round()), blurRadius: 15, offset: const Offset(0, 8))
            else BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              game.dateStr,
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: isSelected ? Colors.white70 : AppColors.secondary),
            ),
            const SizedBox(height: 12),
            Text(
              '${game.homeTeam} vs\n${game.awayTeam}',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1, color: isSelected ? Colors.white : AppColors.onSurface),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: isSelected ? Colors.white70 : AppColors.secondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    game.venue,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w500, color: isSelected ? Colors.white70 : AppColors.secondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(int index, TicketTier tier) {
    bool isSelected = _selectedTierIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTierIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainerLow : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.primary, width: 2) : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.03).round()), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.name,
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 16, fontWeight: FontWeight.w900, color: isSelected ? AppColors.primary : AppColors.onSurface),
                ),
                const SizedBox(height: 4),
                Text(tier.desc, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.secondary)),
              ],
            ),
            Text(
              '\$${tier.price.toInt()}',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: isSelected ? AppColors.primary : AppColors.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.03).round()), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Number of Tickets', style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
          Row(
            children: [
              _buildQtyBtn(Icons.remove, () {
                if (_ticketQuantity > 1) setState(() => _ticketQuantity--);
              }),
              SizedBox(
                width: 48,
                child: Text(
                  '$_ticketQuantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.onSurface),
                ),
              ),
              _buildQtyBtn(Icons.add, () {
                if (_ticketQuantity < 10) setState(() => _ticketQuantity++);
              }),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }

  Widget _buildCheckoutBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.1).round()), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: 1.0)),
                  Text(
                    '\$${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontFamily: 'Lexend', fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.onSurface, height: 1.0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFBB0013), Color(0xFFE71520)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CHECKOUT', style: TextStyle(fontFamily: 'Lexend', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
