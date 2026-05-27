import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'constants.dart';
import 'media_card.dart';
import 'list_provider.dart';

class GamesListScreen extends StatefulWidget {
  final bool ismylist;

  const GamesListScreen({super.key, required this.ismylist});

  @override
  State<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends State<GamesListScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController scrollcontroller = ScrollController();
  List<dynamic> gamesdata = [];
  bool isloading = true;
  bool isloadingmore = false;
  String sortfilter = 'trending';
  int currentOffset = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollcontroller.addListener(_onScroll);
    if (!widget.ismylist) fetchgames();
  }

  void _onScroll() {
    if (scrollcontroller.position.pixels >= scrollcontroller.position.maxScrollExtent - 200) {
      _fetchMore();
    }
  }

  String _buildApicalypseQuery(int limit, int offset) {
    String whereClause = '';
    String sortClause = '';

    if (sortfilter == 'trending') {
      // Games released in the last 6 months with ratings — actually trending
      final sixMonthsAgo = (DateTime.now().subtract(const Duration(days: 180)).millisecondsSinceEpoch ~/ 1000);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      whereClause = 'where first_release_date != null & first_release_date >= $sixMonthsAgo & first_release_date <= $now & rating_count >= 5';
      sortClause = 'sort rating desc;';
    } else if (sortfilter == 'popular') {
      // All time best: high rating with enough votes to be meaningful
      whereClause = 'where rating != null & rating_count >= 100';
      sortClause = 'sort rating desc;';
    } else if (sortfilter == 'newest') {
      final currentUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      whereClause = 'where first_release_date != null & first_release_date <= $currentUnix';
      sortClause = 'sort first_release_date desc;';
    }

    return 'fields name, summary, cover.url; limit $limit; offset $offset; $whereClause $sortClause';
  }

  Future<void> fetchgames() async {
    setState(() { 
      isloading = true; 
      currentOffset = 0; 
    });
    
    try {
      String query = _buildApicalypseQuery(100, currentOffset);
      if (kDebugMode) debugPrint('SENDING QUERY: $query');

      final response = await http.post(
        Uri.parse('$kProxyBaseUrl/igdb/games'),
        headers: { 'Content-Type': 'application/json', 'X-API-Key': kProxyApiKey },
        body: json.encode({ 'query': query }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decodeddata = json.decode(response.body);
        
        // THIS IS THE SMOKING GUN! Check the console for this print statement:
        if (kDebugMode) debugPrint('IGDB SUCCESS: Found ${decodeddata.length} games!');

        if (mounted) {
          setState(() {
            gamesdata = decodeddata;
            currentOffset = 100;
            isloading = false;
          });
        }
      } else {
        if (kDebugMode) debugPrint('IGDB HTTP Error: ${response.statusCode} - ${response.body}');
        if (mounted) setState(() { isloading = false; });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FETCH GAMES CRASH: $e'); 
      if (mounted) setState(() { isloading = false; });
    }
  }

  Future<void> _fetchMore() async {
    if (isloadingmore) return;
    setState(() => isloadingmore = true);

    try {
      String query = _buildApicalypseQuery(50, currentOffset);

      final response = await http.post(
        Uri.parse('$kProxyBaseUrl/igdb/games'),
        headers: { 'Content-Type': 'application/json', 'X-API-Key': kProxyApiKey },
        body: json.encode({ 'query': query }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decodeddata = json.decode(response.body);
        if (mounted) {
          setState(() {
            gamesdata.addAll(decodeddata);
            currentOffset += 50;
            isloadingmore = false;
          });
        }
      } else {
        if (kDebugMode) debugPrint('IGDB FetchMore HTTP Error: ${response.statusCode} - ${response.body}');
        if (mounted) setState(() => isloadingmore = false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FETCH MORE CRASH: $e');
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
      final items = Provider.of<ListProvider>(context).items.where((i) => i.mediatype == 'game').toList();
      return SavedMediaGrid(items: items);
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: sortfilter,
                isExpanded: true,
                dropdownColor: kCard,
                icon: Icon(Icons.sort_rounded, color: kAccent, size: 20),
                style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                items: const [
                  DropdownMenuItem(value: 'trending', child: Text('Trending Right Now')),
                  DropdownMenuItem(value: 'newest', child: Text('Newly Released')),
                  DropdownMenuItem(value: 'popular', child: Text('All Time Best')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => sortfilter = val);
                    fetchgames();
                  }
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: isloading 
            ? Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))
            : gamesdata.isEmpty 
              ? Center(child: Text('Failed to load.', style: TextStyle(color: kTextSecondary)))
              : buildMediaSection(
                  data: gamesdata,
                  gettitle: (item) => item['name'] ?? 'Unknown',
                  getimage: (item) {
                    if (item['cover'] == null || item['cover']['url'] == null) return '';
                    String url = item['cover']['url'];
                    return 'https:' + url.replaceAll('t_thumb', 't_cover_big');
                  },
                  getdescription: (item) => item['summary'] ?? 'No description available.',
                  getid: (item) => item['id'] ?? 0,
                  gettotalepisodes: (item) => null,
                  mediatype: 'game',
                  subtype: 'none',
                  controller: scrollcontroller,
                  isloadingmore: isloadingmore,
                ),
        ),
      ],
    );
  }
}