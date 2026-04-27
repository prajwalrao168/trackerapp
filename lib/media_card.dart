import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// FIX #1 — Removed flutter_dotenv. Using constants.dart for proxy config.
import 'app_theme.dart';
import 'constants.dart';
import 'details_screen.dart';
import 'list_provider.dart';

class FeaturedCard extends StatelessWidget {
  final dynamic item;
  final String Function(dynamic) gettitle;
  final String Function(dynamic) getimage;
  final String Function(dynamic) getdescription;
  final int Function(dynamic) getid;
  final int? Function(dynamic) gettotalepisodes;
  final int rank;
  final String mediatype;
  final String subtype;

  const FeaturedCard({
    super.key,
    required this.item,
    required this.gettitle,
    required this.getimage,
    required this.getdescription,
    required this.getid,
    required this.gettotalepisodes,
    required this.rank,
    required this.mediatype,
    required this.subtype,
  });

  @override
  Widget build(BuildContext context) {
    final title = gettitle(item);
    final imageurl = getimage(item);
    final description = getdescription(item);
    final herotag = 'featured_${mediatype}_${subtype}_${imageurl}_$rank';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailsScreen(
            title: title,
            imageurl: imageurl,
            description: description,
            herotag: herotag,
            mediatype: mediatype,
            subtype: subtype,
            apiid: getid(item),
            apitotalepisodes: gettotalepisodes(item),
          ),
        ),
      ),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: herotag,
                        child: imageurl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageurl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: kCard),
                              errorWidget: (context, url, error) => Container(color: kCard),
                            )
                          : Container(color: kCard),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$rank',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kTextPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegularCard extends StatelessWidget {
  final dynamic item;
  final String Function(dynamic) gettitle;
  final String Function(dynamic) getimage;
  final String Function(dynamic) getdescription;
  final int Function(dynamic) getid;
  final int? Function(dynamic) gettotalepisodes;
  final int index;
  final String mediatype;
  final String subtype;

  const RegularCard({
    super.key,
    required this.item,
    required this.gettitle,
    required this.getimage,
    required this.getdescription,
    required this.getid,
    required this.gettotalepisodes,
    required this.index,
    required this.mediatype,
    required this.subtype,
  });

  @override
  Widget build(BuildContext context) {
    final title = gettitle(item);
    final imageurl = getimage(item);
    final description = getdescription(item);
    final herotag = 'regular_${mediatype}_${subtype}_${imageurl}_$index';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailsScreen(
            title: title,
            imageurl: imageurl,
            description: description,
            herotag: herotag,
            mediatype: mediatype,
            subtype: subtype,
            apiid: getid(item),
            apitotalepisodes: gettotalepisodes(item),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: herotag,
              child: imageurl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageurl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: kCard),
                    errorWidget: (context, url, error) => Container(
                      color: kCard,
                      child: Icon(Icons.broken_image, color: kBorder, size: 20),
                    ),
                  )
                : Container(color: kCard),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.55, 1.0],
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 0, 7, 7),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget sectionheader(String label) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: kTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
      ],
    ),
  );
}

Widget buildMediaSection({
  required List<dynamic> data,
  required String Function(dynamic) gettitle,
  required String Function(dynamic) getimage,
  required String Function(dynamic) getdescription,
  required int Function(dynamic) getid,
  required int? Function(dynamic) gettotalepisodes,
  required String mediatype,
  required String subtype,
  ScrollController? controller,
  bool isloadingmore = false,
}) {
  final top50 = data.take(50).toList();
  final all = data.length > 50 ? data.skip(50).toList() : [];

  return CustomScrollView(
    controller: controller,
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(child: sectionheader('TOP 50')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 480,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: (top50.length / 3).ceil(),
            itemBuilder: (context, colIndex) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 110,
                  child: Column(
                    children: List.generate(3, (rowIndex) {
                      final dataIndex = colIndex * 3 + rowIndex;
                      if (dataIndex >= top50.length) return const SizedBox.shrink();
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: rowIndex < 2 ? 12 : 0),
                          child: FeaturedCard(
                            item: top50[dataIndex],
                            gettitle: gettitle,
                            getimage: getimage,
                            getdescription: getdescription,
                            getid: getid,
                            gettotalepisodes: gettotalepisodes,
                            rank: dataIndex + 1,
                            mediatype: mediatype,
                            subtype: subtype,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      SliverToBoxAdapter(child: sectionheader('ALL')),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => RegularCard(
              item: all[index],
              gettitle: gettitle,
              getimage: getimage,
              getdescription: getdescription,
              getid: getid,
              gettotalepisodes: gettotalepisodes,
              index: index + 50, 
              mediatype: mediatype,
              subtype: subtype,
            ),
            childCount: all.length,
          ),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 115,
            childAspectRatio: 0.62,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
        ),
      ),
      if (isloadingmore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
          ),
        ),
    ],
  );
}

class SavedMediaGrid extends StatefulWidget {
  final List<TrackedItem> items;

  const SavedMediaGrid({super.key, required this.items});

  @override
  State<SavedMediaGrid> createState() => _SavedMediaGridState();
}

class _SavedMediaGridState extends State<SavedMediaGrid> {
  TrackingStatus? selectedfilter;
  String sortmethod = 'alpha';
  int displaylimit = 20;
  final ScrollController scrollcontroller = ScrollController();

  // FIX #21 — Named method so it can be properly removed in dispose()
  void _onScroll() {
    if (scrollcontroller.position.pixels >= scrollcontroller.position.maxScrollExtent - 100) {
      setState(() => displaylimit += 20);
    }
  }

  @override
  void initState() {
    super.initState();
    scrollcontroller.addListener(_onScroll);
  }

  @override
  void dispose() {
    // FIX #21 — Remove named listener before disposing
    scrollcontroller.removeListener(_onScroll);
    scrollcontroller.dispose();
    super.dispose();
  }

  Color getstatuscolor(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.active: return Colors.greenAccent;
      case TrackingStatus.completed: return Colors.purpleAccent;
      case TrackingStatus.planning: return kAccent;
    }
  }

  String formatdate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void showquickeditsheet(BuildContext context, TrackedItem item) {
    final provider = Provider.of<ListProvider>(context, listen: false);
    TrackingStatus currentstatus = item.status;
    DateTime? currentstartdate = item.startdate;
    DateTime? currentenddate = item.enddate;
    int currentprogress = item.currentprogress;
    int totalprogress = item.totalprogress;
    double userrating = item.userrating;
    final TextEditingController notescontroller = TextEditingController(text: item.personalnotes);
    bool isfetching = false;

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
            if (totalprogress == 0 && item.apiid != 0 && !isfetching) {
              isfetching = true;
              if (item.mediatype == 'anime') {
                http.get(Uri.parse('https://api.jikan.moe/v4/anime/${item.apiid}')).then((res) {
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
              } else if (item.mediatype == 'cinema' && item.subtype == 'tv') {
                // FIX #1 — Use dedicated proxy route instead of passing TMDB key
                http.get(
                  Uri.parse('$kProxyBaseUrl/tmdb/tv/${item.apiid}'),
                  headers: {'X-API-Key': kProxyApiKey},
                ).then((res) {
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
              } else {
                  isfetching = false;
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Edit: ${item.title}',
                            style: TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () {
                            // FIX #10 — Pass mediatype + apiid for correct doc ID
                            provider.removeItem(item.title, mediatype: item.mediatype, apiid: item.apiid);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent, foregroundColor: Colors.black, elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          provider.saveItem(TrackedItem(
                            title: item.title, imageurl: item.imageurl, description: item.description, status: currentstatus,
                            startdate: currentstartdate, enddate: currentenddate, mediatype: item.mediatype, subtype: item.subtype,
                            currentprogress: currentprogress, totalprogress: totalprogress, apiid: item.apiid,
                            userrating: userrating, personalnotes: notescontroller.text.trim(),
                          ));
                          Navigator.pop(context);
                        },
                        child: const Text('Update Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) => notescontroller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          'Nothing saved here yet.',
          style: TextStyle(color: kTextSecondary, fontSize: 16),
        ),
      );
    }

    final provider = Provider.of<ListProvider>(context, listen: false);
    List<TrackedItem> filtereditems = selectedfilter == null
        ? widget.items.toList()
        : widget.items.where((i) => i.status == selectedfilter).toList();

    if (sortmethod == 'alpha') {
      filtereditems.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (sortmethod == 'alphareverse') {
      filtereditems.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    } else if (sortmethod == 'datestarted') {
      filtereditems.sort((a, b) {
        if (a.startdate == null && b.startdate == null) return 0;
        if (a.startdate == null) return 1;
        if (b.startdate == null) return -1;
        return a.startdate!.compareTo(b.startdate!);
      });
    } else if (sortmethod == 'datefinished') {
      filtereditems.sort((a, b) {
        if (a.enddate == null && b.enddate == null) return 0;
        if (a.enddate == null) return 1;
        if (b.enddate == null) return -1;
        return a.enddate!.compareTo(b.enddate!);
      });
    }

    List<TrackedItem> itemstodisplay = filtereditems.take(displaylimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 4),
                child: Row(
                  children: [
                    buildfilterchip('All', null),
                    buildfilterchip('Watching/Playing', TrackingStatus.active),
                    buildfilterchip('Completed', TrackingStatus.completed),
                    buildfilterchip('Planning', TrackingStatus.planning),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 8.0),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.sort_rounded, color: kTextPrimary),
                color: kSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  setState(() {
                    sortmethod = val;
                    displaylimit = 20;
                    scrollcontroller.jumpTo(0);
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'alpha',
                    child: Text('A-Z', style: TextStyle(color: sortmethod == 'alpha' ? kAccent : kTextPrimary)),
                  ),
                  PopupMenuItem(
                    value: 'alphareverse',
                    child: Text('Z-A', style: TextStyle(color: sortmethod == 'alphareverse' ? kAccent : kTextPrimary)),
                  ),
                  PopupMenuItem(
                    value: 'datestarted',
                    child: Text('Date Started', style: TextStyle(color: sortmethod == 'datestarted' ? kAccent : kTextPrimary)),
                  ),
                  PopupMenuItem(
                    value: 'datefinished',
                    child: Text('Date Finished', style: TextStyle(color: sortmethod == 'datefinished' ? kAccent : kTextPrimary)),
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: itemstodisplay.isEmpty
              ? Center(
                  child: Text(
                    'No items in this category.',
                    style: TextStyle(color: kTextSecondary, fontSize: 14),
                  ),
                )
              : GridView.builder(
                  controller: scrollcontroller,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: itemstodisplay.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 115,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final item = itemstodisplay[index];
                    final herotag = 'saved_${item.mediatype}_${item.subtype}_${item.imageurl}_$index';

                    final encodedurl = Uri.encodeComponent(item.imageurl);
                    final safeimageurl = (item.imageurl.contains('myanimelist') || item.imageurl.contains('freetogame')) && !item.imageurl.contains('onrender') 
                        ? '$kProxyBaseUrl/?url=$encodedurl' 
                        : item.imageurl;

                    return Dismissible(
                      key: Key(item.title),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 12),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                      ),
                      secondaryBackground: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 12),
                        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          HapticFeedback.lightImpact();
                          provider.saveItem(TrackedItem(
                            title: item.title,
                            imageurl: item.imageurl,
                            description: item.description,
                            status: TrackingStatus.completed,
                            startdate: item.startdate,
                            enddate: item.enddate,
                            mediatype: item.mediatype,
                            subtype: item.subtype,
                            currentprogress: item.currentprogress,
                            totalprogress: item.totalprogress,
                            apiid: item.apiid,
                            userrating: item.userrating,
                            personalnotes: item.personalnotes,
                          ));
                          return false; 
                        } else if (direction == DismissDirection.endToStart) {
                          HapticFeedback.mediumImpact();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: kSurface,
                              title: Text('Delete "${item.title}"?', style: TextStyle(color: kTextPrimary, fontSize: 16)),
                              content: Text('This will remove all your progress and notes. This cannot be undone.', style: TextStyle(color: kTextSecondary, fontSize: 14)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: kTextSecondary))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            provider.removeItem(item.title, mediatype: item.mediatype, apiid: item.apiid);
                            return true;
                          }
                          return false;
                        }
                        return false;
                      },
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailsScreen(
                              title: item.title,
                              imageurl: item.imageurl,
                              description: item.description,
                              herotag: herotag,
                              mediatype: item.mediatype,
                              subtype: item.subtype,
                              apiid: item.apiid,
                              apitotalepisodes: item.totalprogress,
                            ),
                          ),
                        ),
                        onLongPress: () => showquickeditsheet(context, item),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Hero(
                                tag: herotag,
                                child: safeimageurl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: safeimageurl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: kCard),
                                        errorWidget: (context, url, error) => Container(color: kCard),
                                      )
                                    : Container(color: kCard),
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0.55, 1.0],
                                    colors: [Colors.transparent, Color(0xCC000000)],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: getstatuscolor(item.status),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 16,
                                ),
                              ),
                              if (item.userrating > 0)
                                Positioned(
                                  top: 6,
                                  right: 24,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 12),
                                      const SizedBox(width: 2),
                                      Text(
                                        item.userrating.toStringAsFixed(1),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              if (item.currentprogress > 0 || item.totalprogress > 0)
                                Positioned(
                                  bottom: 28,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.currentprogress} / ${item.totalprogress == 0 ? '?' : item.totalprogress}',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              if (item.status == TrackingStatus.active)
                                Positioned(
                                  bottom: 28,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (item.totalprogress == 0 || item.currentprogress < item.totalprogress) {
                                        provider.saveItem(TrackedItem(
                                          title: item.title,
                                          imageurl: item.imageurl,
                                          description: item.description,
                                          status: item.status,
                                          startdate: item.startdate,
                                          enddate: item.enddate,
                                          mediatype: item.mediatype,
                                          subtype: item.subtype,
                                          currentprogress: item.currentprogress + 1,
                                          totalprogress: item.totalprogress,
                                          apiid: item.apiid,
                                          userrating: item.userrating,
                                          personalnotes: item.personalnotes,
                                        ));
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: kAccent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '+1',
                                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(7, 0, 7, 7),
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget buildfilterchip(String label, TrackingStatus? status) {
    final isSelected = selectedfilter == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedfilter = status;
          displaylimit = 20;
          if (scrollcontroller.hasClients) scrollcontroller.jumpTo(0);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kAccent : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kAccent : kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : kTextSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}