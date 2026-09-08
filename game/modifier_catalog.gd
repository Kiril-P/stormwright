extends RefCounted

const ALL: Array[Dictionary] = [
	{"id":"fork", "name":"Fork", "description":"Your Lance opens into three paths. Crown shards divide into paired spears.", "spells":"LANCE · CROWN"},
	{"id":"chain", "name":"Chain", "description":"Direct hits arc through two nearby enemies. A strike becomes a storm.", "spells":"LANCE · CROWN"},
	{"id":"pierce", "name":"Pierce", "description":"Primary paths tear through up to three enemies before fading.", "spells":"LANCE · CROWN"},
	{"id":"echo", "name":"Echo", "description":"Each cast repeats from its original position at 45% power after a short delay.", "spells":"LANCE · CROWN"},
	{"id":"overload", "name":"Overload", "description":"Three direct hits rupture an enemy's storm core, damaging its neighbors.", "spells":"LANCE · CROWN"},
	{"id":"gravity", "name":"Gravity Well", "description":"Cataclysm draws lesser enemies into its heart before the rupture.", "spells":"CATACLYSM"},
	{"id":"aftershock", "name":"Aftershock", "description":"A second ring follows Cataclysm, catching survivors in its wake.", "spells":"CATACLYSM"},
	{"id":"resonance", "name":"Resonance", "description":"Nine Crown shards orbit in a wider constellation and launch in alternating rhythm.", "spells":"CROWN"}
]

static func valid_id(id: String) -> bool:
	for entry in ALL:
		if entry.id == id:
			return true
	return false
