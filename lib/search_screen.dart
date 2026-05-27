import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
// FIX #1 — Removed flutter_dotenv import. TMDB key now lives on the proxy.
import 'app_theme.dart';
import 'constants.dart';
import 'details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController textcontroller = TextEditingController();
  final ScrollController scrollcontroller = ScrollController();
  List<dynamic> searchresults = [];
  bool isloading = false;
  bool isfetchingmore = false;
  bool hasmore = true;
  int currentpage = 1;
  String searchtype = 'anime';
  Timer? debouncetimer;
  // FIX #16 — Track whether the text field has content so the
  // clear button shows/hides instantly on every keystroke.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    scrollcontroller.addListener(_onScroll);
    textcontroller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasContent = textcontroller.text.isNotEmpty;
    if (hasContent != _hasText) {
      setState(() => _hasText = hasContent);
    }
  }

  void _onScroll() {
    if (scrollcontroller.position.pixels >= scrollcontroller.position.maxScrollExtent - 200) {
      _fetchMore();
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchresults = [];
        hasmore = true;
        currentpage = 1;
      });
      return;
    }

    setState(() {
      isloading = true;
      currentpage = 1;
      hasmore = true;
    });

    try {
      http.Response response;

      if (searchtype == 'game') {
        // Remove characters that could break/inject into an Apicalypse query
        String cleanQuery = query.replaceAll(RegExp(r'[";\\\/\n\r]'), '').trim();
        if (cleanQuery.isEmpty) {
          setState(() { isloading = false; });
          return;
        }
        String apicalypse = 'search "$cleanQuery"; fields name, summary, cover.url; limit 20; offset 0; where version_parent = null;';
        
        response = await http.post(
          Uri.parse('$kProxyBaseUrl/igdb/games'),
          // FIX #7 — Include API key for authenticated proxy requests
          headers: { 'Content-Type': 'application/json', 'X-API-Key': kProxyApiKey },
          body: json.encode({ 'query': apicalypse }),
        ).timeout(const Duration(seconds: 15));
      } else {
        String url = '';
        if (searchtype == 'anime') {
          // FIX #18 — URL-encode the query so special characters like
          // / & + # don't break the URL (e.g. "Fate/Stay Night")
          url = 'https://api.jikan.moe/v4/anime?q=${Uri.encodeComponent(query)}&page=$currentpage';
        } else if (searchtype == 'movie') {
          // FIX #1 — Route through proxy instead of calling TMDB directly
          // with the API key. The proxy adds the TMDB key server-side.
          url = '$kProxyBaseUrl/tmdb/search/movie?query=${Uri.encodeComponent(query)}&page=$currentpage';
        }
        if (searchtype == 'movie') {
          // FIX #7 — Include API key header for proxy requests
          response = await http.get(Uri.parse(url), headers: {'X-API-Key': kProxyApiKey}).timeout(const Duration(seconds: 15));
        } else {
          // Jikan is a free public API — no proxy or API key needed
          response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        }
      }

      if (response.statusCode == 200) {
        final decodeddata = json.decode(response.body);
        setState(() {
          if (searchtype == 'anime') {
            searchresults = decodeddata['data'] ?? [];
            hasmore = decodeddata['pagination']?['has_next_page'] ?? false;
          } else if (searchtype == 'movie') {
            searchresults = decodeddata['results'] ?? [];
            hasmore = currentpage < (decodeddata['total_pages'] ?? 1);
          } else if (searchtype == 'game') {
            searchresults = decodeddata is List ? decodeddata : [];
            hasmore = searchresults.length == 20;
          }
          isloading = false;
        });
      } else {
        setState(() { isloading = false; });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() { isloading = false; });
    }
  }

  Future<void> _fetchMore() async {
    if (isloading || isfetchingmore || !hasmore) return;

    setState(() { isfetchingmore = true; });
    currentpage++;

    try {
      http.Response response;

      if (searchtype == 'game') {
        int offset = (currentpage - 1) * 20;
        String cleanQuery = textcontroller.text.replaceAll(RegExp(r'[";\\\/\n\r]'), '').trim();
        if (cleanQuery.isEmpty) {
          setState(() { isfetchingmore = false; });
          return;
        }
        String apicalypse = 'search "$cleanQuery"; fields name, summary, cover.url; limit 20; offset $offset; where version_parent = null;';
        
        response = await http.post(
          Uri.parse('$kProxyBaseUrl/igdb/games'),
          headers: { 'Content-Type': 'application/json', 'X-API-Key': kProxyApiKey },
          body: json.encode({ 'query': apicalypse }),
        ).timeout(const Duration(seconds: 15));
      } else {
        String url = '';
        if (searchtype == 'anime') {
          // FIX #18 — URL-encode the query text
          url = 'https://api.jikan.moe/v4/anime?q=${Uri.encodeComponent(textcontroller.text)}&page=$currentpage';
        } else if (searchtype == 'movie') {
          // FIX #1 — Proxy route (no API key in URL)
          url = '$kProxyBaseUrl/tmdb/search/movie?query=${Uri.encodeComponent(textcontroller.text)}&page=$currentpage';
        }
        if (searchtype == 'movie') {
          response = await http.get(Uri.parse(url), headers: {'X-API-Key': kProxyApiKey}).timeout(const Duration(seconds: 15));
        } else {
          response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        }
      }

      if (response.statusCode == 200) {
        final decodeddata = json.decode(response.body);
        List<dynamic> newitems = [];
        
        if (searchtype == 'anime') {
          newitems = decodeddata['data'] ?? [];
          hasmore = decodeddata['pagination']?['has_next_page'] ?? false;
        } else if (searchtype == 'movie') {
          newitems = decodeddata['results'] ?? [];
          hasmore = currentpage < (decodeddata['total_pages'] ?? 1);
        } else if (searchtype == 'game') {
          newitems = decodeddata is List ? decodeddata : [];
          hasmore = newitems.length == 20;
        }

        setState(() {
          searchresults.addAll(newitems);
          if (newitems.isEmpty) hasmore = false;
          isfetchingmore = false;
        });
      } else {
        setState(() { isfetchingmore = false; hasmore = false; });
      }
    } catch (e) {
      debugPrint('FetchMore error: $e');
      setState(() { isfetchingmore = false; hasmore = false; });
    }
  }

  void _onSearchChanged(String query) {
    if (debouncetimer?.isActive ?? false) debouncetimer!.cancel();
    debouncetimer = Timer(const Duration(milliseconds: 500), () => _performSearch(query));
  }

  void _switchType(String type) {
    setState(() {
      searchtype = type;
      searchresults = [];
      currentpage = 1;
      hasmore = true;
    });
    if (textcontroller.text.isNotEmpty) _performSearch(textcontroller.text);
  }

  @override
  void dispose() {
    scrollcontroller.removeListener(_onScroll);
    scrollcontroller.dispose();
    debouncetimer?.cancel();
    textcontroller.removeListener(_onTextChanged);
    textcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search_rounded, color: kTextSecondary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: textcontroller,
                              autofocus: true,
                              style: TextStyle(color: kTextPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(color: kTextSecondary, fontSize: 15),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          if (_hasText)
                            GestureDetector(
                              onTap: () {
                                debouncetimer?.cancel();
                                textcontroller.clear();
                                setState(() {
                                  searchresults = [];
                                  currentpage = 1;
                                  hasmore = true;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(Icons.close_rounded, color: kTextSecondary, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    _typeButton('Anime', 'anime'),
                    _typeButton('Movies', 'movie'),
                    _typeButton('Games', 'game'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: isloading
                ? Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))
                : searchresults.isEmpty
                  ? _emptyState()
                  : ListView.separated(
                      controller: scrollcontroller,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: searchresults.length + (isfetchingmore ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(color: kBorder, height: 1),
                      itemBuilder: (context, index) {
                        if (index == searchresults.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
                          );
                        }

                        final item = searchresults[index];
                        
                        String title = 'Unknown';
                        if (searchtype == 'anime') {
                          title = item['title'] ?? 'Unknown';
                        } else {
                          title = item['title'] ?? item['name'] ?? 'Unknown';
                        }
                        
                        String imgpath = '';
                        if (searchtype == 'anime') {
                          final rawurl = item['images']?['jpg']?['large_image_url'] ?? '';
                          imgpath = rawurl.isNotEmpty ? '$kProxyBaseUrl/?url=${Uri.encodeComponent(rawurl)}' : '';
                        } else if (searchtype == 'movie') {
                          imgpath = item['poster_path'] != null ? 'https://image.tmdb.org/t/p/w200${item['poster_path']}' : '';
                        } else if (searchtype == 'game') {
                          if (item['cover'] != null && item['cover']['url'] != null) {
                            String url = item['cover']['url'];
                            imgpath = 'https:' + url.replaceAll('t_thumb', 't_cover_big');
                          }
                        }
                                
                        final description = item['synopsis'] ?? item['overview'] ?? item['summary'] ?? item['short_description'] ?? '';
                        final herotag = 'search_${imgpath}_$index';

                        String maintype = 'anime';
                        String subtype = 'tv';
                        int apiid = 0;
                        int? apitotalepisodes;

                        if (searchtype == 'anime') {
                          maintype = 'anime';
                          subtype = item['type']?.toString().toLowerCase() ?? 'tv';
                          apiid = item['mal_id'] ?? 0;
                          apitotalepisodes = item['episodes'];
                        } else if (searchtype == 'movie') {
                          maintype = 'cinema';
                          subtype = 'movie';
                          apiid = item['id'] ?? 0;
                          apitotalepisodes = 1;
                        } else if (searchtype == 'game') {
                          maintype = 'game';
                          subtype = 'none';
                          apiid = item['id'] ?? 0;
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          leading: Hero(
                            tag: herotag,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: imgpath.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imgpath,
                                    width: 44,
                                    height: 62,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(width: 44, height: 62, color: kCard),
                                    errorWidget: (context, url, error) => Container(
                                      width: 44,
                                      height: 62,
                                      color: kCard,
                                      child: Icon(Icons.image, color: kBorder, size: 18),
                                    ),
                                  )
                                : Container(width: 44, height: 62, color: kCard),
                            ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: kTextPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: description.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.4),
                                ),
                              )
                            : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailsScreen(
                                title: title,
                                imageurl: imgpath,
                                description: description,
                                herotag: herotag,
                                mediatype: maintype,
                                subtype: subtype,
                                apiid: apiid,
                                apitotalepisodes: apitotalepisodes,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_rounded,
            size: 52,
            color: kTextSecondary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            textcontroller.text.isEmpty ? 'Search for something' : 'No results found',
            style: TextStyle(color: kTextSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String label, String type) {
    final isSelected = searchtype == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? kAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : kTextSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}