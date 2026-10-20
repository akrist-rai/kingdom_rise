class_name Prof
extends RefCounted
## Tiny accumulating profiler for --autotest diagnostics (microseconds per label).

static var acc := {}
static var frames := 0

static func add(label: String, us: int) -> void:
	acc[label] = int(acc.get(label, 0)) + us

static func report() -> String:
	var keys := acc.keys()
	keys.sort_custom(func(a, b): return acc[a] > acc[b])
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s=%.2fms" % [k, float(acc[k]) / 1000.0 / maxf(1.0, frames)])
	acc.clear()
	frames = 0
	return " ".join(parts)
