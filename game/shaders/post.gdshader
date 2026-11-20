shader_type canvas_item;
// Пост-обработка картинки 3D-мира (рисуется в маленьком разрешении и растягивается):
// упрощение цветов с дизерингом, яркость, виньетка, зерно, «гниение» к концу срока долга.

uniform vec2 low_res = vec2(640.0, 360.0);
uniform float levels = 30.0;
uniform float rot = 0.0;
uniform float vignette = 0.5;
uniform float brightness = 1.0;
uniform float time = 0.0;
uniform bool dither = true;

const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb * brightness;
	vec2 px = floor(UV * low_res);
	if (dither) {
		ivec2 p = ivec2(mod(px, 4.0));
		float d = (bayer[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
		c += d / levels;
		c = floor(c * levels + 0.5) / levels;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(1.0, 1.0, 0.72), rot * 0.45);
	float g = hash(px + floor(time * 24.0)) - 0.5;
	c += g * (0.02 + rot * 0.03);
	float v = distance(UV, vec2(0.5));
	c *= 1.0 - smoothstep(0.32, 0.85, v) * (vignette + rot * 0.35);
	COLOR = vec4(c, 1.0);
}
