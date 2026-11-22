shader_type canvas_item;
render_mode unshaded;

float glow(vec2 at, vec2 source, float radius) {
	return exp(-pow(length((at - source) * vec2(1.65, 1.0)) / radius, 2.0) * 2.0);
}

void fragment() {
	vec4 backdrop = COLOR;
	vec2 left = vec2(0.089, 0.415);
	vec2 right = vec2(0.910, 0.415);
	float left_flicker = 0.75 + 0.14 * sin(TIME * 7.0) + 0.11 * sin(TIME * 18.0);
	float right_flicker = 0.75 + 0.14 * sin(TIME * 8.0 + 1.1) + 0.11 * sin(TIME * 16.0);
	float firelight = glow(UV, left, 0.20) * left_flicker + glow(UV, right, 0.20) * right_flicker;
	vec3 light = vec3(0.11, 0.056, 0.026) * firelight;
	for (int i = 0; i < 10; i++) {
		float seed = float(i);
		float age = fract(TIME * (0.32 + mod(seed, 3.0) * 0.04) + seed * 0.382);
		vec2 source = i < 5 ? left : right;
		vec2 spark = source + vec2(sin(seed * 7.0 + TIME * 0.85) * 0.022 * age, -age * 0.16);
		float flame = glow(UV, spark, 0.0034) * sin(age * 3.14159);
		light += vec3(0.74, 0.37, 0.11) * flame;
	}
	COLOR = vec4(backdrop.rgb + light, backdrop.a);
}
