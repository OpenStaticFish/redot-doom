class_name PixelFont
extends RefCounted
## A hand-authored 5x7 bitmap alphabet. No font downloads or filtering.

const GLYPHS = {
	"A": [14,17,17,31,17,17,17], "B": [30,17,17,30,17,17,30],
	"C": [14,17,16,16,16,17,14], "D": [30,17,17,17,17,17,30],
	"E": [31,16,16,30,16,16,31], "F": [31,16,16,30,16,16,16],
	"G": [14,17,16,23,17,17,15], "H": [17,17,17,31,17,17,17],
	"I": [14,4,4,4,4,4,14], "J": [7,2,2,2,2,18,12],
	"K": [17,18,20,24,20,18,17], "L": [16,16,16,16,16,16,31],
	"M": [17,27,21,21,17,17,17], "N": [17,25,21,19,17,17,17],
	"O": [14,17,17,17,17,17,14], "P": [30,17,17,30,16,16,16],
	"Q": [14,17,17,17,21,18,13], "R": [30,17,17,30,20,18,17],
	"S": [15,16,16,14,1,1,30], "T": [31,4,4,4,4,4,4],
	"U": [17,17,17,17,17,17,14], "V": [17,17,17,17,17,10,4],
	"W": [17,17,17,21,21,21,10], "X": [17,17,10,4,10,17,17],
	"Y": [17,17,10,4,4,4,4], "Z": [31,1,2,4,8,16,31],
	"0": [14,17,19,21,25,17,14], "1": [4,12,4,4,4,4,14],
	"2": [14,17,1,2,4,8,31], "3": [30,1,1,14,1,1,30],
	"4": [2,6,10,18,31,2,2], "5": [31,16,16,30,1,1,30],
	"6": [14,16,16,30,17,17,14], "7": [31,1,2,4,8,8,8],
	"8": [14,17,17,14,17,17,14], "9": [14,17,17,15,1,1,14],
	".": [0,0,0,0,0,12,12], ",": [0,0,0,0,0,4,8],
	":": [0,12,12,0,12,12,0], "/": [1,2,2,4,8,8,16],
	"-": [0,0,0,31,0,0,0], "+": [0,4,4,31,4,4,0],
	"%": [17,2,4,8,17,0,0], "!": [4,4,4,4,4,0,4],
	"?": [14,17,1,2,4,0,4], ">": [16,8,4,2,4,8,16],
	"<": [1,2,4,8,4,2,1], "[": [14,8,8,8,8,8,14],
	"]": [14,2,2,2,2,2,14], "=": [0,31,0,31,0,0,0],
	"'": [4,4,8,0,0,0,0], "_": [0,0,0,0,0,0,31],
	" ": [0,0,0,0,0,0,0]
}

static func width(text: String, scale: int = 1) -> int:
	return maxi(0, text.length() * 6 - 1) * scale

static func text(canvas: CanvasItem, value: String, at: Vector2, color: Color, scale: int = 1, shadow: bool = true) -> void:
	if shadow:
		text(canvas, value, at + Vector2(scale, scale), Color(0.02, 0.02, 0.025, color.a), scale, false)
	var x = int(at.x)
	for letter in value.to_upper():
		var rows = GLYPHS.get(letter, GLYPHS["?"])
		for y in range(7):
			for bit in range(5):
				if rows[y] & (1 << (4 - bit)):
					canvas.draw_rect(Rect2(x + bit * scale, int(at.y) + y * scale, scale, scale), color)
		x += 6 * scale

static func centered(canvas: CanvasItem, value: String, y: float, color: Color, scale: int = 1) -> void:
	text(canvas, value, Vector2((480 - width(value, scale)) / 2.0, y), color, scale)

static func sign_texture(value: String, color: Color) -> ImageTexture:
	var image = Image.create(width(value) + 6, 11, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.025, 0.035, 0.035))
	for y in [0, 10]:
		for x in range(image.get_width()):
			image.set_pixel(x, y, color * Color(0.45, 0.45, 0.45))
	var start = 3
	for letter in value.to_upper():
		var rows = GLYPHS.get(letter, GLYPHS["?"])
		for y in range(7):
			for bit in range(5):
				if rows[y] & (1 << (4 - bit)):
					image.set_pixel(start + bit, y + 2, color)
		start += 6
	return ImageTexture.create_from_image(image)
