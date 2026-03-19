## Thin dispatcher for city district construction.
## Each district is implemented in its own module under scripts/world/districts/.
##
## City Layout (140x100, center at origin, x:-70..70, z:-50..50)
## Districts:
##   Central Plaza       (x:-15..20,  z:-10..10)
##   Market District     (x:-70..-20, z:-10..50)
##   Residential Quarter (x:-70..-20, z:-50..-10)
##   Noble/Temple Quarter(x:-20..25,  z:-50..-10)
##   Park/Gardens        (x:25..70,   z:-50..-10)
##   Craft/Workshop      (x:-20..25,  z:10..50)
##   Garrison/Training   (x:25..70,   z:10..50)
##   City Gate Area      (x:55..70,   z:-10..10)
class_name CityBuilder

const DistrictPlaza       = preload("res://scripts/world/districts/district_plaza.gd")
const DistrictMarket      = preload("res://scripts/world/districts/district_market.gd")
const DistrictResidential = preload("res://scripts/world/districts/district_residential.gd")
const DistrictNoble       = preload("res://scripts/world/districts/district_noble.gd")
const DistrictPark        = preload("res://scripts/world/districts/district_park.gd")
const DistrictCraft       = preload("res://scripts/world/districts/district_craft.gd")
const DistrictGarrison    = preload("res://scripts/world/districts/district_garrison.gd")
const DistrictGate        = preload("res://scripts/world/districts/district_gate.gd")


static func build_all_districts(ctx: WorldBuilderContext) -> void:
	DistrictPlaza.build(ctx)
	DistrictMarket.build(ctx)
	DistrictResidential.build(ctx)
	DistrictNoble.build(ctx)
	DistrictPark.build(ctx)
	DistrictCraft.build(ctx)
	DistrictGarrison.build(ctx)
	DistrictGate.build(ctx)
