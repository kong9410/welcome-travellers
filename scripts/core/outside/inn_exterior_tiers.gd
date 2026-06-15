class_name InnExteriorTiers
extends RefCounted

enum Tier {
	SMALL_INN = 1,
}


class TierSpec:
	var body_size: Vector2 = Vector2(240.0, 180.0)
	var roof_peak_height: float = 95.0
	var window_count: int = 2
	var has_chimney: bool = true


static func spec_for(tier: Tier) -> TierSpec:
	var spec := TierSpec.new()
	match tier:
		Tier.SMALL_INN:
			pass
	return spec
