import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/disposal_guide_repository_local.dart";
import "package:eco_monitor/domain/entities/residue.dart";

void main() {
  const repository = DisposalGuideRepositoryLocal();

  test("listResidues returns the three residue categories", () {
    final List<Residue> residues = repository.listResidues();

    expect(residues.map((Residue residue) => residue.type), [
      ResidueType.medicine,
      ResidueType.battery,
      ResidueType.sharps,
    ]);
  });

  test("stepsGuideFor(medicine) returns the four steps", () {
    final guide = repository.stepsGuideFor(ResidueType.medicine);

    expect(guide, isNotNull);
    expect(guide!.steps, hasLength(4));
    expect(guide.steps.first.title, "Separe os medicamentos");
    expect(guide.steps.last.title, "Leve a uma farmácia");
  });

  test("stepsGuideFor(battery) is not available yet", () {
    expect(repository.stepsGuideFor(ResidueType.battery), isNull);
  });

  test("stepsGuideFor(sharps) is not available yet", () {
    expect(repository.stepsGuideFor(ResidueType.sharps), isNull);
  });
}
