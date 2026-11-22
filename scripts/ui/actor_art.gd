class_name ActorArt
extends RefCounted

# All coordinates are local to the actor's planted feet.
const INK := Color("#161a27")
const METAL := Color("#a8bcc9")
const GOLD := Color("#ebbd76")
const SKIN := Color("#d19b77")
const UNIFORMS := {
	"rook": [Color("#4e7d8d"), Color("#b6dfdf")],
	"mira": [Color("#623e76"), Color("#ceb2ed")],
	"sable": [Color("#2d6e61"), Color("#a5d39b")],
	"guard": [Color("#344c6c"), Color("#8fbdd1")],
	"warden": [Color("#754252"), Color("#f2ac78")],
	"marshal": [Color("#55407d"), Color("#e1bffc")],
	"regent": [Color("#324b51"), Color("#96f4ca")],
	"goblin": [Color("#77475f"), Color("#b4d191")],
	"skeleton": [Color("#716158"), Color("#e4d5af")],
}

class Pose:
	var phase: float
	var pace: float
	var strike: float
	var brace: float

	func _init(clock: float, motion: float = 0.0, attack: float = 0.0, guard: float = 0.0) -> void:
		phase = clock
		pace = motion
		strike = attack
		brace = guard


static func model(fighter: BattleRules.Fighter, fallback: String) -> String:
	return fallback if fighter.id.is_empty() else fighter.id


static func draw(canvas: CanvasItem, id: String, feet: Vector2, height: float, facing: float,
	pose: Pose, tint: Color = Color.WHITE, angle: float = 0.0) -> void:
	var scale: float = height / 48.0
	canvas.draw_set_transform(feet, angle, Vector2(scale * facing, scale))
	match id:
		"rat", "cinder": _rat(canvas, id == "cinder", pose, tint)
		"slime": _slime(canvas, pose, tint)
		"spider": _spider(canvas, pose, tint)
		"mimic": _mimic(canvas, pose, tint)
		"gargoyle": _gargoyle(canvas, pose, tint)
		_: _humanoid(canvas, id, pose, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func _polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color, tint: Color) -> void:
	var low: float = points[0].y
	var high: float = low
	for point: Vector2 in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	var shades := PackedColorArray()
	var highlight: Color = fill.lightened(0.14)
	var shadow: Color = fill.darkened(0.23)
	for point: Vector2 in points:
		var depth: float = (point.y - low) / maxf(1.0, high - low)
		shades.append(highlight.lerp(shadow, depth) * tint)
	canvas.draw_polygon(points, shades)
	points.append(points[0])
	canvas.draw_polyline(points, INK * tint, 1.08, true)


static func _line(canvas: CanvasItem, from: Vector2, to: Vector2, shade: Color, tint: Color, width: float) -> void:
	canvas.draw_line(from, to, shade * tint, width, true)


static func _limb(canvas: CanvasItem, from: Vector2, joint: Vector2, tip: Vector2,
	shade: Color, tint: Color, width: float) -> void:
	canvas.draw_polyline(PackedVector2Array([from, joint, tip]), INK * tint, width + 2.0, true)
	canvas.draw_polyline(PackedVector2Array([from, joint, tip]), shade * tint, width, true)
	canvas.draw_circle(joint, width * 0.48, shade.lightened(0.12) * tint, true, -1.0, true)


static func _humanoid(canvas: CanvasItem, id: String, pose: Pose, tint: Color) -> void:
	var uniform: Array = UNIFORMS.get(id, UNIFORMS.rook)
	var cloth: Color = uniform[0]
	var accent: Color = uniform[1]
	var boss: bool = id in ["warden", "marshal", "regent"]
	var skeleton: bool = id == "skeleton"
	var goblin: bool = id == "goblin"
	var mage: bool = id == "mira"
	var hood: bool = mage or id == "sable"
	var step: float = sin(pose.phase) * 6.5 * pose.pace
	var rise: float = sin(pose.phase * 0.53) * 0.8 - absf(step) * 0.18
	var core := Vector2(pose.strike * 3.0 - pose.brace * 2.0, rise + pose.brace * 3.0 + (5.0 if goblin else 0.0))
	var hip: Vector2 = core + Vector2(0, -16)
	var neck: Vector2 = core + Vector2(1, -32)
	var head: Vector2 = neck + Vector2(1, -5)
	var cape: float = sin(pose.phase * 0.84) * 2.6 - pose.pace * 4.0 - pose.strike * 4.0
	if not skeleton:
		_polygon(canvas, PackedVector2Array([neck + Vector2(-5, -1), neck + Vector2(4, 2),
			hip + Vector2(-1, 10), hip + Vector2(-15 + cape, 12), hip + Vector2(-9 + cape, 2)]),
			cloth.darkened(0.36), tint)
		_line(canvas, neck + Vector2(-5, 1), hip + Vector2(-11 + cape, 9), cloth.lightened(0.22), tint, 1.0)
	var far_foot := Vector2(-5.0 - step, -maxf(0.0, -step) * 0.34)
	var front_foot := Vector2(5.0 + step, -maxf(0.0, step) * 0.34)
	var leg: Color = accent if skeleton else cloth.lightened(0.08)
	_limb(canvas, hip + Vector2(-3, 0), hip.lerp(far_foot, 0.53) + Vector2(-3, 0), far_foot, leg.darkened(0.35), tint, 3.6)
	_limb(canvas, hip + Vector2(4, 0), hip.lerp(front_foot, 0.56) + Vector2(3, 0), front_foot, leg, tint, 4.3)
	_line(canvas, far_foot - Vector2(1, 0), far_foot + Vector2(3, 0), INK.lightened(0.15), tint, 2.8)
	_line(canvas, front_foot - Vector2(1, 0), front_foot + Vector2(4, 0), INK.lightened(0.23), tint, 2.8)
	var plate: Color = accent if skeleton else cloth.lightened(0.24)
	_polygon(canvas, PackedVector2Array([neck + Vector2(-8, 1), neck + Vector2(5, -1),
		neck + Vector2(9, 5), hip + Vector2(5, 1), hip + Vector2(-4, 2), neck + Vector2(-7, 8)]), plate, tint)
	_polygon(canvas, PackedVector2Array([neck + Vector2(-5, 3), neck + Vector2(6, 2),
		hip + Vector2(5, -1), hip + Vector2(0, 2)]), cloth, tint)
	_line(canvas, neck + Vector2(-5, 3), neck + Vector2(6, 2), accent, tint, 1.3)
	if not skeleton:
		_line(canvas, neck + Vector2(0, 5), hip + Vector2(2, -3), cloth.lightened(0.32), tint, 1.35)
		var stud: Vector2 = neck + Vector2(-4, 5)
		canvas.draw_circle(stud, 1.3, (GOLD if boss else accent) * tint, true, -1.0, true)
	_line(canvas, hip + Vector2(-4, -1), hip + Vector2(5, -2), GOLD if boss else accent, tint, 1.5)
	if skeleton:
		for rib: int in range(3):
			_line(canvas, neck + Vector2(-4, 6 + rib * 3), neck + Vector2(5, 6 + rib * 3), accent, tint, 1.6)
	var helmet: Color = accent if skeleton or goblin else (cloth if hood else METAL.darkened(0.2))
	_polygon(canvas, PackedVector2Array([head + Vector2(-6, -2), head + Vector2(-3, -8),
		head + Vector2(3, -9), head + Vector2(7, -4), head + Vector2(6, 3),
		head + Vector2(1, 7), head + Vector2(-5, 4)]), helmet, tint)
	_line(canvas, head + Vector2(-3, -6), head + Vector2(3, -7), helmet.lightened(0.38), tint, 1.1)
	if hood or id == "rook" or goblin:
		var face: Color = accent.darkened(0.19) if goblin else SKIN
		_polygon(canvas, PackedVector2Array([head + Vector2(0, -4), head + Vector2(6, -3),
			head + Vector2(5, 3), head + Vector2(2, 5), head + Vector2(-1, 1)]), face, tint)
		_line(canvas, head + Vector2(4.5, 0), head + Vector2(5.5, 1.5), face.lightened(0.23), tint, 0.9)
	_line(canvas, head + Vector2(1, -1), head + Vector2(5, -1), INK, tint, 1.8)
	if boss or skeleton:
		_line(canvas, head + Vector2(2, -1), head + Vector2(5, -1), accent, tint, 1.0)
	if boss:
		match id:
			"warden":
				_polygon(canvas, PackedVector2Array([head + Vector2(-6, -5), head + Vector2(-8, -12),
					head + Vector2(-3, -10), head + Vector2(0, -15), head + Vector2(4, -10),
					head + Vector2(8, -11), head + Vector2(7, -5)]), GOLD.darkened(0.12), tint)
			"marshal":
				_polygon(canvas, PackedVector2Array([head + Vector2(3, -7), head + Vector2(0, -14),
					head + Vector2(-6 + cape, -16), head + Vector2(-13 + cape, -12),
					head + Vector2(-8 + cape, -9), head + Vector2(-3, -8)]), accent.darkened(0.10), tint)
			"regent":
				for side: int in [-1, 1]:
					_polygon(canvas, PackedVector2Array([head + Vector2(side * 2, -5), head + Vector2(side * 9, -8),
						head + Vector2(side * 11, -16), head + Vector2(side * 6, -11)]), accent.darkened(0.28), tint)
	if goblin:
		_polygon(canvas, PackedVector2Array([head + Vector2(-3, -2), head + Vector2(-11, -8),
			head + Vector2(-8, 1), head + Vector2(-4, 2)]), accent, tint)
	var shoulder: Vector2 = neck + Vector2(6, 4)
	var hand: Vector2 = hip + Vector2(10 + pose.strike * 14.0 - step * 0.55, -4.0 - maxf(0.0, pose.strike) * 9.0 - pose.brace * 9.0)
	_limb(canvas, shoulder, shoulder.lerp(hand, 0.52) + Vector2(1, 3), hand, plate, tint, 4.1)
	if boss or id == "guard" or id == "rook":
		_polygon(canvas, PackedVector2Array([shoulder + Vector2(-5, -2), shoulder + Vector2(0, -4),
			shoulder + Vector2(5, -1), shoulder + Vector2(3, 3), shoulder + Vector2(-4, 2)]), plate, tint)
		_line(canvas, shoulder + Vector2(-3, -2), shoulder + Vector2(1, -3), accent, tint, 0.9)
	var blade_angle: float = lerpf(-1.7, -0.13, maxf(0.0, pose.strike)) + minf(0.0, pose.strike) * 0.8
	var weapon: Vector2 = Vector2.from_angle(blade_angle)
	var length: float = 18.0 if boss else (10.0 if goblin else 14.0)
	if mage or id == "regent" or id == "marshal":
		var orb: Vector2 = hand + Vector2(2.0, -17.0)
		if boss:
			orb = hand + weapon * 19.0
		_line(canvas, hand.lerp(orb, -0.64), orb, Color("#977d60"), tint, 2.5)
		if id == "marshal":
			_polygon(canvas, PackedVector2Array([orb - weapon * 6.0, orb + weapon.orthogonal() * 5.0,
				orb + weapon * 5.0, orb - weapon.orthogonal() * 5.0]), METAL, tint)
		else:
			canvas.draw_circle(orb, 4.0, accent.darkened(0.30) * tint, true, -1.0, true)
			canvas.draw_circle(orb - Vector2(1, 1), 2.5, accent.lightened(0.36) * tint, true, -1.0, true)
	elif id == "sable":
		var tip_a: Vector2 = hand + Vector2(0, -13)
		var tip_b: Vector2 = hand + Vector2(0, 10)
		var pull: Vector2 = hand - Vector2(3.0 + maxf(0.0, -pose.strike) * 9.0, 2)
		canvas.draw_polyline(PackedVector2Array([tip_a, hand + Vector2(5, -5), hand + Vector2(5, 3), tip_b]),
			GOLD * tint, 1.7, true)
		canvas.draw_polyline(PackedVector2Array([tip_a, pull, tip_b]), METAL * tint, 0.8, true)
		if absf(pose.strike) > 0.10:
			_line(canvas, pull, hand + Vector2(9 + pose.strike * 4.0, -1), METAL, tint, 1.0)
	else:
		var tip: Vector2 = hand + weapon * length
		var edge: Vector2 = weapon.orthogonal() * (3.0 if boss else 2.0)
		_polygon(canvas, PackedVector2Array([hand + edge, tip + edge * 0.45, tip + weapon * 3.0,
			tip - edge * 0.45, hand - edge]), METAL, tint)
		_line(canvas, hand + weapon * 2, tip, Color("#edf8f3"), tint, 0.9)
		_line(canvas, hand - edge * 1.6, hand + edge * 1.6, GOLD if boss else accent, tint, 1.4)
	if pose.brace > 0.08:
		var rim: Color = accent
		rim.a *= pose.brace
		canvas.draw_arc(shoulder + Vector2(8, 3), 11.0, -1.45, 1.45, 20, rim * tint, 1.6, true)


static func _rat(canvas: CanvasItem, pet: bool, pose: Pose, tint: Color) -> void:
	var fur := Color("#626e7f") if pet else Color("#795755")
	var nose := Color("#bf8190") if pet else Color("#d58b6c")
	var stride: float = sin(pose.phase) * pose.pace * 6.0
	var body := Vector2(pose.strike * 7, -8 + sin(pose.phase * 0.7) * 1.1 - absf(stride) * 0.20)
	var tail := body + Vector2(-26, 1 + sin(pose.phase * 1.1) * 4.2)
	canvas.draw_polyline(PackedVector2Array([body + Vector2(-9, 1), body + Vector2(-17, 7),
		body + Vector2(-23, 6), tail]), nose * tint, 2.4, true)
	for side: int in [-1, 1]:
		_limb(canvas, body + Vector2(side * 6, 1), body + Vector2(side * 8, 4),
			Vector2(side * 8 + side * stride, -absf(stride) * 0.26), fur.darkened(0.25), tint, 2.6)
	_polygon(canvas, PackedVector2Array([body + Vector2(-12, 4), body + Vector2(-12, -4),
		body + Vector2(-4, -9), body + Vector2(7, -7), body + Vector2(13, -4),
		body + Vector2(17, 1), body + Vector2(10, 5), body + Vector2(-6, 6)]), fur, tint)
	_line(canvas, body + Vector2(-9, -5), body + Vector2(2, -6), fur.lightened(0.32), tint, 1.4)
	canvas.draw_circle(body + Vector2(6, -7), 3.5, INK * tint, true, -1, true)
	canvas.draw_circle(body + Vector2(6, -7), 2.4, nose.darkened(0.13) * tint, true, -1, true)
	canvas.draw_circle(body + Vector2(11, -3), 1.3, (Color("#a4f5ca") if pet else GOLD) * tint, true, -1, true)
	canvas.draw_circle(body + Vector2(16, 1), 1.4, nose * tint, true, -1, true)
	for whisker: int in [-1, 1]:
		_line(canvas, body + Vector2(14, 1), body + Vector2(20, 1 + 3 * whisker), fur.lightened(0.35), tint, 0.75)
	if pet:
		_line(canvas, body + Vector2(7, -4), body + Vector2(5, 4), Color("#63b7a3"), tint, 2.2)


static func _slime(canvas: CanvasItem, pose: Pose, tint: Color) -> void:
	var pulse: float = sin(pose.phase * 0.9) * (1.9 + 3.4 * pose.pace) - maxf(0.0, pose.strike) * 4.0
	var lean: float = pose.strike * 9.0
	_polygon(canvas, PackedVector2Array([Vector2(-20, -1), Vector2(-19, -9), Vector2(-11 + lean, -23 - pulse),
		Vector2(0 + lean, -29 - pulse), Vector2(10 + lean, -26 - pulse),
		Vector2(18 + lean * 0.6, -14), Vector2(21, -2), Vector2(8, 2), Vector2(-9, 2)]), Color("#a35e42"), tint)
	_polygon(canvas, PackedVector2Array([Vector2(-16, -7), Vector2(-8 + lean, -23 - pulse),
		Vector2(2 + lean, -25 - pulse), Vector2(12 + lean, -18 - pulse), Vector2(14, -7),
		Vector2(1, -3)]), Color("#de9b58"), tint)
	_line(canvas, Vector2(-7 + lean, -21 - pulse), Vector2(5 + lean, -23 - pulse), Color("#fff09e"), tint, 2.0)
	for index: int in range(4):
		var y: float = -6 - fposmod(pose.phase * 1.7 + index * 4.0, 13.0)
		canvas.draw_circle(Vector2(-9 + index * 5 + lean * 0.4, y), 1.4 + index * 0.21, GOLD * tint, true, -1.0, true)
	_line(canvas, Vector2(5 + lean, -10), Vector2(12 + lean, -10), INK, tint, 2.0)


static func _spider(canvas: CanvasItem, pose: Pose, tint: Color) -> void:
	var body := Vector2(pose.strike * 8.0, -12.0 + sin(pose.phase) * 1.4)
	var shell := Color("#77566b")
	for side: int in [-1, 1]:
		for leg: int in range(4):
			var beat: float = sin(pose.phase + leg * PI * 0.75 + float(side)) * (1.1 + pose.pace * 4.0)
			var knee := body + Vector2(side * (13 + leg), -10 + leg * 3 + beat)
			var foot := Vector2(side * (19 + leg) + beat, -1.0 - maxf(beat, 0.0) * 0.6)
			_limb(canvas, body + Vector2(side * 4, -1 + leg), knee, foot, shell.lightened(0.19), tint, 2.2)
	_polygon(canvas, PackedVector2Array([body + Vector2(-11, -1), body + Vector2(-8, -11),
		body + Vector2(0, -15), body + Vector2(8, -10), body + Vector2(10, -1),
		body + Vector2(5, 6), body + Vector2(-7, 4)]), shell, tint)
	_line(canvas, body + Vector2(-5, -8), body + Vector2(4, -11), shell.lightened(0.42), tint, 1.6)
	canvas.draw_circle(body + Vector2(6, 2), 6.0, INK.lightened(0.19) * tint, true, -1.0, true)
	for eye: int in range(3):
		canvas.draw_circle(body + Vector2(3 + eye * 3, eye % 2), 1.2, Color("#ffaf95") * tint, true, -1.0, true)


static func _mimic(canvas: CanvasItem, pose: Pose, tint: Color) -> void:
	var lift: float = 8.0 + sin(pose.phase * 0.8) * 2.4 + maxf(0.0, pose.strike) * 12.0
	var sway: float = pose.strike * 6.0
	var hide := Color("#916544")
	for side: int in [-1, 1]:
		var heel := Vector2(side * 12, 0)
		_limb(canvas, Vector2(side * 12, -8), Vector2(side * 17, -4), heel, hide.darkened(0.26), tint, 3.1)
	_polygon(canvas, PackedVector2Array([Vector2(-16, -14 - lift), Vector2(14 + sway, -14 - lift),
		Vector2(17, -8), Vector2(-17, -8)]), INK.lightened(0.08), tint)
	_polygon(canvas, PackedVector2Array([Vector2(-18, -9), Vector2(17, -9), Vector2(15, -1),
		Vector2(-15, -1)]), hide, tint)
	_polygon(canvas, PackedVector2Array([Vector2(-16, -13), Vector2(-12 + sway, -20 - lift),
		Vector2(9 + sway, -20 - lift), Vector2(17 + sway, -14 - lift), Vector2(14, -12 - lift)]), hide.lightened(0.24), tint)
	_line(canvas, Vector2(-10 + sway, -18 - lift), Vector2(9 + sway, -18 - lift), GOLD, tint, 1.6)
	for x: int in [-12, -6, 0, 6, 12]:
		var tooth := Vector2(x, -10)
		_polygon(canvas, PackedVector2Array([tooth + Vector2(-2, 2), tooth + Vector2(2, 2),
			tooth + Vector2(-0.5, -3.0)]), Color("#f9dbad"), tint)
	_line(canvas, Vector2(-13, -4), Vector2(13, -4), hide.lightened(0.3), tint, 1.0)
	canvas.draw_rect(Rect2(-2, -8, 4, 5), GOLD * tint)


static func _gargoyle(canvas: CanvasItem, pose: Pose, tint: Color) -> void:
	var spread: float = 2.0 * sin(pose.phase * 0.47) + 8.0 * maxf(0.0, pose.strike)
	var core := Vector2(pose.strike * 4.0, sin(pose.phase * 0.61) * 0.64)
	var stone := Color("#637587")
	for side: int in [-1, 1]:
		var joint: Vector2 = core + Vector2(side * 7, -23)
		var point: Vector2 = core + Vector2(side * (18 + spread), -41 + spread * 0.45)
		var edge: Vector2 = core + Vector2(side * (24 + spread * 0.33), -17)
		_polygon(canvas, PackedVector2Array([joint, point, edge, core + Vector2(side * 13, -20),
			core + Vector2(side * 7, -10)]), stone.darkened(0.32), tint)
		_line(canvas, point, core + Vector2(side * 10, -17), stone.lightened(0.24), tint, 1.5)
		_line(canvas, point.lerp(edge, 0.22), core + Vector2(side * 13, -20), stone.lightened(0.11), tint, 0.9)
		_limb(canvas, core + Vector2(side * 5, -13), core + Vector2(side * 11, -7),
			Vector2(side * 8, -1), stone, tint, 4.8)
	_polygon(canvas, PackedVector2Array([core + Vector2(-8, -25), core + Vector2(8, -25),
		core + Vector2(10, -17), core + Vector2(4, -8), core + Vector2(-5, -9)]), stone, tint)
	_polygon(canvas, PackedVector2Array([core + Vector2(-7, -24), core + Vector2(-7, -36),
		core + Vector2(-2, -30), core + Vector2(3, -31), core + Vector2(8, -36),
		core + Vector2(9, -25), core + Vector2(4, -21)]), stone.lightened(0.23), tint)
	_line(canvas, core + Vector2(-2, -27), core + Vector2(5, -27), GOLD, tint, 1.7)
	_line(canvas, core + Vector2(1, -19), core + Vector2(4, -14), stone.lightened(0.37), tint, 1.2)
