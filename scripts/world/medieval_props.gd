class_name MedievalProps
extends RefCounted
## Architecture shares the siege footprints and obstruction fades.
class Chapel extends Node2D:
	var battle
	func _draw() -> void:
		var p=Painter.new(self)
		p.ink_w=0.8
		p.shape(Painter.rect(-40,-65,80,65),Color("#d9c69d"),Color("#9b947d"))
		CityArt.roof(self,Rect2(-46,-93,92,40),CityArt.ROOFS[1])
		p.shape(Painter.rect(-13,-109,26,63),Color("#c6bea0"),Color("#7f8875"))
		p.shape(PackedVector2Array([Vector2(-18,-109),Vector2(0,-158),Vector2(18,-109)]),Color("#3a5a5f"),Color("#253f47"))
		p.fill(Painter.rect(-4,-102,8,19),Color("#2b4141"))
		p.fill(Painter.rect(-7,-30,14,30),Color("#3d493e"))
		for x in [-27,27]:
			p.fill(Painter.rect(x-3,-40,6,13),Color("#3a5554"))
		p.line(Vector2(0,-157),Vector2(0,-173),CityArt.INK,1.2)
		p.line(Vector2(-5,-168),Vector2(5,-168),CityArt.INK,1.2)
	func _process(delta:float) -> void:
		SiegeProps.House._fade(self,battle,Rect2(position-Vector2(48,180),Vector2(96,180)),delta)

class Keep extends Node2D:
	var battle
	var rect=Rect2()
	func setup(b,r:Rect2)->void:
		battle=b
		rect=r
		position=Vector2(r.get_center().x,r.end.y)
	func _draw()->void:
		var p=Painter.new(self)
		p.ink_w=0.9
		var w=rect.size.x
		var d=rect.size.y
		p.shape(Painter.rect(-w/2,-d-60,w,d+60),Color("#c4bea0"),Color("#808b7e"))
		for j in 7:
			var y=-d-54+j*21
			p.line(Vector2(-w/2,y),Vector2(w/2,y),Color("#8d9784"),0.7)
		CityArt.roof(self,Rect2(-w/2-8,-d-100,w+16,d*0.58),CityArt.ROOFS[1])
		for x in [-w/2+18,w/2-18]:
			p.shape(Painter.rect(x-23,-d-96,46,d+96),Color("#d8cfad"),Color("#899580"))
			for k in 4:
				p.shape(Painter.rect(x-26+k*15,-d-107,10,19),Color("#e0d4b3"),Color("#92967b"))
			for y in [-38,-76,-116]:
				p.fill(Painter.rect(x-2,y,4,15),Color("#314b49"))
		p.fill(Painter.rect(-16,-42,32,42),Color("#384b44"))
		for x in [-w*0.28,0,w*0.28]:
			p.shape(Painter.rect(x-8,-d+10,16,28),Color("#3e6569"),Color("#293f43"))
			p.line(Vector2(x,-d+10),Vector2(x,-d+38),Color("#ead9aa"),1.0)
		for x in [-w*0.32,w*0.32]:
			p.fill(PackedVector2Array([Vector2(x-12,-64),Vector2(x+12,-64),Vector2(x+12,-15),Vector2(x,-24),Vector2(x-12,-15)]),Color("#32646a"))
			p.line(Vector2(x,-58),Vector2(x,-30),Color("#dbbd78"),2.0)
	func _process(delta:float)->void:
		SiegeProps.House._fade(self,battle,Rect2(rect.position-Vector2(20,170),rect.size+Vector2(40,180)),delta)
