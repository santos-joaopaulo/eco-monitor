import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/disposal_guide_repository_synced.dart";
import "package:eco_monitor/domain/entities/disposal_guide.dart";
import "package:eco_monitor/domain/entities/residue.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test("serves bundled fallback synchronously before any network call", () {
    final DisposalGuideRepositorySynced repository =
        DisposalGuideRepositorySynced();

    expect(repository.listResidues(), hasLength(4));
    expect(repository.stepsGuideFor(WasteType.medicines), isNotNull);
    expect(repository.stepsGuideFor(WasteType.batteries), isNotNull);
    expect(repository.stepsGuideFor(WasteType.sharps), isNotNull);
    expect(repository.stepsGuideFor(WasteType.electronics), isNull);
    expect(repository.sourceOrigin, DataSourceOrigin.bundledAsset);
  });

  test("refresh merges remote guides, caches them, and survives reload", () async {
    final DateTime serverTime = DateTime.utc(2026, 11, 17, 16);
    const DisposalGuide batteryGuide = DisposalGuide(
      title: "Pilhas e baterias",
      subtitle: "Prepare antes de descartar.",
      warning: "Nunca perfure ou incinere baterias.",
      steps: <DisposalStep>[
        DisposalStep(
          title: "Isole os polos",
          description: "Use fita isolante nos polos metálicos.",
        ),
      ],
    );

    final DisposalGuideRepositorySynced repository =
        DisposalGuideRepositorySynced(
          fetcher: () async => DisposalGuidesRemoteSnapshot(
            residues: const <Residue>[
              Residue(
                type: WasteType.batteries,
                title: "Pilhas e baterias (atualizado)",
                description: "Descrição remota.",
                minutes: 2,
                totalSteps: 1,
              ),
            ],
            guides: const <WasteType, DisposalGuide>{
              WasteType.batteries: batteryGuide,
            },
            updatedAt: serverTime,
          ),
          clock: () => serverTime,
        );

    await repository.refresh();

    expect(repository.sourceOrigin, DataSourceOrigin.remoteServer);
    expect(repository.stepsGuideFor(WasteType.batteries)?.steps, hasLength(1));
    // O guia de remédios empacotado permanece disponível mesmo quando o remoto substitui
    // apenas pilhas e baterias.
    expect(repository.stepsGuideFor(WasteType.medicines), isNotNull);
    // A mesclagem remota preserva a ordem de exibição do guia empacotado.
    expect(
      repository.listResidues().map((Residue residue) => residue.type),
      const <WasteType>[
        WasteType.medicines,
        WasteType.batteries,
        WasteType.sharps,
        WasteType.electronics,
      ],
    );

    final DisposalGuideRepositorySynced offlineReload =
        DisposalGuideRepositorySynced(clock: () => serverTime);
    await offlineReload.loadOffline();

    expect(offlineReload.sourceOrigin, DataSourceOrigin.localCache);
    expect(offlineReload.lastUpdated, serverTime);
    expect(
      offlineReload.stepsGuideFor(WasteType.batteries)?.warning,
      "Nunca perfure ou incinere baterias.",
    );
  });

  test("clearCache restores bundled fallback", () async {
    final DateTime serverTime = DateTime.utc(2026, 11, 17, 16);
    final DisposalGuideRepositorySynced repository =
        DisposalGuideRepositorySynced(
          fetcher: () async => DisposalGuidesRemoteSnapshot(
            residues: const <Residue>[],
            guides: const <WasteType, DisposalGuide>{
              WasteType.batteries: DisposalGuide(
                title: "Pilhas",
                subtitle: "Sub",
                warning: "Aviso",
                steps: <DisposalStep>[
                  DisposalStep(title: "Passo 1", description: "Desc"),
                ],
              ),
            },
            updatedAt: serverTime,
          ),
          clock: () => serverTime,
        );

    await repository.refresh();
    expect(repository.stepsGuideFor(WasteType.batteries)?.steps, hasLength(1));

    await repository.clearCache();
    expect(repository.stepsGuideFor(WasteType.batteries)?.steps, hasLength(4));
    expect(repository.sourceOrigin, DataSourceOrigin.bundledAsset);
  });
}
