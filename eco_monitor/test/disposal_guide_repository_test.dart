import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/disposal_guide_repository_local.dart";
import "package:eco_monitor/domain/entities/disposal_guide.dart";
import "package:eco_monitor/domain/entities/residue.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  const DisposalGuideRepositoryLocal repository =
      DisposalGuideRepositoryLocal();

  test("listResidues returns all four residue categories", () {
    final List<Residue> residues = repository.listResidues();

    expect(residues.map((Residue residue) => residue.type), [
      ResidueType.medicine,
      ResidueType.battery,
      ResidueType.sharps,
      ResidueType.electronics,
    ]);
  });

  test("every listed residue has a matching guide with consistent steps", () {
    for (final Residue residue in repository.listResidues()) {
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

  test("stepsGuideFor(medicine) returns the four steps", () {
    final DisposalGuide? guide = repository.stepsGuideFor(ResidueType.medicine);

    expect(guide, isNotNull);
    expect(guide!.steps, hasLength(4));
    expect(guide.steps.first.title, "Separe os medicamentos");
    expect(guide.steps.last.title, "Leve a uma farmácia");
  });

  test("stepsGuideFor(battery) returns the four steps", () {
    final DisposalGuide? guide = repository.stepsGuideFor(ResidueType.battery);

    expect(guide, isNotNull);
    expect(guide!.steps, hasLength(4));
    expect(guide.steps.first.title, "Separe do lixo comum");
    expect(guide.steps.last.title, "Leve a um ponto de coleta");
  });

  test("stepsGuideFor(sharps) returns the five ANVISA-aligned steps", () {
    final DisposalGuide? guide = repository.stepsGuideFor(ResidueType.sharps);

    expect(guide, isNotNull);
    expect(guide!.warning, contains("ANVISA"));
    expect(guide.steps, hasLength(5));
    expect(guide.steps.first.title, "Não reencape nem quebre");
    expect(guide.steps.last.title, "Entregue em uma UBS");
  });

  test("stepsGuideFor(electronics) returns the four steps", () {
    final DisposalGuide? guide = repository.stepsGuideFor(
      ResidueType.electronics,
    );

    expect(guide, isNotNull);
    expect(guide!.steps, hasLength(4));
    expect(guide.steps.first.title, "Apague seus dados");
    expect(guide.steps.last.title, "Leve a um ecoponto");
  });
}
