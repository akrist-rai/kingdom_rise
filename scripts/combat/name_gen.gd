class_name NameGen
extends RefCounted
const GIVEN = ["ALDEN", "ROWAN", "OSWIN", "CEDRIC", "BRAM", "ELRIC", "HUGH", "GARETH", "LEIF", "RUFUS", "TOMAS", "IVAR", "WILLEM", "MILO", "LUCAN", "SEREN"]
const SURNAMES = ["ASH", "VALE", "THORN", "REED", "WARD", "FEN", "PIKE", "HOLT", "MARCH", "GREY", "MOSS", "ROOK", "WREN", "FROST", "WELLS", "STONE"]
static func make(_fac: int) -> String:
	return GIVEN.pick_random()+" "+SURNAMES.pick_random()
