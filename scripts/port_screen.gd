extends Control
## Port screen: binds the HUD built by tools/build_port_hud.gd to GameState.
## Fixed buttons are found by name; tavern rosters and ships for sale are rebuilt as rows.

const TABS := ["Store", "Tavern", "Shipyard", "Armory"]
const UI := "res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/"
const TAB_ON := preload("res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/tile_0002.png")
const TAB_OFF := preload("res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/tile_0003.png")
const INK := Color(0.18, 0.11, 0.05)
const CREAM := Color(1.0, 0.97, 0.88)
const WARN := Color(0.7, 0.1, 0.06)
const PROF_ICONS := {
	"deckhand": "res://assets/vendor/kenney-generic-items/PNG/Colored/genericItem_color_119.png",
	"navigator": "res://assets/vendor/kenney-generic-items/PNG/Colored/genericItem_color_162.png",
	"cook": "res://assets/vendor/kenney-generic-items/PNG/Colored/genericItem_color_114.png",
	"marksman": "res://assets/vendor/kenney-generic-items/PNG/Colored/genericItem_color_001.png",
	"swordsman": "res://assets/vendor/kenney-generic-items/PNG/Colored/genericItem_color_134.png",
}

## Button name -> [GameState method, argument].
const ACTIONS := {
	"LoadFood": ["load_supply", "food"], "LoadWater": ["load_supply", "water"],
	"UnloadFood": ["unload_supply", "food"], "UnloadWater": ["unload_supply", "water"],
	"BuyCannon": ["buy_arm", "cannon"], "SellCannon": ["sell_arm", "cannon"],
	"BuyMusket": ["buy_arm", "musket"], "SellMusket": ["sell_arm", "musket"],
	"BuySword": ["buy_arm", "sword"], "SellSword": ["sell_arm", "sword"],
	"BuyPowder": ["buy_arm", "powder"], "SellPowder": ["sell_arm", "powder"],
	"BuyShot": ["buy_arm", "shot"], "SellShot": ["sell_arm", "shot"],
	"Repair": ["repair", ""],
}

var tab := "Store"

func _ready() -> void:
	for id in ACTIONS:
		var node := find_child(id, true, false)
		if node != null and node.has_signal("pressed"):
			node.pressed.connect(_act.bind(id))
	for id in ["Depart", "NewVoyage"]:
		var node := find_child(id, true, false)
		if node != null:
			node.pressed.connect(_depart if id == "Depart" else _new_voyage)
	for id in TABS:
		var tab_button := find_child("Tab" + id, true, false)
		if tab_button != null:
			tab_button.pressed.connect(_show_tab.bind(id))
	var chart := find_child("ChartCourse", true, false)
	var map := get_node_or_null("Map")
	if chart != null and map != null:
		chart.pressed.connect(_open_map)
		map.closed.connect(_refresh)
		map.sail_requested.connect(_depart)
	var sea := get_node_or_null("SeaView")
	if sea != null:
		sea.finished.connect(_refresh)
	var log_view := get_node_or_null("Log")
	if log_view != null:
		log_view.closed.connect(_refresh)
		for id in ["OpenLog", "EndLog"]:
			var b := find_child(id, true, false)
			if b != null:
				b.pressed.connect(log_view.open)
	_show_tab(tab)
	for badge in get_tree().get_nodes_in_group("info_badge"):
		badge.mouse_entered.connect(_show_info.bind(badge))
		badge.mouse_exited.connect(_hide_info)
	_refresh()

func _act(id: String) -> void:
	var spec: Array = ACTIONS[id]
	if str(spec[1]) == "":
		GameState.call(str(spec[0]))
	else:
		GameState.call(str(spec[0]), str(spec[1]))
	_refresh()

# --- Info popups --------------------------------------------------------

func _show_info(badge: Control) -> void:
	var popup := get_node_or_null("InfoPopup") as Control
	if popup == null:
		return
	popup.get_node("Text").text = _info_text(str(badge.get_meta("info", "")))
	popup.visible = true
	popup.reset_size()
	_place_info.call_deferred(badge)

## Below the badge if it fits, else above, else to its left; always inside the window.
func _place_info(badge: Control) -> void:
	var popup := get_node("InfoPopup") as Control
	popup.reset_size()
	var view := get_viewport_rect().size
	var b := badge.get_global_rect()
	var anchor: Rect2 = b
	if badge.get_parent() is Button:
		anchor = (badge.get_parent() as Control).get_global_rect()
	var s := popup.size
	var pos := Vector2(b.end.x - s.x, b.end.y + 4)
	if pos.y + s.y > view.y - 4:
		pos.y = b.position.y - s.y - 4
		if pos.y < 4:
			pos = Vector2(anchor.position.x - s.x - 6, b.get_center().y - s.y / 2.0)
	popup.global_position = Vector2(clampf(pos.x, 4, view.x - s.x - 4), clampf(pos.y, 4, view.y - s.y - 4))

func _hide_info() -> void:
	var popup := get_node_or_null("InfoPopup")
	if popup != null:
		popup.visible = false

func _info_text(key: String) -> String:
	var v: Dictionary = GameState.voyage
	match key:
		"market":
			var cats: Array[String] = []
			for cat in GameState.goods_data["categories"]:
				var names: Array[String] = []
				for id in GameState.goods_order():
					if str(GameState.goods_data["goods"][id]["category"]) == cat:
						names.append(GameState.good_name(id))
				cats.append("%s: %s" % [str(GameState.goods_data["categories"][cat]["name"]), ", ".join(names)])
			return "Each port makes a few goods: buy them there, cheap. Every port buys every good, so you can sell anything anywhere. \"Best\" names the charted port that pays the most.\n\nEvery unit takes one hold slot.\n\n" + "\n".join(cats)
		"supply":
			return "Food and water cost %dg each and refund %dg when unloaded. %d fit in a hold slot.\n\nEach day at sea the captain eats and drinks 1, plus half for every crew member. A cook cuts the food. \"Need\" covers the slower trip (running from a pirate)." % [
				int(v["supply_price"]), int(v.get("supply_refund", v["supply_price"])), int(v.get("supply_stack", 1))]
		"ammo":
			return "Every cannon or musket shot uses 1 powder + 1 shot. Cannons fire first, then marksmen with muskets, until either runs out.\n\n%d powder or %d shot fit in a hold slot. Muskets and swords take no hold space, one per bunk." % [int(v["ammo_stack"]), int(v["ammo_stack"])]
		"ship":
			var s: Dictionary = GameState.ship()
			return "%s (tier %d): hold %d, bunks %d, gun ports %d, hull %d, %s, needs %d crew to sail.\n\n%s\n\nBuying a ship trades in yours for %d%% of its price. Owning a tier %d ship (the Brig) wins the game." % [
				GameState.ship_name, int(s["tier"]), GameState.cargo_capacity, GameState.bunks, GameState.gun_ports, GameState.hull_max,
				_speed_text(int(s["speed"])), GameState.min_crew(), str(s["blurb"]), int(float(v["trade_in"]) * 100), int(v["win_ship_tier"])]
		"crew":
			var lines: Array[String] = []
			for id in GameState.crew_data["professions"]:
				var p: Dictionary = GameState.crew_data["professions"][id]
				lines.append("%s (%d/day): %s" % [str(p["name"]), int(p["wage"][0]), str(p["note"])])
			return "\n".join(lines) + "\n\nWages are paid on arrival for each day at sea; unpaid crew desert. Signing on costs %d days' wages. Each crew member eats and drinks half a ration a day. Rosters change every %d days." % [int(v["hire_fee_days"]), int(v["roster_refresh_days"])]
		"power":
			return "About %d in 100 voyages meet a pirate. Fight power, added in order while powder and shot last:\n- each cannon %d (1 powder + 1 shot)\n- each marksman 2 with a musket and ammo, else 1\n- each swordsman 2 with a sword, else 1; deckhands 1\n\nBeat the pirate's power to take its loot (lose 1 hull unless you win by half again). Lose and you take hull damage and are plundered: %d%% of your gold and half your goods. At hull 0 you sink. Run always escapes: -1 cargo, +1 day.\n\nFarther seas have their own pirates: the chart lists who sails each route." % [
				int(round(float(v["pirate_chance"]) * 100.0)), int(v["cannon_power"]), int(float(v["plunder_gold"]) * 100)]
	return ""

func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else "%.1f" % x

func _speed_short(speed: int) -> String:
	if speed == 0:
		return ""
	return " · %+d day" % speed

func _section_title(node_name: String, text: String) -> void:
	var section := find_child(node_name, true, false)
	if section != null:
		section.get_node("Title").text = text

func _speed_text(speed: int) -> String:
	if speed < 0:
		return "%d day faster" % -speed
	if speed > 0:
		return "+%d day slower" % speed
	return "normal speed"

# --- Navigation ---------------------------------------------------------

func _open_map() -> void:
	$Panel.visible = false
	$Map.open()

func _show_tab(id: String) -> void:
	tab = id
	for other in TABS:
		var page := find_child(other, true, false)
		if page != null and page.get_parent().name == "Pages":
			page.visible = other == id
		var tab_button := find_child("Tab" + other, true, false)
		if tab_button == null:
			continue
		var frame := tab_button.get_node_or_null("Frame")
		if frame != null:
			frame.texture = TAB_ON if other == id else TAB_OFF
		var text := tab_button.get_node_or_null("Text")
		if text != null:
			text.add_theme_color_override("font_color", INK if other == id else CREAM)

func _new_voyage() -> void:
	GameState.reset()
	_refresh()

func _depart() -> void:
	if GameState.ended != "" or GameState.encounter:
		return
	var start_day: int = GameState.day
	var est: int = GameState.estimate_days(false)
	GameState.depart()
	var sea := get_node_or_null("SeaView")
	# Refused (crew) or starving in port skips the voyage; anything else gets animated.
	if sea != null and (GameState.encounter or GameState.day != start_day):
		$Panel.visible = false
		sea.play(start_day, est)
	_refresh()

func _sea_busy() -> bool:
	var sea := get_node_or_null("SeaView")
	return sea != null and sea.playing

func _hire(id: String) -> void:
	GameState.hire(id)
	_refresh()

func _dismiss(id: String) -> void:
	GameState.dismiss(id)
	_refresh()

func _buy_ship(id: String) -> void:
	GameState.buy_ship(id)
	_refresh()

# --- Refresh ------------------------------------------------------------

func _refresh() -> void:
	var busy := _sea_busy()
	var at_port := GameState.ended == "" and not GameState.encounter and not busy
	var map := get_node_or_null("Map")
	if map != null and not at_port:
		map.visible = false
	$Panel.visible = at_port and (map == null or not map.visible)
	var sea := get_node_or_null("SeaView")
	if sea != null:
		# The sea stays up behind the end panel.
		sea.visible = busy or GameState.ended != ""
		if GameState.ended != "" and not busy:
			sea.end_backdrop()
	var ending := get_node_or_null("End")
	if ending != null:
		ending.visible = GameState.ended != "" and not busy
	if not at_port:
		_refresh_end()
		return
	_refresh_overview()
	_refresh_store()
	_refresh_tavern()
	_refresh_yard()
	_refresh_armory()
	_refresh_prices()
	var message := find_child("Message", true, false)
	if message != null:
		message.text = GameState.message
	_refresh_hints()

## Every buy/sell button carries its price: "Buy (7)", "Sell (5)".
func _refresh_prices() -> void:
	var v: Dictionary = GameState.voyage
	for id in ACTIONS:
		var spec: Array = ACTIONS[id]
		var what := str(spec[1])
		var price := -1
		match str(spec[0]):
			"buy":
				price = GameState.price(what, "buy")
			"sell":
				price = GameState.price(what, "sell")
			"load_supply":
				price = int(v["supply_price"])
			"unload_supply":
				price = int(v.get("supply_refund", v["supply_price"]))
			"buy_arm":
				price = GameState.arm_price(what)
			"sell_arm":
				price = GameState.arm_sell_price(what)
			"repair":
				price = GameState.service("repair_cost")
		var button := find_child(id, true, false)
		if button == null or price < 0:
			continue
		if not button.has_meta("verb"):
			button.set_meta("verb", str(button.get_node("Text").text))
		button.get_node("Text").text = "%s (%d)" % [str(button.get_meta("verb")), price]

func _set_icon(row_name: String, path: String) -> void:
	var row := find_child(row_name, true, false)
	if row != null and row.get_node_or_null("Icon") != null:
		row.get_node("Icon").texture = load(path)

func _refresh_overview() -> void:
	_set_row("PortRow", "Port", str(GameState.port().get("name", GameState.current_port_id)))
	_set_row("PortRow", "Gold", str(GameState.gold))
	_set_row("PortRow", "Day", "  day %d" % GameState.day)
	var flag := find_child("PortFlag", true, false)
	if flag != null:
		flag.texture = load(str(GameState.port()["flag"]))
	_refresh_trip()
	_set_row("CargoRow", "Cargo", "%d / %d slots" % [GameState.cargo_used(), GameState.cargo_capacity])
	var goods: Array[String] = []
	for good in GameState.goods_order():
		if int(GameState.cargo.get(good, 0)) > 0:
			goods.append("%s %d" % [GameState.good_name(good), int(GameState.cargo[good])])
	_set_row("GoodsRow", "Goods", ", ".join(goods) if not goods.is_empty() else "none")
	var short_crew := GameState.crew_count() < GameState.min_crew()
	_set_row("AboardRow", "Aboard", "%d / %d · %dg/day%s" % [GameState.crew_count(), GameState.bunks, GameState.wages_per_day(),
		" · need %d" % GameState.min_crew() if short_crew else ""])
	_color_row("AboardRow", "Aboard", WARN if short_crew else INK)
	_set_row("RolesRow", "Roles", _roles_text())
	_set_row("ShipRow", "Ship", "%s (tier %d)" % [GameState.ship_name, int(GameState.ship()["tier"])])
	_set_icon("ShipRow", GameState.hull_texture())
	_set_row("HullRow", "Hull", "%d / %d" % [GameState.hull, GameState.hull_max])
	_color_row("HullRow", "Hull", WARN if GameState.hull <= 1 else INK)
	var a: Dictionary = GameState.armory
	_set_row("ArmsRow", "Arms", "%d · ammo %d/%d" % [int(GameState.fight_power()["total"]), int(a["powder"]), int(a["shot"])])

func _roles_text() -> String:
	var parts: Array[String] = []
	for id in GameState.crew_data["professions"]:
		var n: int = GameState.count(id)
		if n > 0:
			parts.append("%d %s" % [n, str(GameState.crew_data["professions"][id]["name"]).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "none"

func _refresh_trip() -> void:
	var dest_id: String = GameState.destination_id()
	var dest: Dictionary = GameState.ports[dest_id]
	var known: bool = GameState.is_known(dest_id)
	_set_row("ToRow", "To", "%s, %d-%d days" % [str(dest.get("name", dest_id)) if known else "? (uncharted)", GameState.estimate_days(false), GameState.estimate_days(true)])
	var to_row := find_child("ToRow", true, false)
	if to_row != null and to_row.get_node_or_null("Icon") != null:
		to_row.get_node("Icon").texture = load(str(dest["flag"])) if known else null
	for spec in [["Food", GameState.food, GameState.supplies_needed()], ["Water", GameState.water, GameState.water_needed()]]:
		var have := int(spec[1])
		var need := int(spec[2])
		var id := str(spec[0])
		_set_row(id + "Row", id, "%d · need %d" % [have, need])
		_color_row(id + "Row", id, WARN if have < need else INK)

func _refresh_store() -> void:
	var v: Dictionary = GameState.voyage
	_fill_list("GoodsList", _goods_rows())
	var food_need: int = GameState.supplies_needed()
	var water_need: int = GameState.water_needed()
	_set_row("SupplyFoodRow", "SupplyFood", "have %d · need %d · %s/day" % [GameState.food, food_need, _num(GameState.food_per_day())])
	_set_row("SupplyWaterRow", "SupplyWater", "have %d · need %d · %s/day" % [GameState.water, water_need, _num(GameState.water_per_day())])
	_color_row("SupplyFoodRow", "SupplyFood", WARN if GameState.food < food_need else INK)
	_color_row("SupplyWaterRow", "SupplyWater", WARN if GameState.water < water_need else INK)
	_section_title("StoreProvisionsSection", "PROVISIONS · %d PER SLOT" % int(v.get("supply_stack", 1)))
	_section_title("StoreCargoSection", "CARGO · %d FREE SLOTS" % GameState.free_cargo())

## Store rows: goods made here (Buy and Sell) and goods in the hold (Sell), under category headers.
func _goods_rows() -> Array:
	var rows: Array = []
	var cat := ""
	for good in GameState.goods_order():
		var made: bool = GameState.produces(good)
		var have := int(GameState.cargo.get(good, 0))
		if not made and have == 0:
			continue
		var spec: Dictionary = GameState.goods_data["goods"][good]
		if str(spec["category"]) != cat:
			cat = str(spec["category"])
			rows.append({"header": str(GameState.goods_data["categories"][cat]["name"]).to_upper()})
		var best := _best_market(good)
		var sub := "best price here" if best == GameState.current_port_id else "best: %s %d" % [_port_name(best), GameState.price(good, "sell", best)]
		var buttons: Array = []
		if made:
			buttons.append(["Buy (%d)" % GameState.price(good, "buy"), _trade.bind("buy", good)])
		buttons.append(["Sell (%d)" % GameState.price(good, "sell"), _trade.bind("sell", good)])
		rows.append({"icon": str(spec["icon"]), "text": "%s · have %d" % [str(spec["name"]), have], "sub": sub,
			"tip": "%s: %s" % [str(GameState.goods_data["categories"][cat]["name"]), "made here" if made else "not made here, sell only"], "buttons": buttons})
	if rows.is_empty():
		rows.append({"text": "Nothing to trade here."})
	return rows

## Charted port paying the most for a good (ties: the first in data order).
func _best_market(good: String) -> String:
	return _port_where(func(id): return GameState.price(good, "sell", id))

func _trade(side: String, good: String) -> void:
	if side == "buy":
		GameState.buy(good)
	else:
		GameState.sell(good)
	_refresh()

func _refresh_tavern() -> void:
	var carto_rows: Array = []
	var spec: Dictionary = GameState.cartographer()
	if not spec.is_empty():
		var chart: Dictionary = GameState.charts[str(spec["chart"])]
		var why: String = GameState.carto_refusal(spec)
		var names: Array[String] = []
		for id in chart["ports"]:
			names.append(str(GameState.ports[id]["name"]))
		carto_rows.append({"icon": "res://assets/vendor/kenney-generic-items/PNG/Colored/genericItem_color_162.png",
			"text": "%s · chart of %s · %dg/day" % [str(spec["name"]), str(chart["name"]), int(spec["wage"])],
			"sub": why if why != "" else "Sails with you to ?, then charts %s." % " and ".join(names), "warn": why != "",
			"tip": "Takes a bunk and a daily wage until you reach the landfall port; dismissed or deserted, the fee is lost.",
			"buttons": [["Hire (%d)" % int(spec["fee"]), _hire_carto]]})
	_fill_list("CartoList", carto_rows)
	var carto_section := find_child("TavernCartoSection", true, false)
	if carto_section != null:
		carto_section.visible = not carto_rows.is_empty()
	var roster_rows: Array = []
	for m in GameState.roster():
		var fee: int = GameState.hire_fee(m)
		roster_rows.append({"icon": PROF_ICONS.get(str(m["profession"]), ""), "text": "%s · %s · %dg/day" % [str(m["name"]), _prof(m), int(m["wage"])],
			"tip": str(GameState.crew_data["professions"][str(m["profession"])]["note"]), "buttons": [["Hire (%d)" % fee, _hire.bind(str(m["id"]))]]})
	if roster_rows.is_empty():
		roster_rows.append({"text": "Nobody for hire. New faces every %d days." % int(GameState.voyage["roster_refresh_days"])})
	_fill_list("RosterList", roster_rows)
	var crew_rows: Array = []
	for m in GameState.crew:
		crew_rows.append({"icon": PROF_ICONS.get(str(m["profession"]), ""), "text": "%s · %s · %dg/day" % [str(m["name"]), _prof(m), int(m["wage"])],
			"tip": str(GameState.crew_data["professions"][str(m["profession"])]["note"]), "buttons": [["Dismiss", _dismiss.bind(str(m["id"]))]]})
	if crew_rows.is_empty():
		crew_rows.append({"text": "No crew. The %s sails with %d." % [GameState.ship_name, GameState.min_crew()]})
	_fill_list("CrewList", crew_rows)
	var aboard := find_child("TavernAboardSection", true, false)
	if aboard != null:
		aboard.get_node("Title").text = "ABOARD %d/%d · %dG/DAY" % [GameState.crew_count(), GameState.bunks, GameState.wages_per_day()]

func _hire_carto() -> void:
	GameState.hire_cartographer()
	_refresh()

func _prof(m: Dictionary) -> String:
	return str(GameState.crew_data["professions"][str(m["profession"])]["name"])

func _refresh_yard() -> void:
	var s: Dictionary = GameState.ship()
	_set_row("YardShipRow", "YardShip", "%s · hold %d · bunks %d · %d gun port%s" % [GameState.ship_name, GameState.cargo_capacity, GameState.bunks, GameState.gun_ports, "" if GameState.gun_ports == 1 else "s"])
	var ship_icon := find_child("YardShipRow", true, false)
	if ship_icon != null:
		ship_icon.get_node("Icon").texture = load(GameState.hull_texture())
	_set_row("YardHullRow", "YardHull", "%d / %d" % [GameState.hull, GameState.hull_max])
	_set_row("CannonRow", "Cannon", "have %d/%d" % [int(GameState.armory["cannon"]), GameState.gun_ports])
	var rows: Array = []
	for id in GameState.port().get("shipyard", []):
		var o: Dictionary = GameState.ships[id]
		var win := " · WINS" if int(o["tier"]) >= int(GameState.voyage["win_ship_tier"]) else ""
		rows.append({"icon": str(o["sprite"]), "text": "%s%s" % [str(o["name"]), win],
			"sub": "hold %d · bunks %d · guns %d · hull %d · crew %d%s" % [int(o["hold"]), int(o["bunks"]), int(o["gun_ports"]), int(o["hull"]), int(o["min_crew"]), _speed_short(int(o["speed"]))],
			"tip": str(o["blurb"]), "buttons": [["Buy (%d)" % GameState.ship_net_price(id), _buy_ship.bind(id)]] if id != GameState.ship_id else []})
	if rows.is_empty():
		rows.append({"text": "No ships for sale here."})
	_fill_list("ShipList", rows)
	var sale := find_child("YardSaleSection", true, false)
	if sale != null:
		sale.get_node("Title").text = "FOR SALE · PRICE AFTER %dG TRADE-IN" % GameState.trade_in_value()

func _refresh_armory() -> void:
	var a: Dictionary = GameState.armory
	for kind in ["musket", "sword", "powder", "shot"]:
		var limit := "/%d" % GameState.arm_limit(kind) if kind in ["musket", "sword"] else ""
		_set_row(kind.capitalize() + "Row", kind.capitalize(), "have %d%s" % [int(a[kind]), limit])
	var p: Dictionary = GameState.fight_power()
	_set_hint("ArmoryHint", "Power %d = cannons %d + muskets %d + boarding %d (uses %d ammo)." % [int(p["total"]), int(p["cannons"]), int(p["muskets"]), int(p["boarding"]), int(p["ammo"])])
	_section_title("ArmoryWeaponsSection", "WEAPONS · ONE PER BUNK")
	_section_title("ArmoryAmmoSection", "AMMUNITION · %d PER SLOT" % int(GameState.voyage["ammo_stack"]))

## Page hints name what this port is good for, and point to the better port otherwise.
func _refresh_hints() -> void:
	var here: String = GameState.current_port_id
	var cheap: Array[String] = []
	var best: Array[String] = []
	for good in GameState.goods_order():
		if GameState.produces(good) and _port_where(func(id): return -GameState.price(good, "buy", id) if GameState.produces(good, id) else -9999) == here:
			cheap.append(GameState.good_name(good))
		var any_source := false
		for id in GameState.known_ports():
			any_source = any_source or GameState.produces(good, id)
		if any_source and _best_market(good) == here:
			best.append(GameState.good_name(good))
	var parts: Array[String] = []
	if not cheap.is_empty():
		parts.append("Cheapest " + ", ".join(cheap.slice(0, 3)))
	if not best.is_empty():
		parts.append("best price for " + ", ".join(best.slice(0, 3)))
	_set_hint("StoreHint", ("; ".join(parts) + " on the chart.") if not parts.is_empty() else "No standout prices. Compare on the chart.")
	var crew := _port_where(func(id): return -GameState.service_f("hire_mult", id) * 100.0)
	var lean := _tavern_lean(here)
	if crew == here:
		_set_hint("TavernHint", "Mostly %s. Half-price signing here." % lean)
	else:
		_set_hint("TavernHint", "Mostly %s. Half-price signing in %s." % [lean, _port_name(crew)])
	var yard := _port_where(func(id): return -GameState.service("repair_cost", id))
	var winners: Array[String] = []
	for p in GameState.known_ports():
		for id in GameState.ports[p].get("shipyard", []):
			if int(GameState.ships[id]["tier"]) >= int(GameState.voyage["win_ship_tier"]) and not _port_name(p) in winners:
				winners.append(_port_name(p))
	var yard_hint := "Cheapest repairs here." if yard == here else "Cheapest repairs: %s (%dg)." % [_port_name(yard), GameState.service("repair_cost", yard)]
	_set_hint("ShipyardHint", "%s %s (wins): %s." % [yard_hint, _win_ship_name(), ", ".join(winners)])

func _win_ship_name() -> String:
	for id in GameState.ships:
		if int(GameState.ships[id]["tier"]) >= int(GameState.voyage["win_ship_tier"]):
			return str(GameState.ships[id]["name"])
	return "next ship"

func _tavern_lean(port_id: String) -> String:
	var weights: Dictionary = GameState.ports[port_id].get("tavern", {}).get("weights", {})
	var best := ""
	for id in weights:
		if best == "" or float(weights[id]) > float(weights[best]):
			best = id
	var name := str(GameState.crew_data["professions"].get(best, {"name": "sailor"})["name"]).to_lower()
	return name.replace("man", "men") if name.ends_with("man") else name + "s"

## Port id with the highest score (ties keep the first found).
func _port_where(score: Callable) -> String:
	var pick := ""
	for id in GameState.known_ports():
		if pick == "" or float(score.call(id)) > float(score.call(pick)):
			pick = id
	return pick

func _port_name(id: String) -> String:
	return str(GameState.ports[id]["name"])

func _set_hint(node_name: String, text: String) -> void:
	var label := find_child(node_name, true, false)
	if label != null:
		label.text = text

func _set_row(row_name: String, value_name: String, value: String) -> void:
	var row := find_child(row_name, true, false)
	if row == null:
		return
	var label := row.get_node_or_null(value_name)
	if label != null:
		label.text = value

func _color_row(row_name: String, value_name: String, color: Color) -> void:
	var row := find_child(row_name, true, false)
	if row != null and row.get_node_or_null(value_name) != null:
		row.get_node(value_name).add_theme_color_override("font_color", color)

# --- Runtime list rows ----------------------------------------------------

## Rebuilds a VBox of rows: {icon?, text, sub?, tip?, buttons: [[label, Callable]]}.
func _fill_list(list_name: String, rows: Array) -> void:
	var list := find_child(list_name, true, false)
	if list == null:
		return
	# Detach now (the pressed button may be inside), free at end of frame.
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for r in rows:
		if r.has("header"):
			var head := _small_label(str(r["header"]), 10, Color(INK, 0.55))
			head.custom_minimum_size = Vector2(0, 14)
			list.add_child(head)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.custom_minimum_size = Vector2(0, 24)
		list.add_child(row)
		if str(r.get("icon", "")) != "":
			var icon := TextureRect.new()
			icon.texture = load(str(r["icon"]))
			icon.custom_minimum_size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", -2)
		row.add_child(texts)
		var label := _small_label(str(r["text"]), 11, INK)
		label.tooltip_text = str(r.get("tip", ""))
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		texts.add_child(label)
		if r.has("sub"):
			texts.add_child(_small_label(str(r["sub"]), 10, WARN if r.get("warn", false) else Color(INK, 0.65)))
		for spec in r.get("buttons", []):
			row.add_child(_plate(str(spec[0]), spec[1]))

func _small_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _plate(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(72, 22)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := NinePatchRect.new()
	frame.texture = load(UI + "tile_0001.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_patch_margin(side, 6)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", CREAM)
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(action)
	return button

# --- End panel ----------------------------------------------------------

func _refresh_end() -> void:
	var titles := {
		"starved": "Starved at sea",
		"sunk": "Sunk by the pirate",
		"win": "You commissioned a %s" % GameState.ship_name,
	}
	var reasons := {
		"starved": "Food or water ran out. Each day eats 1 of each, plus half for every crew member. Load what the trip needs before you depart.",
		"sunk": "Your hull hit 0. Fight power (cannons with powder and shot, marksmen, swordsmen) must beat the pirate's. Running always survives; repair between trips.",
		"win": "The trade runs paid for a real warship. That is the game.",
	}
	_set_text("End/Box/Title", str(titles.get(GameState.ended, GameState.ended)))
	_set_text("End/Box/Reason", str(reasons.get(GameState.ended, "")))
	_set_text("End/Box/Day", "Day %d" % GameState.day)
	_set_text("End/Box/Gold", "Gold %d" % GameState.gold)
	var icon := get_node_or_null("End/Box/Icon")
	if icon == null:
		return
	var path := ""
	if GameState.ended == "starved":
		path = "res://assets/vendor/kenney-generic-items/PNG/Colored/genericItem_color_101.png"
	elif GameState.ended == "sunk":
		path = "res://assets/vendor/kenney-pirate-pack/PNG/Default size/Effects/explosion1.png"
	elif GameState.ended == "win":
		path = GameState.hull_texture()
	if path != "":
		icon.texture = load(path)

func _set_text(path: String, value: String) -> void:
	var node := get_node_or_null(path)
	if node != null:
		node.text = value
