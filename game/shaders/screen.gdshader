shader_type spatial;
render_mode unshaded, cull_back;
// Экранчик: пиксели, строки развёртки, лёгкое мерцание и виньетка по краям.

uniform sampler2D tex : filter_nearest, source_color;
uniform vec2 res = vec2(192.0, 112.0);
uniform float time = 0.0;

void fragment() {
	vec2 uv = UV;
	vec3 c = texture(tex, uv).rgb;
	// строки развёртки
	float line = 0.78 + 0.22 * step(0.5, fract(uv.y * res.y));
	// бегущая полоса
	float roll = 0.94 + 0.06 * smoothstep(0.0, 0.08, abs(fract(uv.y - time * 0.12) - 0.5));
	// виньетка
	vec2 d = uv - 0.5;
	float vig = clamp(1.0 - dot(d, d) * 1.6, 0.0, 1.0);
	float flick = 0.97 + 0.03 * sin(time * 50.0);
	ALBEDO = c * line * roll * vig * flick * 1.6 + vec3(0.012, 0.01, 0.01);
}
