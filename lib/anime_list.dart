import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'constants.dart';
import 'media_card.dart';
import 'list_provider.dart';

class AnimeListScreen extends StatefulWidget {
  final bool isMyList;

  const AnimeListScreen({super.key, required this.isMyList});

  @override
  State<AnimeListScreen> createState() => _AnimeListScreenState();
}

class _AnimeListScreenState extends State<AnimeListScreen> {
  String _sortFilter = 'trending';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          if (!widget.isMyList)
            _FilterDropdown(
              value: _sortFilter,
              onChanged: (val) => setState(() => _sortFilter = val),
            ),
          const TabBar(
            tabs: [
              Tab(text: 'TV Shows'),
              Tab(text: 'Movies'),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                AnimeGrid(apitype: 'tv', ismylist: widget.isMyList, sortFilter: _sortFilter),
                AnimeGrid(apitype: 'movie', ismylist: widget.isMyList, sortFilter: _sortFilter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: kCard,
            icon: Icon(Icons.sort_rounded, color: kAccent, size: 20),
            style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            items: const [
              DropdownMenuItem(value: 'trending', child: Text('Trending Right Now')),
              DropdownMenuItem(value: 'newly_released', child: Text('Newly Released')),
              DropdownMenuItem(value: 'all_time', child: Text('All Time Best')),
            ],
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ),
      ),
    );
  }
}

class AnimeGrid extends StatefulWidget {
  final String apitype;
  final bool ismylist;
  final String sortFilter;

  const AnimeGrid({super.key, required this.apitype, required this.ismylist, required this.sortFilter});

  @override
  State<AnimeGrid> createState() => _AnimeGridState();
}

class _AnimeGridState extends State<AnimeGrid>
    with AutomaticKeepAliveClientMixin {
  final ScrollController scrollcontroller = ScrollController();

  List<dynamic> animedata = [];
  bool isloading = true;
  bool isloadingmore = false;
  bool hasError = false;
  bool hasmore = true;

  int currentpage = 1;
  String _activeSortFilter = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollcontroller.addListener(_onScroll);
    if (!widget.ismylist) {
      _activeSortFilter = widget.sortFilter;
      _initialFetch();
    }
  }

  @override
  void didUpdateWidget(covariant AnimeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.ismylist && widget.sortFilter != _activeSortFilter) {
      _activeSortFilter = widget.sortFilter;
      _refetchWithFilter();
    }
  }

  void _onScroll() {
    if (scrollcontroller.position.pixels >=
        scrollcontroller.position.maxScrollExtent - 200) {
      _fetchMore();
    }
  }

  String _buildUrl(int page) {
    switch (_activeSortFilter) {
      case 'trending':
        return 'https://api.jikan.moe/v4/top/anime?type=${widget.apitype}&filter=airing&page=$page';
      case 'newly_released':
        return 'https://api.jikan.moe/v4/seasons/now?filter=${widget.apitype}&page=$page';
      case 'all_time':
      default:
        return 'https://api.jikan.moe/v4/top/anime?type=${widget.apitype}&page=$page';
    }
  }

  Future<http.Response?> safeGet(Uri url, {int retries = 2}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        final res = await http.get(url).timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) return res;

        if ((res.statusCode >= 500 || res.statusCode == 429) && i < retries) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
          continue;
        }

        return res;
      } catch (e) {
        if (i < retries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return null;
      }
    }
    return null;
  }

  Future<void> _refetchWithFilter() async {
    if (mounted) {
      setState(() {
        isloading = true;
        hasError = false;
        animedata = [];
        currentpage = 1;
        hasmore = true;
      });
    }
    await _initialFetch();
  }

  Future<void> _initialFetch() async {
    try {
      List<dynamic> combined = [];

      // Load 4 pages (25 items each = 100 total) so the ALL grid section
      // has enough content to make the page scrollable on mobile.
      for (int page = 1; page <= 4; page++) {
        if (page > 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }

        final url = Uri.parse(_buildUrl(page));

        final res = await safeGet(url);

        if (res != null && res.statusCode == 200) {
          combined.addAll(json.decode(res.body)['data']);
        }
      }

      if (mounted) {
        setState(() {
          animedata = combined;
          isloading = false;
          hasError = combined.isEmpty;
          currentpage = 5;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isloading = false;
          hasError = true;
        });
      }
    }
  }

  Future<void> _fetchMore() async {
    if (isloadingmore || !hasmore) return;

    setState(() => isloadingmore = true);

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final url = Uri.parse(_buildUrl(currentpage));

      final response = await safeGet(url);

      if (response != null && response.statusCode == 200) {
        final decodeddata = json.decode(response.body);
        final newItems = decodeddata['data'] ?? [];
        final hasNextPage = decodeddata['pagination']?['has_next_page'] ?? false;

        if (mounted) {
          setState(() {
            animedata.addAll(newItems);
            currentpage++;
            hasmore = hasNextPage && newItems.isNotEmpty;
          });
        }
      }
    } catch (e) {
      // FIX #19 — Log the error instead of silently swallowing it
      debugPrint('Anime fetchMore error: $e');
    }

    if (mounted) {
      setState(() => isloadingmore = false);
    }
  }

  @override
  void dispose() {
    scrollcontroller.removeListener(_onScroll);
    scrollcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.ismylist) {
      final items = Provider.of<ListProvider>(context)
          .items
          .where((i) =>
              i.mediatype == 'anime' &&
              (i.subtype == widget.apitype ||
                  (widget.apitype == 'tv' && i.subtype != 'movie')))
          .toList();

      return SavedMediaGrid(items: items);
    }

    if (isloading) {
      return Center(
        child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
      );
    }

    if (hasError) {
      return Center(
        child: Text(
          'Server is temporarily down.\nPlease try again later.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextSecondary),
        ),
      );
    }

    return buildMediaSection(
      data: animedata,
      gettitle: (item) => item['title'] ?? 'Unknown',
      getimage: (item) {
        final rawurl =
            item['images']?['jpg']?['large_image_url'] ?? '';
        return rawurl.isNotEmpty
            ? '$kProxyBaseUrl/?url=${Uri.encodeComponent(rawurl)}'
            : '';
      },
      getdescription: (item) =>
          item['synopsis'] ?? 'No description available.',
      getid: (item) => item['mal_id'] ?? 0,
      gettotalepisodes: (item) => item['episodes'],
      mediatype: 'anime',
      subtype: widget.apitype,
      controller: scrollcontroller,
      isloadingmore: isloadingmore,
    );
  }
}