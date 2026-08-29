## Verlangt eine gefuellte Sammlung. Belohnt Spieler, die das Journal
## vollmachen, statt nur den wertvollsten Fisch zu wiederholen.
class_name JournalCondition
extends CatchCondition

@export var min_species: int = 5

func is_met(state: Dictionary) -> bool:
	return int(state.get("journal_species", 0)) >= min_species

func describe() -> String:
	return "Verlangt %d entdeckte Arten" % min_species
