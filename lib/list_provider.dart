import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum TrackingStatus { planning, active, completed }

class TrackedItem {
  final String title;
  final String imageurl;
  final String description;
  final TrackingStatus status;
  final DateTime? startdate;
  final DateTime? enddate;
  final String mediatype;
  final String subtype;
  final int currentprogress;
  final int totalprogress;
  final int apiid;
  final double userrating;
  final String personalnotes;

  TrackedItem({
    required this.title,
    required this.imageurl,
    required this.description,
    required this.status,
    this.startdate,
    this.enddate,
    required this.mediatype,
    required this.subtype,
    this.currentprogress = 0,
    this.totalprogress = 0,
    this.apiid = 0,
    this.userrating = 0.0,
    this.personalnotes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageurl,
      'description': description,
      'status': status.name,
      'startDate': startdate?.toIso8601String(),
      'endDate': enddate?.toIso8601String(),
      'mediaType': mediatype,
      'subType': subtype,
      'currentprogress': currentprogress,
      'totalprogress': totalprogress,
      'apiid': apiid,
      'userrating': userrating,
      'personalnotes': personalnotes,
    };
  }

  factory TrackedItem.fromMap(Map<String, dynamic> map) {
    return TrackedItem(
      title: map['title'] ?? '',
      imageurl: map['imageUrl'] ?? map['imageurl'] ?? '',
      description: map['description'] ?? '',
      status: TrackingStatus.values.firstWhere(
        (e) => e.name == map['status'], 
        orElse: () => TrackingStatus.planning,
      ),
      startdate: DateTime.tryParse(map['startDate'] ?? map['startdate'] ?? ''),
      enddate: DateTime.tryParse(map['endDate'] ?? map['enddate'] ?? ''),
      mediatype: map['mediaType'] ?? map['mediatype'] ?? '',
      subtype: map['subType'] ?? map['subtype'] ?? '',
      currentprogress: map['currentprogress'] ?? 0,
      totalprogress: map['totalprogress'] ?? 0,
      apiid: map['apiid'] ?? 0,
      userrating: (map['userrating'] as num?)?.toDouble() ?? 0.0,
      personalnotes: map['personalnotes'] ?? '',
    );
  }
}

class ListProvider extends ChangeNotifier {
  List<TrackedItem> itemsdata = [];
  List<TrackedItem> get items => itemsdata;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _itemsSubscription;

  ListProvider() {
    _listenToAuth();
  }

  void _listenToAuth() {
    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          if (user != null) {
            _fetchItems(user.uid);
          } else {
            _itemsSubscription?.cancel();
            _itemsSubscription = null;
            itemsdata.clear();
            Future.microtask(() => notifyListeners());
          }
        },
        onError: (error) {
          debugPrint('Auth listen error: $error');
        },
      );
    } catch (e) {
      debugPrint('Auth init error: $e');
    }
  }

  void _fetchItems(String uid) {
    _itemsSubscription?.cancel();
    // FIX #13 — Clear old user's data immediately so it doesn't
    // flash on screen while the new subscription is loading
    itemsdata.clear();
    try {
      _itemsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tracked_items')
          .snapshots()
          .listen(
            (snapshot) {
              itemsdata = snapshot.docs.map((doc) => TrackedItem.fromMap(doc.data())).toList();
              Future.microtask(() => notifyListeners());
            },
            onError: (error) {
              debugPrint('Firestore listen error: $error');
            },
          );
    } catch (e) {
      debugPrint('Firestore init error: $e');
    }
  }

  // FIX #10 — Generate a unique document ID using mediatype + apiid.
  // This prevents different media with the same title from overwriting
  // each other (e.g. "Dragon Ball" anime vs "Dragon Ball" game).
  // Falls back to sanitized title for items with no API ID.
  String _getDocId(String title, String mediatype, int apiid) {
    if (apiid > 0 && mediatype.isNotEmpty) {
      return '${mediatype}_$apiid';
    }
    return title.replaceAll(RegExp(r'[/\\.]'), '_');
  }

  // FIX #11 — Match by apiid + mediatype (unique identifier) instead of
  // just title text. Falls back to title matching for items without apiid.
  TrackedItem? getItem(String title, {String mediatype = '', int apiid = 0}) {
    try {
      if (apiid > 0 && mediatype.isNotEmpty) {
        return itemsdata.firstWhere(
          (item) => item.apiid == apiid && item.mediatype == mediatype,
        );
      }
      return itemsdata.firstWhere((item) => item.title == title);
    } catch (e) {
      return null;
    }
  }

  // FIX #11 — Same apiid-based matching for isSaved check.
  bool isSaved(String title, {String mediatype = '', int apiid = 0}) {
    if (apiid > 0 && mediatype.isNotEmpty) {
      return itemsdata.any((item) => item.apiid == apiid && item.mediatype == mediatype);
    }
    return itemsdata.any((item) => item.title == title);
  }

  Future<void> saveItem(TrackedItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Save failed: User not authenticated');
      return;
    }

    // FIX #10 — Use mediatype + apiid for unique doc IDs
    final docid = _getDocId(item.title, item.mediatype, item.apiid);
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tracked_items')
        .doc(docid)
        .set(item.toMap());
  }

  // FIX #10 — removeItem now takes mediatype + apiid to generate the
  // correct document ID, matching the same logic used in saveItem.
  Future<void> removeItem(String title, {String mediatype = '', int apiid = 0}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Remove failed: User not authenticated');
      return;
    }

    final docid = _getDocId(title, mediatype, apiid);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tracked_items')
        .doc(docid)
        .delete();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _itemsSubscription?.cancel();
    super.dispose();
  }
}