import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

class DownloadProvider extends ChangeNotifier {
  late StreamSubscription subscription;
  bool isConnected = false;

  checkInternetConnection() {
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      checkStatus();
    });
  }

  checkInternetConnectionCansel() {
    subscription.cancel();
  }

  void checkStatus() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      isConnected = true;
      notifyListeners();
    } else if (connectivityResult == ConnectivityResult.none) {
      isConnected = false;
      notifyListeners();
    }
  }

  String? _currentStore = 'Map';

  String? get currentStore => _currentStore;

  set currentStore(String? newStore) {
    _currentStore = newStore;
    notifyListeners();
  }

  final StreamController<void> resetController = StreamController.broadcast();

  void resetMap() => resetController.add(null);

  BaseRegion? _region;

  BaseRegion? get region => _region;

  set region(BaseRegion? newRegion) {
    _region = newRegion;
    notifyListeners();
  }

  int? _regionTiles;

  int? get regionTiles => _regionTiles;

  set regionTiles(int? newNum) {
    _regionTiles = newNum;
    notifyListeners();
  }

  int _minZoom = 1;

  int get minZoom => _minZoom;

  set minZoom(int newNum) {
    _minZoom = newNum;
    notifyListeners();
  }

  int _maxZoom = 19;

  int get maxZoom => _maxZoom;

  set maxZoom(int newNum) {
    _maxZoom = newNum;
    notifyListeners();
  }

  LatLng _center = LatLng(45, 64.5);

  LatLng get center => _center;

  set center(LatLng newCenter) {
    _center = newCenter;
    notifyListeners();
  }

  StoreDirectory? _selectedStore;

  StoreDirectory? get selectedStore => _selectedStore;

  void setSelectedStore(StoreDirectory? newStore, {bool notify = true}) {
    _selectedStore = newStore;
    if (notify) notifyListeners();
  }

  final StreamController<void> _manualPolygonRecalcTrigger =
      StreamController.broadcast();

  StreamController<void> get manualPolygonRecalcTrigger =>
      _manualPolygonRecalcTrigger;

  void triggerManualPolygonRecalc() => _manualPolygonRecalcTrigger.add(null);

  Stream<DownloadProgress>? _downloadProgress;

  Stream<DownloadProgress>? get downloadProgress => _downloadProgress;

  void setDownloadProgress(
    Stream<DownloadProgress>? newStream, {
    bool notify = true,
  }) {
    _downloadProgress = newStream;
    if (notify) notifyListeners();
  }

  bool _preventRedownload = false;

  bool get preventRedownload => _preventRedownload;

  set preventRedownload(bool newBool) {
    _preventRedownload = newBool;
    notifyListeners();
  }

  bool _seaTileRemoval = true;

  bool get seaTileRemoval => _seaTileRemoval;

  set seaTileRemoval(bool newBool) {
    _seaTileRemoval = newBool;
    notifyListeners();
  }

  bool _disableRecovery = false;

  bool get disableRecovery => _disableRecovery;

  set disableRecovery(bool newBool) {
    _disableRecovery = newBool;
    notifyListeners();
  }
}
