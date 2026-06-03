import 'package:flutter/material.dart';

// ─── Core Shimmer Effect Widget ───────────────────────────────────────────────

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE8E8E8),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

// ─── Shimmer Box (basic building block) ─────────────────────────────────────

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius:
            shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
        shape: shape,
      ),
    );
  }
}

// ─── Full-Page Shimmer (replaces initial Scaffold-level loading) ─────────────

class HomePageShimmer extends StatelessWidget {
  const HomePageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner shimmer
            Container(
              margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: const ShimmerBox(height: 148, borderRadius: 24),
            ),
            const SizedBox(height: 24),
            // Categories section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 160, height: 18, borderRadius: 8),
                  ShimmerBox(width: 50, height: 14, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        ShimmerBox(
                          height: 64,
                          width: 64,
                          borderRadius: 20,
                        ),
                        const SizedBox(height: 7),
                        ShimmerBox(
                          height: 10,
                          width: 40,
                          borderRadius: 5,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Shops section title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 130, height: 18, borderRadius: 8),
                  ShimmerBox(width: 60, height: 14, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Shop cards shimmer
            ...List.generate(3, (index) => _buildShopCardShimmer()),
          ],
        ),
      ),
    );
  }

  Widget _buildShopCardShimmer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 140, borderRadius: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 180, height: 16, borderRadius: 8),
                const SizedBox(height: 8),
                ShimmerBox(width: 120, height: 12, borderRadius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: 200, height: 11, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Banner Shimmer ─────────────────────────────────────────────────────────

class BannerShimmer extends StatelessWidget {
  const BannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: const ShimmerBox(height: 148, borderRadius: 24),
      ),
    );
  }
}

// ─── Category Shimmer ───────────────────────────────────────────────────────

class CategoryShimmer extends StatelessWidget {
  const CategoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SizedBox(
        height: 104,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  ShimmerBox(height: 64, width: 64, borderRadius: 20),
                  const SizedBox(height: 7),
                  ShimmerBox(height: 10, width: 40, borderRadius: 5),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Shops List Shimmer (for Nearby Shops on home, All Shops, Category Shops) ─

class ShopsListShimmer extends StatelessWidget {
  final int itemCount;
  final bool isSliver;

  const ShopsListShimmer({
    super.key,
    this.itemCount = 3,
    this.isSliver = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = ShimmerEffect(
      child: Column(
        children: List.generate(itemCount, (index) => _buildShopCardShimmer()),
      ),
    );

    if (isSliver) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: content,
    );
  }

  Widget _buildShopCardShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 140, borderRadius: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 180, height: 16, borderRadius: 8),
                const SizedBox(height: 8),
                ShimmerBox(width: 120, height: 12, borderRadius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: 200, height: 11, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Product Grid Shimmer ───────────────────────────────────────────────────

class ProductGridShimmer extends StatelessWidget {
  final bool isSliver;

  const ProductGridShimmer({super.key, this.isSliver = true});

  @override
  Widget build(BuildContext context) {
    final content = ShimmerEffect(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.68,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => _buildProductCardShimmer(),
      ),
    );

    if (isSliver) {
      return SliverToBoxAdapter(child: content);
    }
    return content;
  }

  Widget _buildProductCardShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(
            height: 95,
            borderRadius: 20,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 50, height: 14, borderRadius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: double.infinity, height: 14, borderRadius: 6),
                const SizedBox(height: 4),
                ShimmerBox(width: 70, height: 11, borderRadius: 5),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 50, height: 15, borderRadius: 6),
                    ShimmerBox(
                      width: 28,
                      height: 28,
                      borderRadius: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Orders List Shimmer ────────────────────────────────────────────────────

class OrdersListShimmer extends StatelessWidget {
  final int itemCount;

  const OrdersListShimmer({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        itemCount: itemCount,
        itemBuilder: (context, index) => _buildOrderCardShimmer(),
      ),
    );
  }

  Widget _buildOrderCardShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 160, height: 14, borderRadius: 6),
                  const SizedBox(height: 6),
                  ShimmerBox(width: 120, height: 11, borderRadius: 5),
                ],
              ),
              ShimmerBox(width: 70, height: 24, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: 1, borderRadius: 0),
          const SizedBox(height: 16),
          // Item rows
          ...List.generate(2, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ShimmerBox(width: 38, height: 38, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 120, height: 13, borderRadius: 6),
                      const SizedBox(height: 4),
                      ShimmerBox(width: 80, height: 11, borderRadius: 5),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 100, height: 10, borderRadius: 4),
                  const SizedBox(height: 4),
                  ShimmerBox(width: 80, height: 13, borderRadius: 6),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShimmerBox(width: 90, height: 10, borderRadius: 4),
                  const SizedBox(height: 4),
                  ShimmerBox(width: 60, height: 16, borderRadius: 6),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Cart Items Shimmer ─────────────────────────────────────────────────────

class CartItemsShimmer extends StatelessWidget {
  final int itemCount;

  const CartItemsShimmer({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Column(
        children: List.generate(itemCount, (index) => _buildCartItemShimmer()),
      ),
    );
  }

  Widget _buildCartItemShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 64, height: 64, borderRadius: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 15, borderRadius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: 100, height: 11, borderRadius: 5),
                const SizedBox(height: 10),
                ShimmerBox(width: 60, height: 15, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShimmerBox(width: 36, height: 100, borderRadius: 14),
        ],
      ),
    );
  }
}

// ─── Products List Shimmer (for manage products page) ───────────────────────

class ProductsListShimmer extends StatelessWidget {
  final int itemCount;

  const ProductsListShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Column(
        children: List.generate(
          itemCount,
          (index) => _buildProductRowShimmer(),
        ),
      ),
    );
  }

  Widget _buildProductRowShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ShimmerBox(width: 60, height: 60, borderRadius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 14, borderRadius: 6),
                const SizedBox(height: 6),
                ShimmerBox(width: 90, height: 11, borderRadius: 5),
                const SizedBox(height: 6),
                ShimmerBox(width: 60, height: 14, borderRadius: 6),
              ],
            ),
          ),
          ShimmerBox(width: 32, height: 32, borderRadius: 8),
        ],
      ),
    );
  }
}

// ─── Order Detail Bottom Sheet Shimmer ───────────────────────────────────────

class OrderDetailShimmer extends StatelessWidget {
  const OrderDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 140, height: 22, borderRadius: 8),
                    const SizedBox(height: 6),
                    ShimmerBox(width: 180, height: 14, borderRadius: 6),
                  ],
                ),
                ShimmerBox(width: 80, height: 28, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 24),
            // Section card shimmer
            ...List.generate(3, (_) => _buildSectionShimmer()),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionShimmer() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 140, height: 12, borderRadius: 6),
          const SizedBox(height: 16),
          ...List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                ShimmerBox(width: 28, height: 28, borderRadius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 70, height: 10, borderRadius: 4),
                      const SizedBox(height: 4),
                      ShimmerBox(
                        width: double.infinity,
                        height: 13,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
