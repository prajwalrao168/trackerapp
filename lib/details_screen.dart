import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// FIX #1 — Removed flutter_dotenv. TMDB key now lives on the proxy server.
import 'app_theme.dart';
import 'constants.dart';
import 'list_provider.dart';

class DetailsScreen extends StatefulWidget {
  final String title;
  final String imageurl;
  final String description;
  final String herotag;
  final String mediatype;
  final String subtype;
  final int apiid;
  final int? apitotalepisodes;

  const DetailsScreen({
    super.key,
    required this.title,
    required this.imageurl,
    required this.description,
    required this.herotag,
    required this.mediatype,
    required this.subtype,
    required this.apiid,
    required this.apitotalepisodes,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool isloadingdetails = true;
  String developername = '';
  String apirating = '';
  List<Map<String, String>> castlist = [];

  @override
  void initState() {
    super.initState();
    fetchdetails();
  }

  Future<void> fetchdetails() async {
    if (widget.apiid == 0) {
      if (mounted) setState(() => isloadingdetails = false);
      return;
    }

    try {
      if (widget.mediatype == 'anime') {
        final r1 = await http.get(Uri.parse('https://api.jikan.moe/v4/anime/${widget.apiid}')).timeout(const Duration(seconds: 15));
        // Wait 400ms between Jikan requests to avoid 429 rate limiting
        await Future.delayed(const Duration(milliseconds: 400));
        final r2 = await http.get(Uri.parse('https://api.jikan.moe/v4/anime/${widget.apiid}/characters')).timeout(const Duration(seconds: 15));
        
        if (r1.statusCode == 200) {
          final d = json.decode(r1.body)['data'];
          if (mounted) {
            setState(() {
              developername = d['studios'] != null && d['studios'].isNotEmpty ? d['studios'][0]['name'] : '';
              apirating = d['score']?.toString() ?? '';
            });
          }
        }
        if (r2.statusCode == 200) {
          final d = json.decode(r2.body)['data'] as List;
          if (mounted) {
            setState(() {
              for (var c in d.take(12)) {
                castlist.add({
                  'name': c['character']?['name'] ?? '',
                  'image': c['character']?['images']?['jpg']?['image_url'] ?? '',
                });
              }
            });
          }
        }
      } else if (widget.mediatype == 'cinema') {
        // FIX #1 — Use dedicated proxy route instead of passing TMDB API key
        // through the generic proxy. The proxy adds the key server-side.
        final r = await http.get(
          Uri.parse('$kProxyBaseUrl/tmdb/${widget.subtype}/${widget.apiid}?append_to_response=credits'),
          headers: await getProxyHeaders(),
        ).timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          final d = json.decode(r.body);
          if (mounted) {
            setState(() {
              developername = d['production_companies'] != null && d['production_companies'].isNotEmpty ? d['production_companies'][0]['name'] : '';
              apirating = d['vote_average'] != null ? (d['vote_average'] as num).toStringAsFixed(1) : '';
              final clist = (d['credits']?['cast'] as List?) ?? [];
              for (var c in clist.take(12)) {
                castlist.add({
                  'name': c['name'] ?? '',
                  'image': c['profile_path'] != null ? 'https://image.tmdb.org/t/p/w200${c['profile_path']}' : '',
                });
              }
            });
          }
        }
      } else if (widget.mediatype == 'game') {
        // Use dedicated FreeToGame proxy route (GET / only allows images now)
        final r = await http.get(
          Uri.parse('$kProxyBaseUrl/freetogame/${widget.apiid}'),
          headers: await getProxyHeaders(),
        ).timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          final d = json.decode(r.body);
          if (mounted) {
            setState(() {
              developername = d['developer'] ?? '';
              apirating = ''; 
            });
          }
        }
      }
    } catch (e) {
      // FIX #19 — Log errors instead of silently swallowing them.
      debugPrint('fetchdetails error: $e');
    }

    if (mounted) {
      setState(() => isloadingdetails = false);
    }
  }

  String formatdate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void showtrackingsheet(BuildContext context, ListProvider provider) {
    // FIX #11 — Use apiid + mediatype for lookup instead of just title
    final existingitem = provider.getItem(widget.title, mediatype: widget.mediatype, apiid: widget.apiid);
    TrackingStatus currentstatus = existingitem?.status ?? TrackingStatus.planning;
    DateTime? currentstartdate = existingitem?.startdate;
    DateTime? currentenddate = existingitem?.enddate;
    int currentprogress = existingitem?.currentprogress ?? 0;
    double userrating = existingitem?.userrating ?? 0.0;
    final TextEditingController notescontroller = TextEditingController(text: existingitem?.personalnotes ?? '');
    
    int totalprogress = existingitem?.totalprogress != null && existingitem!.totalprogress > 0 
        ? existingitem.totalprogress 
        : (widget.apitotalepisodes ?? 0);
    bool isfetching = false;

    try {
      showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setsheetstate) {
            if (totalprogress == 0 && widget.apiid != 0 && !isfetching) {
              isfetching = true;
              if (widget.mediatype == 'anime') {
                http.get(Uri.parse('https://api.jikan.moe/v4/anime/${widget.apiid}')).timeout(const Duration(seconds: 15)).then((res) {
                  if (res.statusCode == 200) {
                    final data = json.decode(res.body)['data'];
                    if (context.mounted) {
                      setsheetstate(() {
                        totalprogress = data['episodes'] ?? 0;
                        isfetching = false;
                      });
                    }
                  }
                }).catchError((e) {
                   debugPrint('Anime episodes fetch error: $e');
                   if (context.mounted) setsheetstate(() => isfetching = false);
                });
              } else if (widget.mediatype == 'cinema' && widget.subtype == 'tv') {
                // FIX #1 — Use dedicated proxy route for TV details
                getProxyHeaders().then((headers) {
                  http.get(
                    Uri.parse('$kProxyBaseUrl/tmdb/tv/${widget.apiid}'),
                    headers: headers,
                  ).timeout(const Duration(seconds: 15)).then((res) {
                    if (res.statusCode == 200) {
                      final data = json.decode(res.body);
                      if (context.mounted) {
                        setsheetstate(() {
                          totalprogress = data['number_of_episodes'] ?? 0;
                          isfetching = false;
                        });
                      }
                    }
                  }).catchError((e) {
                     debugPrint('TV episodes fetch error: $e');
                     if (context.mounted) setsheetstate(() => isfetching = false);
                  });
                });
              } else {
                  isfetching = false;
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Track Media', style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Text('Status', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TrackingStatus>(
                          value: currentstatus,
                          isExpanded: true,
                          dropdownColor: kCard,
                          style: TextStyle(color: kTextPrimary, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: TrackingStatus.planning, child: Text('Planning to Watch/Play')),
                            DropdownMenuItem(value: TrackingStatus.active, child: Text('Watching/Playing')),
                            DropdownMenuItem(value: TrackingStatus.completed, child: Text('Completed')),
                          ],
                          onChanged: (val) {
                            if (val != null) setsheetstate(() => currentstatus = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context, initialDate: currentstartdate ?? DateTime.now(),
                                    firstDate: DateTime(2000), lastDate: DateTime(2100),
                                  );
                                  if (picked != null) setsheetstate(() => currentstartdate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                                  child: Text(
                                    currentstartdate != null ? formatdate(currentstartdate!) : 'Optional',
                                    style: TextStyle(color: currentstartdate != null ? kTextPrimary : kTextSecondary, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Date', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context, initialDate: currentenddate ?? DateTime.now(),
                                    firstDate: DateTime(2000), lastDate: DateTime(2100),
                                  );
                                  if (picked != null) setsheetstate(() => currentenddate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                                  child: Text(
                                    currentenddate != null ? formatdate(currentenddate!) : 'Optional',
                                    style: TextStyle(color: currentenddate != null ? kTextPrimary : kTextSecondary, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline_rounded, color: kAccent, size: 20),
                              onPressed: () {
                                if (currentprogress > 0) setsheetstate(() => currentprogress--);
                              },
                            ),
                            Text('$currentprogress', style: TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline_rounded, color: kAccent, size: 20),
                              onPressed: () {
                                if (totalprogress == 0 || currentprogress < totalprogress) {
                                  setsheetstate(() => currentprogress++);
                                }
                              },
                            ),
                            Text(' / ', style: TextStyle(color: kTextSecondary, fontSize: 16)),
                            isfetching 
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: kTextSecondary, strokeWidth: 2))
                              : Text(totalprogress > 0 ? '$totalprogress' : '?', style: TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your Rating', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                        Text('${userrating.toStringAsFixed(1)} / 10.0', style: TextStyle(color: kAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: userrating,
                      min: 0.0,
                      max: 10.0,
                      divisions: 100,
                      activeColor: kAccent,
                      inactiveColor: kCard,
                      onChanged: (val) {
                        setsheetstate(() => userrating = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Personal Notes', style: TextStyle(color: kTextSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notescontroller,
                      maxLines: 3,
                      style: TextStyle(color: kTextPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add your thoughts...',
                        hintStyle: TextStyle(color: kTextSecondary, fontSize: 14),
                        filled: true,
                        fillColor: kCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (existingitem != null)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withValues(alpha: 0.1), foregroundColor: Colors.redAccent, elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                // FIX #10 — Pass mediatype + apiid for correct doc ID
                                provider.removeItem(widget.title, mediatype: widget.mediatype, apiid: widget.apiid);
                                Navigator.pop(context);
                              },
                              child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        if (existingitem != null) const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent, foregroundColor: Colors.black, elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              provider.saveItem(TrackedItem(
                                title: widget.title, imageurl: widget.imageurl, description: widget.description, status: currentstatus,
                                startdate: currentstartdate, enddate: currentenddate, mediatype: widget.mediatype, subtype: widget.subtype,
                                currentprogress: currentprogress, totalprogress: totalprogress, apiid: widget.apiid,
                                userrating: userrating, personalnotes: notescontroller.text.trim(),
                              ));
                              Navigator.pop(context);
                            },
                            child: const Text('Save to List', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => notescontroller.dispose());
    } catch (e) {
      notescontroller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final encodedurl = Uri.encodeComponent(widget.imageurl);
    final safeimageurl = (widget.imageurl.contains('myanimelist') || widget.imageurl.contains('freetogame')) && !widget.imageurl.contains('onrender') 
        ? '$kProxyBaseUrl/?url=$encodedurl' 
        : widget.imageurl;

    final provider = Provider.of<ListProvider>(context);
    // FIX #11 — Use apiid + mediatype for reliable lookup
    final issaved = provider.isSaved(widget.title, mediatype: widget.mediatype, apiid: widget.apiid);

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: safeimageurl.isNotEmpty
                ? Opacity(
                    opacity: 0.15,
                    child: CachedNetworkImage(
                      imageUrl: safeimageurl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => ColoredBox(color: kBg),
                      errorWidget: (context, url, error) => ColoredBox(color: kBg),
                    ),
                  )
                : const SizedBox(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, kBg],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 20), onPressed: () => Navigator.pop(context)),
                        IconButton(
                          icon: Icon(issaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: issaved ? kAccent : kTextPrimary, size: 26),
                          onPressed: () => showtrackingsheet(context, provider),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: widget.herotag,
                          child: Container(
                            width: 130,
                            height: 195,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: safeimageurl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: safeimageurl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(color: kCard),
                                      errorWidget: (context, url, error) => Container(color: kCard, child: Icon(Icons.broken_image, color: kBorder, size: 30)),
                                    )
                                  : Container(color: kCard),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              Text(
                                widget.title,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                              ),
                              const SizedBox(height: 16),
                              if (isloadingdetails)
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))
                              else ...[
                                if (apirating.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        apirating,
                                        style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                if (apirating.isNotEmpty) const SizedBox(height: 8),
                                if (developername.isNotEmpty)
                                  Text(
                                    developername,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: issaved ? kSurface : kAccent,
                          foregroundColor: issaved ? kAccent : Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: issaved ? BorderSide(color: kAccent, width: 1.5) : BorderSide.none,
                          ),
                        ),
                        icon: Icon(issaved ? Icons.edit_rounded : Icons.add_rounded, size: 20),
                        label: Text(
                          issaved ? 'Update Progress' : 'Add to List',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        onPressed: () => showtrackingsheet(context, provider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(width: 3, height: 14, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        Text('SYNOPSIS', style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      widget.description.isNotEmpty ? widget.description : 'No description available.',
                      style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.7, letterSpacing: 0.2),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (castlist.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(width: 3, height: 14, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 10),
                          Text('CAST & CREW', style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: castlist.length,
                        itemBuilder: (context, index) {
                          final castmember = castlist[index];
                          return Container(
                            width: 76,
                            margin: const EdgeInsets.only(right: 14),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: kSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kBorder),
                                    image: castmember['image']!.isNotEmpty 
                                        ? DecorationImage(image: CachedNetworkImageProvider(castmember['image']!), fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: castmember['image']!.isEmpty ? Icon(Icons.person_rounded, color: kTextSecondary, size: 28) : null,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  castmember['name']!,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.w600, height: 1.2),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}