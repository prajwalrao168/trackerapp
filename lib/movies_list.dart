import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'constants.dart';
import 'media_card.dart';
import 'list_provider.dart';

class MoviesListScreen extends StatefulWidget {
  final bool ismylist;

  const MoviesListScreen({super.key, required this.ismylist});

  @override
  State<MoviesListScreen> createState() => _MoviesListScreenState();
}

class _MoviesListScreenState extends State<MoviesListScreen> {
  String _sortFilter = 'trending';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          if (!widget.ismylist)
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
                TvShowsGrid(ismylist: widget.ismylist, sortFilter: _sortFilter),
                MoviesGrid(ismylist: widget.ismylist, sortFilter: _sortFilter),
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
              DropdownMenuItem(value: 'top_rated', child: Text('All Time Best')),
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

// ═══════════════════════════════════════════════
// TV SHOWS GRID
// ═══════════════════════════════════════════════

class TvShowsGrid extends StatefulWidget {
  final bool ismylist;
  final String sortFilter;
  const TvShowsGrid({super.key, required this.ismylist, required this.sortFilter});

  @override
  State<TvShowsGrid> createState() => _TvShowsGridState();
}

class _TvShowsGridState extends State<TvShowsGrid> with AutomaticKeepAliveClientMixin {
  final ScrollController scrollcontroller = ScrollController();
  List<dynamic> showsdata = [];
  bool isloading = true;
  bool isloadingmore = false;
  bool hasError = false;
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
  void didUpdateWidget(covariant TvShowsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.ismylist && widget.sortFilter != _activeSortFilter) {
      _activeSortFilter = widget.sortFilter;
      _refetchWithFilter();
    }
  }

  void _onScroll() {
    if (scrollcontroller.position.pixels >= scrollcontroller.position.maxScrollExtent - 200) {
      _fetchMore();
    }
  }

  String _buildEndpoint(int page) {
    switch (_activeSortFilter) {
      case 'trending':
        return '$kProxyBaseUrl/tmdb/trending/tv/week?page=$page';
      case 'newly_released':
        final today = DateTime.now();
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        return '$kProxyBaseUrl/tmdb/discover/tv?sort_by=first_air_date.desc&first_air_date.lte=$dateStr&vote_count.gte=10&page=$page';
      case 'top_rated':
        return '$kProxyBaseUrl/tmdb/tv/top_rated?page=$page';
      default:
        return '$kProxyBaseUrl/tmdb/tv/popular?page=$page';
    }
  }

  Future<void> _refetchWithFilter() async {
    if (mounted) {
      setState(() {
        isloading = true;
        hasError = false;
        showsdata = [];
        currentpage = 1;
      });
    }
    await _initialFetch();
  }

  Future<void> _initialFetch() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(_buildEndpoint(1)), headers: {'X-API-Key': kProxyApiKey}).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse(_buildEndpoint(2)), headers: {'X-API-Key': kProxyApiKey}).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse(_buildEndpoint(3)), headers: {'X-API-Key': kProxyApiKey}).timeout(const Duration(seconds: 15)),
      ]);

      List<dynamic> combined = [];
      for (var res in responses) {
        if (res.statusCode == 200) {
          combined.addAll(json.decode(res.body)['results']);
        }
      }

      if (mounted) {
        setState(() {
          showsdata = combined;
          isloading = false;
          currentpage = 4;
        });
      }
    } catch (e) {
      if (mounted) setState(() { isloading = false; hasError = true; });
    }
  }

  Future<void> _fetchMore() async {
    if (isloadingmore) return;
    setState(() => isloadingmore = true);

    try {
      final response = await http.get(
        Uri.parse(_buildEndpoint(currentpage)),
        headers: {'X-API-Key': kProxyApiKey},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decodeddata = json.decode(response.body);
        if (mounted) {
          setState(() {
            showsdata.addAll(decodeddata['results']);
            isloadingmore = false;
            currentpage++;
          });
        }
      } else {
        if (mounted) setState(() => isloadingmore = false);
      }
    } catch (e) {
      if (mounted) setState(() => isloadingmore = false);
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
      final items = Provider.of<ListProvider>(context).items.where((i) => i.mediatype == 'cinema' && i.subtype == 'tv').toList();
      return SavedMediaGrid(items: items);
    }

    if (isloading) {
      return Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2));
    }

    if (showsdata.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasError ? Icons.wifi_off_rounded : Icons.movie_filter_rounded, color: kTextSecondary, size: 48),
            const SizedBox(height: 12),
            Text(hasError ? 'Failed to load. Check your connection.' : 'No shows found.', style: TextStyle(color: kTextSecondary, fontSize: 14)),
            if (hasError) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.black),
                onPressed: () { setState(() { hasError = false; isloading = true; }); _initialFetch(); },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }

    return buildMediaSection(
      data: showsdata,
      gettitle: (item) => item['name'] ?? item['title'] ?? 'Unknown',
      getimage: (item) => item['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${item['poster_path']}' : '',
      getdescription: (item) => item['overview'] ?? 'No description available.',
      getid: (item) => item['id'] ?? 0,
      gettotalepisodes: (item) => null,
      mediatype: 'cinema',
      subtype: 'tv',
      controller: scrollcontroller,
      isloadingmore: isloadingmore,
    );
  }
}

// ═══════════════════════════════════════════════
// MOVIES GRID
// ═══════════════════════════════════════════════

class MoviesGrid extends StatefulWidget {
  final bool ismylist;
  final String sortFilter;
  const MoviesGrid({super.key, required this.ismylist, required this.sortFilter});

  @override
  State<MoviesGrid> createState() => _MoviesGridState();
}

class _MoviesGridState extends State<MoviesGrid> with AutomaticKeepAliveClientMixin {
  final ScrollController scrollcontroller = ScrollController();
  List<dynamic> moviesdata = [];
  bool isloading = true;
  bool isloadingmore = false;
  bool hasError = false;
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
  void didUpdateWidget(covariant MoviesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.ismylist && widget.sortFilter != _activeSortFilter) {
      _activeSortFilter = widget.sortFilter;
      _refetchWithFilter();
    }
  }

  void _onScroll() {
    if (scrollcontroller.position.pixels >= scrollcontroller.position.maxScrollExtent - 200) {
      _fetchMore();
    }
  }

  String _buildEndpoint(int page) {
    switch (_activeSortFilter) {
      case 'trending':
        return '$kProxyBaseUrl/tmdb/trending/movie/week?page=$page';
      case 'newly_released':
        final today = DateTime.now();
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        return '$kProxyBaseUrl/tmdb/discover/movie?sort_by=release_date.desc&release_date.lte=$dateStr&vote_count.gte=10&page=$page';
      case 'top_rated':
        return '$kProxyBaseUrl/tmdb/movie/top_rated?page=$page';
      default:
        return '$kProxyBaseUrl/tmdb/movie/popular?page=$page';
    }
  }

  Future<void> _refetchWithFilter() async {
    if (mounted) {
      setState(() {
        isloading = true;
        hasError = false;
        moviesdata = [];
        currentpage = 1;
      });
    }
    await _initialFetch();
  }

  Future<void> _initialFetch() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(_buildEndpoint(1)), headers: {'X-API-Key': kProxyApiKey}).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse(_buildEndpoint(2)), headers: {'X-API-Key': kProxyApiKey}).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse(_buildEndpoint(3)), headers: {'X-API-Key': kProxyApiKey}).timeout(const Duration(seconds: 15)),
      ]);

      List<dynamic> combined = [];
      for (var res in responses) {
        if (res.statusCode == 200) {
          combined.addAll(json.decode(res.body)['results']);
        }
      }

      if (mounted) {
        setState(() {
          moviesdata = combined;
          isloading = false;
          currentpage = 4;
        });
      }
    } catch (e) {
      if (mounted) setState(() { isloading = false; hasError = true; });
    }
  }

  Future<void> _fetchMore() async {
    if (isloadingmore) return;
    setState(() => isloadingmore = true);

    try {
      final response = await http.get(
        Uri.parse(_buildEndpoint(currentpage)),
        headers: {'X-API-Key': kProxyApiKey},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decodeddata = json.decode(response.body);
        if (mounted) {
          setState(() {
            moviesdata.addAll(decodeddata['results']);
            isloadingmore = false;
            currentpage++;
          });
        }
      } else {
        if (mounted) setState(() => isloadingmore = false);
      }
    } catch (e) {
      if (mounted) setState(() => isloadingmore = false);
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
      final items = Provider.of<ListProvider>(context).items.where((i) => i.mediatype == 'cinema' && i.subtype == 'movie').toList();
      return SavedMediaGrid(items: items);
    }

    if (isloading) {
      return Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2));
    }

    if (moviesdata.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasError ? Icons.wifi_off_rounded : Icons.movie_filter_rounded, color: kTextSecondary, size: 48),
            const SizedBox(height: 12),
            Text(hasError ? 'Failed to load. Check your connection.' : 'No movies found.', style: TextStyle(color: kTextSecondary, fontSize: 14)),
            if (hasError) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.black),
                onPressed: () { setState(() { hasError = false; isloading = true; }); _initialFetch(); },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }

    return buildMediaSection(
      data: moviesdata,
      gettitle: (item) => item['title'] ?? item['name'] ?? 'Unknown',
      getimage: (item) => item['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${item['poster_path']}' : '',
      getdescription: (item) => item['overview'] ?? 'No description available.',
      getid: (item) => item['id'] ?? 0,
      gettotalepisodes: (item) => 1,
      mediatype: 'cinema',
      subtype: 'movie',
      controller: scrollcontroller,
      isloadingmore: isloadingmore,
    );
  }
}