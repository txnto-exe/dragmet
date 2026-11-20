shader_type canvas_item;
// Пост-обработка: упрощение цветов с дизерингом (как в старых 3D-играх), виньетка,
// зерно и «гниение» — чем ближе срок долга, тем грязнее и желтее картинка.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float levels = 28.0;
uniform float rot = 0.0;
uniform float vignette = 0.55;
uniform float time = 0.0;

const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float d = (bayer[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	c += d / levels;
	c = floor(c * levels + 0.5) / levels;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(1.0, 1.0, 0.72), rot * 0.45);
	float g = hash(floor(FRAGCOORD.xy) + floor(time * 24.0)) - 0.5;
	c += g * (0.025 + rot * 0.03);
	float v = distance(uv, vec2(0.5));
	c *= 1.0 - smoothstep(0.32, 0.8, v) * (vignette + rot * 0.35);
	COLOR = vec4(c, 1.0);
}
