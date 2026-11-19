import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/disposal_guide_repository_synced.dart";
import "package:eco_monitor/domain/entities/disposal_guide.dart";
import "package:eco_monitor/domain/entities/residue.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test("serves bundled fallback synchronously before any network call", () {
    final DisposalGuideRepositorySynced repository =
        DisposalGuideRepositorySynced();

    expect(repository.listResidues(), hasLength(4));
    expect(repository.stepsGuideFor(ResidueType.medicine), isNotNull);
    expect(repository.stepsGuideFor(ResidueType.battery), isNotNull);
    expect(repository.stepsGuideFor(ResidueType.sharps), isNotNull);
    expect(repository.stepsGuideFor(ResidueType.electronics), isNotNull);
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
                type: ResidueType.battery,
                title: "Pilhas e baterias (atualizado)",
                description: "Descrição remota.",
                minutes: 2,
                totalSteps: 1,
              ),
            ],
            guides: const <ResidueType, DisposalGuide>{
              ResidueType.battery: batteryGuide,
            },
            updatedAt: serverTime,
          ),
          clock: () => serverTime,
        );

    await repository.refresh();

    expect(repository.sourceOrigin, DataSourceOrigin.remoteServer);
    expect(repository.stepsGuideFor(ResidueType.battery)?.steps, hasLength(1));
    // Bundled medicine guide remains available even when remote only overrides
    // battery.
    expect(repository.stepsGuideFor(ResidueType.medicine), isNotNull);

    final DisposalGuideRepositorySynced offlineReload =
        DisposalGuideRepositorySynced(clock: () => serverTime);
    await offlineReload.loadOffline();

    expect(offlineReload.sourceOrigin, DataSourceOrigin.localCache);
    expect(offlineReload.lastUpdated, serverTime);
    expect(
      offlineReload.stepsGuideFor(ResidueType.battery)?.warning,
      "Nunca perfure ou incinere baterias.",
    );
  });

  test("clearCache restores bundled fallback", () async {
    final DateTime serverTime = DateTime.utc(2026, 11, 17, 16);
    final DisposalGuideRepositorySynced repository =
        DisposalGuideRepositorySynced(
          fetcher: () async => DisposalGuidesRemoteSnapshot(
            residues: const <Residue>[],
            guides: const <ResidueType, DisposalGuide>{
              ResidueType.battery: DisposalGuide(
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
    expect(repository.stepsGuideFor(ResidueType.battery)?.steps, hasLength(1));

    await repository.clearCache();
    expect(repository.stepsGuideFor(ResidueType.battery)?.steps, hasLength(4));
    expect(repository.sourceOrigin, DataSourceOrigin.bundledAsset);
  });
}
