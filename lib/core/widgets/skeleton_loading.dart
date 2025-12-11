import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmer skeleton loading widget for various content types
class SkeletonLoading extends StatelessWidget {
  final SkeletonType type;
  final int itemCount;

  const SkeletonLoading({
    super.key,
    required this.type,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: switch (type) {
        SkeletonType.pintList => _PintListSkeleton(itemCount: itemCount),
        SkeletonType.pubList => _PubListSkeleton(itemCount: itemCount),
        SkeletonType.leagueList => _LeagueListSkeleton(itemCount: itemCount),
        SkeletonType.friendList => _FriendListSkeleton(itemCount: itemCount),
        SkeletonType.homeScreen => const _HomeScreenSkeleton(),
        SkeletonType.card => const _CardSkeleton(),
        SkeletonType.statsRow => const _StatsRowSkeleton(),
      },
    );
  }
}

enum SkeletonType {
  pintList,
  pubList,
  leagueList,
  friendList,
  homeScreen,
  card,
  statsRow,
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;

  const _SkeletonCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PintListSkeleton extends StatelessWidget {
  final int itemCount;

  const _PintListSkeleton({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const _SkeletonCircle(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                          width: 120 + (index * 20).toDouble(),
                          height: 16,
                        ),
                        const SizedBox(height: 8),
                        const _SkeletonBox(width: 80, height: 12),
                      ],
                    ),
                  ),
                  const _SkeletonBox(width: 50, height: 24, borderRadius: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PubListSkeleton extends StatelessWidget {
  final int itemCount;

  const _PubListSkeleton({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: const _SkeletonCircle(size: 40),
              title: _SkeletonBox(
                width: 100 + (index * 15).toDouble(),
                height: 14,
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: _SkeletonBox(width: 150, height: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeagueListSkeleton extends StatelessWidget {
  final int itemCount;

  const _LeagueListSkeleton({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const _SkeletonBox(width: 56, height: 56, borderRadius: 12),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 140, height: 16),
                        SizedBox(height: 8),
                        _SkeletonBox(width: 100, height: 12),
                      ],
                    ),
                  ),
                  const _SkeletonBox(width: 24, height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendListSkeleton extends StatelessWidget {
  final int itemCount;

  const _FriendListSkeleton({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: const _SkeletonCircle(size: 48),
              title: _SkeletonBox(
                width: 90 + (index * 10).toDouble(),
                height: 14,
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 6),
                child: _SkeletonBox(width: 70, height: 12),
              ),
              trailing: const _SkeletonBox(width: 50, height: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeScreenSkeleton extends StatelessWidget {
  const _HomeScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _SkeletonCircle(size: 56),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 100, height: 12),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 140, height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Weekly stats
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SkeletonBox(width: 80, height: 16),
                      _SkeletonBox(width: 60, height: 24, borderRadius: 12),
                    ],
                  ),
                  SizedBox(height: 20),
                  _StatsRowSkeleton(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick actions
          const Row(
            children: [
              Expanded(child: _CardSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _CardSkeleton()),
            ],
          ),
          const SizedBox(height: 24),

          // Recent pints header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SkeletonBox(width: 100, height: 18),
              _SkeletonBox(width: 50, height: 14),
            ],
          ),
          const SizedBox(height: 12),

          // Recent pints
          const _PintListSkeleton(itemCount: 3),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _SkeletonCircle(size: 32),
            SizedBox(height: 12),
            _SkeletonBox(width: 60, height: 14),
          ],
        ),
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            _SkeletonCircle(size: 24),
            SizedBox(height: 8),
            _SkeletonBox(width: 30, height: 20),
            SizedBox(height: 4),
            _SkeletonBox(width: 40, height: 12),
          ],
        ),
        Column(
          children: [
            _SkeletonCircle(size: 24),
            SizedBox(height: 8),
            _SkeletonBox(width: 30, height: 20),
            SizedBox(height: 4),
            _SkeletonBox(width: 40, height: 12),
          ],
        ),
        Column(
          children: [
            _SkeletonCircle(size: 24),
            SizedBox(height: 8),
            _SkeletonBox(width: 30, height: 20),
            SizedBox(height: 4),
            _SkeletonBox(width: 40, height: 12),
          ],
        ),
      ],
    );
  }
}

