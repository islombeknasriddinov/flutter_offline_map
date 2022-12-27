import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_offline_map/pages/download_map_page.dart';
import 'package:flutter_offline_map/viewmodel/download_viewmodel.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

const String BASE_MAP_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";

class HomePage extends StatefulWidget {
  static const String id = "home_page";

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    final DownloadProvider provider =
    Provider.of<DownloadProvider>(context, listen: false);
    provider.checkInternetConnection();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(builder: (ctx, provider, index) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Map"),
          elevation: 0,
          actions: [
            IconButton(
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed(DownloadMapPage.id)
                      .then((value) {
                    _mapController.move(
                        provider.center, provider.minZoom.toDouble());
                  });
                },
                icon: const Icon(Icons.download)),
            const SizedBox(
              width: 10,
            )
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              provider.isConnected == true
                  ? FlutterMap(
                      options: MapOptions(
                        zoom: 5,
                        center:  LatLng(45, 64.5),
                        maxZoom: 19,
                        minZoom: 1,
                      ),
                      children: [
                        /*
                         * Online Map
                         * */
                        TileLayer(
                          maxZoom: 19,
                          minZoom: 1,
                          urlTemplate: BASE_MAP_URL,
                        ),
                        //MarkerLayer(markers: markers),
                      ],
                    )
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                          zoom: provider.minZoom.toDouble(),
                          center: provider.center,
                          maxZoom: provider.maxZoom.toDouble(),
                          minZoom: provider.minZoom.toDouble()
                          ),
                      children: [
                        /*
                         * Offline Map
                         * */
                        TileLayer(
                          maxZoom: provider.maxZoom.toDouble(),
                          minZoom: provider.minZoom.toDouble(),
                          tileProvider: provider.currentStore != null
                              ? FMTC
                                  .instance(provider.currentStore!)
                                  .getTileProvider(FMTCTileProviderSettings(
                                      behavior: CacheBehavior.cacheOnly))
                              : NetworkNoRetryTileProvider(),
                        ),
                        //MarkerLayer(markers: markers),
                      ],
                    ),
            ],
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
    final DownloadProvider provider =
    Provider.of<DownloadProvider>(context, listen: false);
    provider.checkInternetConnectionCansel();
  }
}
