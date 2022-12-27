import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_offline_map/pages/home_page.dart';
import 'package:flutter_offline_map/viewmodel/download_viewmodel.dart';
import 'package:latlong2/latlong.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_transform/stream_transform.dart';

class DownloadMapPage extends StatefulWidget {
  static const String id = "download_map_page";

  @override
  State<DownloadMapPage> createState() => _DownloadMapPageState();
}

class _DownloadMapPageState extends State<DownloadMapPage> {
  static const double _shapePadding = 15;
  static const _crosshairsMovement = Point<double>(10, 10);

  final _mapKey = GlobalKey<State<StatefulWidget>>();
  final MapController _mapController = MapController();

  late final StreamSubscription _polygonVisualizerStream;
  late final StreamSubscription _tileCounterTriggerStream;
  late final StreamSubscription _manualPolygonRecalcTriggerStream;

  Point<double>? _crosshairsTop;
  Point<double>? _crosshairsBottom;
  LatLng? _coordsTopLeft;
  LatLng? _coordsBottomRight;
  double? progress;
  String percent = "0";
  bool isVisible = false;
  bool isDownloaded = false;
  var center;
  var minZoom;

  PolygonLayer _buildTargetPolygon(BaseRegion region) => PolygonLayer(
        polygons: [
          Polygon(
            points: [
              LatLng(-90, 180),
              LatLng(90, 180),
              LatLng(90, -180),
              LatLng(-90, -180),
            ],
            holePointsList: [region.toList()],
            isFilled: true,
            borderColor: Colors.black,
            borderStrokeWidth: 2,
            color: Colors.white.withOpacity(2 / 3),
          ),
        ],
      );

  @override
  void initState() {
    currentStore();
    _manualPolygonRecalcTriggerStream =
        Provider.of<DownloadProvider>(context, listen: false)
            .manualPolygonRecalcTrigger
            .stream
            .listen((_) {
      _updatePointLatLng();
      _countTiles();
    });
    super.initState();
    _polygonVisualizerStream =
        _mapController.mapEventStream.listen((e){
          zoom(e);
          return _updatePointLatLng();
        });
    _tileCounterTriggerStream = _mapController.mapEventStream
        .debounce(const Duration(seconds: 5))
        .listen((_) => _countTiles());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      key: _mapKey,
      builder: (context, viewModel, index) => Scaffold(
        appBar: AppBar(
          title: const Text("Download Page"),
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            !isVisible
                ? IconButton(
                    onPressed: () => downloadMap(viewModel),
                    icon: const Icon(Icons.check))
                : Container(),
            const SizedBox(width: 10,)
          ],
        ),
        body: Center(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                    zoom: 5,
                    minZoom: 1,
                    maxZoom: 19,
                    center: LatLng(41, 64.5),
                    interactiveFlags:
                        InteractiveFlag.all & ~InteractiveFlag.rotate,
                    keepAlive: true),
                children: [
                  TileLayer(
                    minZoom: 1,
                    maxZoom: 19,
                    urlTemplate: BASE_MAP_URL,
                  ),
                  if (_coordsTopLeft != null && _coordsBottomRight != null)
                    _buildTargetPolygon(
                      RectangleRegion(
                        LatLngBounds(_coordsTopLeft, _coordsBottomRight),
                      ),
                    ), //MarkerLayer(markers: markers),
                ],
              ),
              Center(
                child: Visibility(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(2 / 3),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(15))),
                    child: Column(
                      mainAxisAlignment:  MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8,),
                        CircularPercentIndicator(
                          radius: 35.0,
                          lineWidth: 5.0,
                          percent: progress ?? 1.0,
                          center: Text(
                            "$percent%",
                            style: const TextStyle(fontSize: 15),
                          ),
                          progressColor: changeProgressColor(progress ?? 1.0),
                        ),
                        TextButton(
                            onPressed: () {
                              cancelledMap(viewModel);
                            },
                            child: const Text("Cancel", style: TextStyle(color: Colors.blueAccent, ),))
                      ],
                    ),
                  ),
                  visible: isVisible,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void downloadMap(DownloadProvider viewModel) async {
    final DownloadProvider downloadProvider =
    Provider.of<DownloadProvider>(context, listen: false);
    downloadProvider.minZoom = minZoom;
    downloadProvider.center = center;
    try {
      isVisible = true;
      isDownloaded = true;
      setState(() {});
      var region = viewModel.region!.toDownloadable(
        viewModel.minZoom,
        viewModel.maxZoom,
        TileLayer(urlTemplate: BASE_MAP_URL,),
        preventRedownload: viewModel.preventRedownload,
        seaTileRemoval: viewModel.seaTileRemoval,
        parallelThreads: (await SharedPreferences.getInstance()).getBool('bypassDownloadThreadsLimitation',) ??
                false
            ? 10
            : 2,
      );
      await viewModel.selectedStore!.download.startBackground(
          region: region,
          disableRecovery: viewModel.disableRecovery,
          backgroundNotificationIcon: const AndroidResource(
            name: 'ic_notification_icon',
            defType: 'mipmap',
          ),
          progressNotificationBody: (event) {
            progress = event.percentageProgress.round() / 100;
            percent = event.percentageProgress.round().toString();
            if (progress == 1) isVisible = false;
            setState(() {});
            return '${event.attemptedTiles}/${event.maxTiles} (${event.percentageProgress.round().toString()}%)';
          }).then((value){
            isDownloaded = false;
            setState(() {});
      });
    } catch (e, st) {
      print("Error massage: $e, \n$st");
    }
  }

  void _updatePointLatLng() {
    final DownloadProvider downloadProvider =
        Provider.of<DownloadProvider>(context, listen: false);
    final Size mapSize = _mapKey.currentContext!.size!;
    final centerNormal = Point<double>(mapSize.width / 2, mapSize.height / 2);
    late final Point<double> calculatedTopLeft;
    late final Point<double> calculatedBottomRight;
    final double offset = (mapSize.shortestSide - (_shapePadding * 2)) / 2;


    calculatedTopLeft = Point<double>(
      centerNormal.x - offset,
      centerNormal.y - offset,
    );
    calculatedBottomRight = Point<double>(
      centerNormal.x + offset,
      centerNormal.y + offset,
    );

    _crosshairsTop = calculatedTopLeft - _crosshairsMovement;
    _crosshairsBottom = calculatedBottomRight - _crosshairsMovement;

    _coordsTopLeft =
        _mapController.pointToLatLng(_customPointFromPoint(calculatedTopLeft));

    _coordsBottomRight = _mapController
        .pointToLatLng(_customPointFromPoint(calculatedBottomRight));

    downloadProvider.region = RectangleRegion(
      LatLngBounds(_coordsTopLeft, _coordsBottomRight),
    );

    setState(() {});
  }

  Future<void> _countTiles() async {
    final DownloadProvider provider =
        Provider.of<DownloadProvider>(context, listen: false);

    if (provider.region != null) {
      provider
        ..regionTiles = null
        ..regionTiles = await FMTC.instance('').download.check(
              provider.region!.toDownloadable(
                provider.minZoom,
                provider.maxZoom,
                TileLayer(),
              ),
            );
    }
  }

  void currentStore() async {
    final String? currentStoreName =
        Provider.of<DownloadProvider>(context, listen: false).currentStore;
    if (currentStoreName != null) {
      final StoreDirectory instanceA = FMTC.instance(currentStoreName);

      await instanceA.manage.createAsync();
      await instanceA.metadata.addAsync(
        key: 'sourceURL',
        value: 'https://map.greenwhite.uz/osm/{z}/{x}/{y}.png',
      );
      await instanceA.metadata.addAsync(
        key: 'validDuration',
        value: '14',
      );
      await instanceA.metadata.addAsync(
        key: 'behaviour',
        value: 'cacheFirst',
      );

      Provider.of<DownloadProvider>(context, listen: false)
          .setSelectedStore(instanceA, notify: false);
    }
  }

  Color changeProgressColor(double progress) {
    if (progress > 0 && progress <= 0.20) {
      return Colors.red;
    } else if (progress > 0.20 && progress < 0.50) {
      return Colors.yellow;
    } else if (progress >= 0.50 && progress < 1.0) {
      return Colors.green;
    } else {
      return const Color(0xFFB8C7CB);
    }
  }

  void cancelledMap(DownloadProvider viewModel) async {
    isVisible = false;
    setState(() {});
    try{
      await FMTC.instance(viewModel.selectedStore!.storeName).download.cancel();
    }catch(e, st){
      print("error : $e, $st");
    }
  }

  void zoom(MapEvent e) {
     minZoom = e.zoom.round();
     center = e.center;
  }

  @override
  void dispose() {
    super.dispose();
    _polygonVisualizerStream.cancel();
    _tileCounterTriggerStream.cancel();
    _manualPolygonRecalcTriggerStream.cancel();
  }
}

CustomPoint<E> _customPointFromPoint<E extends num>(Point<E> point) =>
    CustomPoint(point.x, point.y);
