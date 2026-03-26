import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 无限滚动列表组件（Sliver版本）
/// 
/// 当滚动到底部时自动加载更多数据
class InfiniteScrollSliverList extends StatelessWidget {
  final List<Widget> children;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback? onRefresh;
  final ScrollController? scrollController;
  final double? itemExtent;
  final double loadThreshold;

  const InfiniteScrollSliverList({
    super.key,
    required this.children,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    required this.onLoadMore,
    this.onRefresh,
    this.scrollController,
    this.itemExtent,
    this.loadThreshold = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo is ScrollEndNotification) {
          final metrics = scrollInfo.metrics;
          final threshold = metrics.maxScrollExtent * loadThreshold;
          
          if (metrics.pixels >= threshold) {
            if (hasMore && !isLoading && !isLoadingMore) {
              onLoadMore();
            }
          }
        }
        return false;
      },
      child: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == children.length) {
              return _buildLoadMoreIndicator();
            }
            return children[index];
          },
          childCount: children.length + (hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    } else if (hasMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text(
          '上拉加载更多',
          style: TextStyle(color: Colors.grey),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text(
          '没有更多了',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
  }
}

/// 无限滚动列表组件（ListView版本）
/// 
/// 当滚动到底部时自动加载更多数据
class InfiniteScrollList extends StatelessWidget {
  final List<Widget> children;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback? onRefresh;
  final ScrollController? scrollController;
  final double? itemExtent;
  final double loadThreshold;

  const InfiniteScrollList({
    super.key,
    required this.children,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    required this.onLoadMore,
    this.onRefresh,
    this.scrollController,
    this.itemExtent,
    this.loadThreshold = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo is ScrollEndNotification) {
          final metrics = scrollInfo.metrics;
          final threshold = metrics.maxScrollExtent * loadThreshold;
          
          if (metrics.pixels >= threshold) {
            if (hasMore && !isLoading && !isLoadingMore) {
              onLoadMore();
            }
          }
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh != null
            ? () async {
                onRefresh!();
              }
            : () async {},
        child: ListView.builder(
          controller: scrollController,
          itemExtent: itemExtent,
          cacheExtent: itemExtent != null ? itemExtent! * 3 : 300,
          itemCount: children.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == children.length) {
              return _buildLoadMoreIndicator();
            }
            return children[index];
          },
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    } else if (hasMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text(
          '上拉加载更多',
          style: TextStyle(color: Colors.grey),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text(
          '没有更多了',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
  }
}

/// 带有分割线的无限滚动列表
class InfiniteScrollListWithDivider extends StatelessWidget {
  final List<Widget> children;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback? onRefresh;
  final ScrollController? scrollController;
  final double? itemExtent;
  final double loadThreshold;
  final Widget? divider;

  const InfiniteScrollListWithDivider({
    super.key,
    required this.children,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    required this.onLoadMore,
    this.onRefresh,
    this.scrollController,
    this.itemExtent,
    this.loadThreshold = 0.8,
    this.divider,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo is ScrollEndNotification) {
          final metrics = scrollInfo.metrics;
          final threshold = metrics.maxScrollExtent * loadThreshold;
          
          if (metrics.pixels >= threshold) {
            if (hasMore && !isLoading && !isLoadingMore) {
              onLoadMore();
            }
          }
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh != null
            ? () async {
                onRefresh!();
              }
            : () async {},
        child: ListView.separated(
          controller: scrollController,
          cacheExtent: itemExtent != null ? itemExtent! * 3 : 300,
          itemCount: children.length + (hasMore ? 1 : 0),
          separatorBuilder: (context, index) => divider ?? const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == children.length) {
              return _buildLoadMoreIndicator();
            }
            return children[index];
          },
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    } else if (hasMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text(
          '上拉加载更多',
          style: TextStyle(color: Colors.grey),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Text(
          '没有更多了',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
  }
}
