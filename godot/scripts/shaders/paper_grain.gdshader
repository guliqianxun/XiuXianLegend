shader_type canvas_item;

// 纸纹背景 shader：cheap value noise 叠在底色上，模拟旧纸/墨痕。
// 不读取 SCREEN_TEXTURE（保持 GL Compatibility 兼容）

uniform vec3 base_color : source_color = vec3(0.055, 0.045, 0.038);
uniform float noise_strength : hint_range(0.0, 0.2) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float grain_scale : hint_range(20.0, 400.0) = 180.0;


// 经典 hash → value noise（无外部纹理）
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}


void fragment() {
	vec2 uv = UV;
	// 双层噪声：粗（墨晕）+ 细（颗粒）
	float n1 = noise(uv * grain_scale * 0.05) * 0.5 + 0.5;  // 大块墨晕
	float n2 = noise(uv * grain_scale) * 0.5 + 0.5;          // 细颗粒
	float grain = (n1 * 0.6 + n2 * 0.4 - 0.5) * noise_strength;
	// vignette
	vec2 center = uv - 0.5;
	float vig = 1.0 - dot(center, center) * vignette_strength * 2.0;
	vec3 col = base_color + vec3(grain);
	col *= vig;
	COLOR = vec4(col, 1.0);
}
