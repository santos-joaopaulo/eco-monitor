import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/disposal_guide_repository_local.dart";
import "package:eco_monitor/domain/entities/disposal_guide.dart";
import "package:eco_monitor/domain/entities/residue.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  const DisposalGuideRepositoryLocal repository =
      DisposalGuideRepositoryLocal();

  test("listResidues returns all residue categories", () {
    final List<Residue> residues = repository.listResidues();

    expect(residues.map((Residue residue) => residue.type), [
      WasteType.medicines,
      WasteType.batteries,
      WasteType.sharps,
      WasteType.electronics,
      WasteType.glass,
    ]);
  });

  test("every active residue has a matching guide with consistent steps", () {
    for (final Residue residue in repository.listResidues()) {
      if (residue.type == WasteType.electronics) continue;
      final DisposalGuide? guide = repository.stepsGuideFor(residue.type);

      expect(guide, isNotNull, reason: "Missing guide for ${residue.type}");
      expect(guide!.title, isNotEmpty);
      expect(guide.subtitle, isNotEmpty);
      expect(guide.warning, isNotEmpty);
      expect(
        guide.steps,
        hasLength(residue.totalSteps),
        reason: "Step count mismatch for ${residue.type}",
      );

      for (final DisposalStep step in guide.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
      }
    }
  });

  test("stepsGuideFor(medicines) returns the four steps", () {
    final DisposalGuide? guide = repository.stepsGuideFor(WasteType.medicines);

    expect(guide, isNotNull);
    expect(guide!.steps, hasLength(4));
    expect(guide.steps.first.title, "Separe os medicamentos");
    expect(guide.steps.last.title, "Leve a uma farmácia");
  });

  test("stepsGuideFor(batteries) returns the four steps", () {
    final DisposalGuide? guide = repository.stepsGuideFor(WasteType.batteries);

    expect(guide, isNotNull);
    expect(guide!.steps, hasLength(4));
    expect(guide.steps.first.title, "Separe do lixo comum");
    expect(guide.steps.last.title, "Leve a um ponto de coleta");
  });

  test("stepsGuideFor(sharps) returns the five ANVISA-aligned steps", () {
    final DisposalGuide? guide = repository.stepsGuideFor(WasteType.sharps);

    expect(guide, isNotNull);
    expect(guide!.warning, contains("ANVISA"));
    expect(guide.steps, hasLength(5));
    expect(guide.steps.first.title, "Não reencape nem quebre");
    expect(guide.steps.last.title, "Entregue em uma UBS");
  });

  test("stepsGuideFor(electronics) returns null because it is disabled", () {
    final DisposalGuide? guide = repository.stepsGuideFor(
      WasteType.electronics,
    );

    expect(guide, isNull);
  });
}
