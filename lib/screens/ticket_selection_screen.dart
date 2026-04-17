import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
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
                    icon: Icon(Icons.arrow_back, color: colorScheme.primary, size: 28),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 24,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'UPCOMING GAMES'),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _games.length,
                itemBuilder: (context, index) => _buildGameCard(context, index, _games[index]),
              ),
            ),
            const SizedBox(height: 48),

            _buildSectionHeader(context, 'TICKET TYPE'),
            const SizedBox(height: 16),
            Column(
              children: _tiers.asMap().entries.map((e) => _buildTierCard(context, e.key, e.value)).toList(),
            ),
            const SizedBox(height: 48),

            _buildSectionHeader(context, 'QUANTITY'),
            const SizedBox(height: 16),
            _buildQuantitySelector(context),
          ],
        ),
      ),
      ),
      bottomSheet: _buildCheckoutBottomBar(context),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(width: 4, height: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(fontFamily: 'Lexend', fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface, fontStyle: FontStyle.italic, letterSpacing: -0.5),
        ),
      ],
    );
  }

  Widget _buildGameCard(BuildContext context, int index, UpcomingGame game) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isSelected = _selectedGameIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedGameIndex = index),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : (colorScheme.brightness == Brightness.dark ? colorScheme.surfaceContainer : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: colorScheme.outlineVariant.withAlpha((255 * 0.2).round())),
          boxShadow: [
            if (isSelected) BoxShadow(color: colorScheme.primary.withAlpha((255 * 0.3).round()), blurRadius: 15, offset: const Offset(0, 8))
            else BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              game.dateStr,
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: isSelected ? Colors.white70 : colorScheme.secondary),
            ),
            const SizedBox(height: 12),
            Text(
              '${game.homeTeam} vs\n${game.awayTeam}',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1, color: isSelected ? Colors.white : colorScheme.onSurface),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: isSelected ? Colors.white70 : colorScheme.secondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    game.venue,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w500, color: isSelected ? Colors.white70 : colorScheme.secondary),
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

  Widget _buildTierCard(BuildContext context, int index, TicketTier tier) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isSelected = _selectedTierIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTierIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surfaceContainerLow : (colorScheme.brightness == Brightness.dark ? colorScheme.surfaceContainer : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: colorScheme.primary, width: 2) : Border.all(color: Colors.transparent, width: 2),
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
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 16, fontWeight: FontWeight.w900, color: isSelected ? colorScheme.primary : colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(tier.desc, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: colorScheme.secondary)),
              ],
            ),
            Text(
              '\$${tier.price.toInt()}',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: isSelected ? colorScheme.primary : colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.03).round()), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Number of Tickets', style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          Row(
            children: [
              _buildQtyBtn(context, Icons.remove, () {
                if (_ticketQuantity > 1) setState(() => _ticketQuantity--);
              }),
              SizedBox(
                width: 48,
                child: Text(
                  '$_ticketQuantity',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                ),
              ),
              _buildQtyBtn(context, Icons.add, () {
                if (_ticketQuantity < 10) setState(() => _ticketQuantity++);
              }),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQtyBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: colorScheme.primary),
      ),
    );
  }

  Widget _buildCheckoutBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
                  Text('TOTAL', style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.secondary, letterSpacing: 1.0)),
                  Text(
                    '\$${_totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 32, fontWeight: FontWeight.w900, color: colorScheme.onSurface, height: 1.0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
