import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FanShopScreen extends StatefulWidget {
  const FanShopScreen({super.key});

  @override
  State<FanShopScreen> createState() => _FanShopScreenState();
}

class _FanShopScreenState extends State<FanShopScreen> {
  int _selectedCategory = 0;
  final List<String> _categories = ['All Items', 'Jerseys', 'Headwear', 'Memorabilia', 'Training'];

  // Product data matching the Stitch design
  final List<Map<String, String>> _products = [
    {
      'title': 'Cedar Elite Home Jersey',
      'subtitle': '2024 Season Edition • Moisture-wicking fabric',
      'price': '\$120.00',
      'badge': 'Authentic',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCBhqlu88FtI77R06HoxfnJ4gt9nK2r9_eKpBsj-5ezeHa6KFh5DgYAD5pUEcAGgbQ_bsPf_xAbDxXS1wIM9og7ZzAw0QSc25-RUITZLadjEIGk41cMkf5iU8ejUYtIQc5SUeS_0wlT-Ub-mrXaptJQWTbEDWrHvxbZIrgs_eQMJTNrFExUilIfHEqRwMHWtZp4w0vkbIxrnPzgp3nPzAwUT9faSzu6KspN5KBmV1BxQCJdE2qvxK2-4AUCNx4Tb2PuLZBmAEUyAKfD',
    },
    {
      'title': 'The Finals Snapback',
      'subtitle': 'Adjustable • One size',
      'price': '\$35.00',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCkxKuLef9iVRYDuD1TGyLt3aoYGn5-s01ceYK5GgkxRkG5kSz7O9w7HGXNsYSe8z35Zir1tI4UBWl2qcyHezxoUZZzmVfJCmdZo4tsaKlWnPxw1ZGYR3RODtaL-JLUN7WeusxUOb2ZJCmC0y535uMvDwt_TlOUdZWITFd9Ln3lynSe1R6W0TdfFPb8q8CzJh7A4paSs2Zo_Xy8NzKPfy1J8Z81qpJGWq-eqjd1WIsvNH0x-nxhLB4hKuS1HfyFpqf45p5S6U4kHM86',
    },
    {
      'title': 'Official Game Ball',
      'subtitle': 'Pro League Standard Size 7',
      'price': '\$85.00',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuBgYl9M_nujrgtwP53a-ldvxavTlBsOXL16EnXfozUWPEpu4SVb85fI_GbuH1jJnDj48gGCIHRBgKHKvrdAF0pK7bgENnDiPMu0kZgExCO0ANoi7GqQ2mcjCqgVnpJoMnQTduXRrsNLcf2g0c5deKONXRFogZc2C2CfT7pqunoD1EA4qrG6j4uryHiLE0XrXm0-rmx7X0tse19XbEv_LuMwr3rpfB5VnwdKd_p9vNP8eqOG9ytyE1wa7lwJOJ8LNB7YztFfSxN8dI1L',
    },
    {
      'title': 'Sideline Fleece Hoodie',
      'subtitle': 'Available in Grey / Black',
      'price': '\$65.00',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuBwk91XV2mPKLowey1YFyKShlG97mVenZFlTba6h_9hNfOP9V0fuH3YilG2KZn888biDYYyXRVrxUbtPmDbwQxF2B5r83QatqSGobWao_hDW4O_OFvY6nqhquO0TZhr2s0IRlgJXRrPx3Rt7NuK_0YczPeQzHLZF2Bp2wFV5P0oNAZO4IVL8Y6FrozOYqaV7SPGWQ1OeBX8f-fE5ylVcTatdy18vRuV4Y7R8jzPBi31doQAwodqt3TctbSH9l-EAq-cSl3wFvN6X1OW',
    },
    {
      'title': 'Autographed Frame',
      'subtitle': 'Hand-signed by 2023 MVP',
      'price': '\$245.00',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCMWpwqDCrQaBY9F89MN3Z03MJRvCg5AkU80hRSo7LE6TgA6T6uu0nXKnuSninjUjAdaPAChy7JuAY-jet4JywTbiICaCbPuuE8IloNBfRpuYEgAUhjd0eEgQudSTn0tTPvyT2hbkx9nmPwdMraoI9K3U6YuZuEDRqvunBTjNQSjdmAn64-4e_CrAIgp-MhvxwFS1DpJUUcGAah0_zljZCY3hG6cZJuaDYLVl-8l2F8UdEhkWe7_Q7ZGX8Xm4MLAtNE7XCpAckZpWRr',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 128, left: 24, right: 24), // pt-20 pb-32 px-6
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroBanner(),
              const SizedBox(height: 48), // mb-12
              _buildCategoryFilters(),
              const SizedBox(height: 48), // mb-12
              _buildFeaturedProduct(),
              const SizedBox(height: 32), // gap-8
              _buildProductGrid(),
              const SizedBox(height: 80), // mt-20
              _buildMvpPackSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero Editorial Section ──────────────────────────────────
  Widget _buildHeroBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12), // rounded-xl
      child: SizedBox(
        height: 340,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuB2F4mXAhrehyYkaSQPdQQ1dR2wxLNX1XPrcB6V6lxlXqCZf28yFRXtd2pT0w83wae8N2gmhS2unSlqSzgqUKlrfZfOZqtfHv7UsGARUI1rkCQM0_jo7Sm8eGGi1j8qHWHYkVeuAZQCIZARigfKNPpbSsmRA2uMMtbEpSXGK86y_Cv-zq9MFpzo9S8j9cyA9VIiFUKeZ4ug1XDvY9Hqcmup0pwY9T9D4Ntf36YqtfKgzTYBc450HXwfTDTx4xifUKB6fmHaJM2ake0a',
              fit: BoxFit.cover,
            ),
            // Gradient overlay: from-on-surface via-on-surface/40 to-transparent
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.onSurface,
                    AppColors.onSurface.withAlpha((255 * 0.4).round()),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Text content
            Positioned(
              bottom: 32, // p-8
              left: 32,
              right: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
                    color: AppColors.primary,
                    child: const Text(
                      'Limited Drop',
                      style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0), // text-xs uppercase tracking-widest
                    ),
                  ),
                  const SizedBox(height: 16), // mb-4
                  const Text(
                    'REPRESENT THE LEGACY',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, fontStyle: FontStyle.italic, height: 1.0), // text-4xl font-black italic leading-none
                  ),
                  const SizedBox(height: 16), // mb-4
                  Text(
                    'Explore the official 2024 Lebanese League collection. Authentic gear for the ultimate fan.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white.withAlpha((255 * 0.8).round()), height: 1.4), // text-sm text-white/80
                  ),
                  const SizedBox(height: 24), // mb-6
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), // px-8 py-3
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // rounded-xl
                      elevation: 0,
                    ),
                    child: const Text(
                      'SHOP EXCLUSIVES',
                      style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold), // font-bold text-sm
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Filter Chips ──────────────────────────────────
  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16), // gap-4
        itemBuilder: (context, index) {
          final isActive = _selectedCategory == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // px-6 py-2
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12), // rounded-xl
                boxShadow: isActive
                    ? [BoxShadow(color: AppColors.primary.withAlpha((255 * 0.2).round()), blurRadius: 8, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 14, // text-sm
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : AppColors.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Featured (Large) Product Card ──────────────────────────
  Widget _buildFeaturedProduct() {
    final product = _products[0];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with badge
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Image.network(
                  product['image']!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100), // rounded-full
                  ),
                  child: const Text(
                    'Authentic',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.5), // text-[10px] font-black tracking-tighter
                  ),
                ),
              ),
            ],
          ),
          // Product info
          Container(
            padding: const EdgeInsets.all(32), // p-8
            color: AppColors.surfaceContainerHighest.withAlpha((255 * 0.5).round()), // bg-surface-container-highest/50
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['title']!,
                            style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: AppColors.onSurface, height: 1.1), // text-2xl font-extrabold italic leading-tight
                          ),
                          const SizedBox(height: 4), // mb-1
                          Text(
                            product['subtitle']!,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.secondary), // text-sm text-secondary
                          ),
                        ],
                      ),
                    ),
                    Text(
                      product['price']!,
                      style: const TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary), // text-2xl font-black text-primary
                    ),
                  ],
                ),
                const SizedBox(height: 24), // mt-6
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                    label: const Text(
                      'QUICK ADD',
                      style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16), // py-4
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // rounded-xl
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Standard Product Grid (2-col) ─────────────────────────
  Widget _buildProductGrid() {
    final standardProducts = _products.sublist(1); // skip the featured one
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 32, // gap-8
        mainAxisSpacing: 32, // gap-8
        childAspectRatio: 0.5,
      ),
      itemCount: standardProducts.length,
      itemBuilder: (context, index) {
        final product = standardProducts[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12), // rounded-xl
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.white, // bg-white
                  width: double.infinity,
                  child: Image.network(
                    product['image']!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Product info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12), // p-3
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product['title']!,
                              style: const TextStyle(fontFamily: 'Lexend', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface, height: 1.1),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              product['subtitle']!,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.secondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            product['price']!,
                            style: const TextStyle(fontFamily: 'Lexend', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.onSurface),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.onSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Limited Edition MVP Pack Section ───────────────────────
  Widget _buildMvpPackSection() {
    return Container(
      padding: const EdgeInsets.all(40), // p-10
      decoration: BoxDecoration(
        color: AppColors.inverseSurface, // bg-inverse-surface (#2A303F)
        borderRadius: BorderRadius.circular(16), // rounded-2xl
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIMITED EDITION MVP PACK',
            style: TextStyle(fontFamily: 'Lexend', fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, fontStyle: FontStyle.italic, letterSpacing: -2.0, height: 1.1), // text-3xl font-black italic uppercase tracking-tighter
          ),
          const SizedBox(height: 16), // mb-4
          Text(
            'Get the exclusive MVP bundle including the limited edition game day jersey, signed photo, and a commemorative ring box.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: AppColors.inverseOnSurface.withAlpha((255 * 0.8).round()), height: 1.5), // text-inverse-on-surface/80
          ),
          const SizedBox(height: 32), // mb-8
          // Pricing row
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '\$399.00',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryFixedDim), // text-2xl font-black text-primary-fixed-dim
                  ),
                  Text(
                    '\$550.00',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white.withAlpha((255 * 0.4).round()), decoration: TextDecoration.lineThrough), // text-sm line-through text-white/40
                  ),
                ],
              ),
              const SizedBox(width: 24), // gap-6
              Container(height: 40, width: 1, color: Colors.white.withAlpha((255 * 0.2).round())), // h-10 w-[1px] bg-white/20
              const SizedBox(width: 24), // gap-6
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Only 50',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // text-xl font-bold
                  ),
                  Text(
                    'PACKS LEFT',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white.withAlpha((255 * 0.6).round()), letterSpacing: 2.0), // text-xs uppercase text-white/60 tracking-widest
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32), // mb-8
          // MVP pack image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuDQHqQs-m67gy7EMc5cN937YiLcBXKX6g4zpfKKlqcbzlTePA4aXxIclAHjm2_BMLhG__ypw8Ib2l_v1DTlkXHcYksixROpznJqwXHqsCQDGZ0Req3jsFJZJF71zAIVs4tbiuFSDMjuA5bVVbRr7VKxfb4VLSSN-CkP_h0O5tsn-h8qMiI0zKN8DM6Ue8HYaGh5KM-VJ4h6wVzL6E5zL0cn69wW5lq8xZK8oL1KI_AQxmBsvLTDmUSQfa3ugS815PpYWk7PRmSpW70n',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40), // px-10 py-4
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // rounded-xl
                elevation: 0,
              ),
              child: const Text(
                'SECURE YOUR PACK',
                style: TextStyle(fontFamily: 'Lexend', fontSize: 18, fontWeight: FontWeight.bold), // font-bold text-lg
              ),
            ),
          ),
        ],
      ),
    );
  }
}
