shader_type canvas_item;
// Вид в дверной глазок: всё чёрное, кроме круга; по краю круга — тёмное кольцо линзы.

void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5);
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(uv);
	float lens = smoothstep(0.43, 0.38, r);
	float ring = smoothstep(0.30, 0.42, r) * 0.75;
	float a = 1.0 - lens + ring * lens;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(a, 0.0, 1.0));
}
