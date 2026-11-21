import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/app_data_sync.dart";
import "package:eco_monitor/data/campaigns_repository.dart";
import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/connectivity_service.dart";
import "package:eco_monitor/data/disposal_guide_repository_synced.dart";
import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/models/point_suggestion.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    "loads offline first, syncs when reconnecting, and flushes queue",
    () async {
      final StreamController<List<ConnectivityResult>> connectivityController =
          StreamController<List<ConnectivityResult>>.broadcast();
      bool online = false;
      final List<String> sentSuggestions = <String>[];
      final DateTime now = DateTime.utc(2026, 11, 17, 18);

      final AppDataSync sync = AppDataSync(
        collectPointsRepository: CollectPointsRepository(
          fetcher: () async => CollectPointsRemoteSnapshot(
            points: <CollectionPoint>[
              CollectionPoint(
                id: "remote-1",
                name: "Farmácia Remota",
                type: PointType.pharmacy,
                latitude: -10.92,
                longitude: -37.05,
                address: "Av. Remota, 10",
                acceptedWasteTypes: const {WasteType.medicines},
                hours: "8h às 18h",
                status: PointStatus.active,
              ),
            ],
            updatedAt: now,
          ),
          clock: () => now,
        ),
        campaignsRepository: CampaignsRepository(
          fetcher: () async => CampaignsRemoteSnapshot(
            campaigns: <Campaign>[
              Campaign(
                id: "remote-camp",
                title: "Campanha Remota",
                description: "Desc",
                wasteTypes: const {WasteType.batteries},
                locationName: "Praça",
                address: "Centro",
                latitude: -10.91,
                longitude: -37.05,
                startDate: now,
                endDate: now.add(const Duration(days: 5)),
                status: CampaignStatus.active,
              ),
            ],
            updatedAt: now,
          ),
          clock: () => now,
        ),
        suggestionsRepository: PointSuggestionsRepository(
          sender: (PointSuggestion suggestion) async {
            if (!online) {
              throw Exception("offline");
            }
            sentSuggestions.add(suggestion.name);
          },
        ),
        guideRepository: DisposalGuideRepositorySynced(clock: () => now),
        connectivityService: ConnectivityService(
          connectivityStream: connectivityController.stream,
          checkConnectivity: () async => <ConnectivityResult>[
            online ? ConnectivityResult.wifi : ConnectivityResult.none,
          ],
        ),
      );

      addTearDown(() {
        sync.dispose();
        connectivityController.close();
      });

      await sync.initialize();

      // Iniciado offline: dados empacotados carregados, dados remotos ainda não buscados.
      expect(sync.isOnline, isFalse);
      expect(sync.points.length, greaterThan(1));
      expect(sync.sourceOrigin, DataSourceOrigin.bundledAsset);

      // Envio de sugestão offline -> enfileirada localmente.
      final SuggestionSubmitResult result = await sync.submitSuggestion(
        PointSuggestion(
          id: "",
          name: "Sugestão Offline",
          address: "Rua X, 50",
          acceptedWasteTypes: const {WasteType.sharps},
          hours: "8h às 17h",
          latitude: null,
          longitude: null,
          status: SuggestionStatus.pending,
          createdAt: now,
        ),
      );

      expect(result, SuggestionSubmitResult.queuedOffline);
      expect(sync.pendingSuggestionsCount, 1);

      // Reconexão -> atualiza automaticamente os dados remotos e esvazia a fila.
      online = true;
      connectivityController.add(const <ConnectivityResult>[
        ConnectivityResult.wifi,
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sync.isOnline, isTrue);
      expect(sync.points.single.id, "remote-1");
      expect(sync.campaigns.single.id, "remote-camp");
      expect(sync.sourceOrigin, DataSourceOrigin.remoteServer);
      expect(sync.pendingSuggestionsCount, 0);
      expect(sentSuggestions, ["Sugestão Offline"]);
    },
  );
}
