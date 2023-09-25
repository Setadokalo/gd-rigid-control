shader_type spatial;
render_mode shadows_disabled, cull_disabled;

uniform float pWaveMagnitude: hint_range(0.0, 0.8) = 0.1;
uniform float pWaveWindFalloff = 3.0;
uniform float pWaveColorFalloff = 3.0;
uniform float pWaveWidthFalloff: hint_range(0.0, 1.0) = 0.2;
uniform float pWaveWidthCurve: hint_range(0.0, 8.0) = 0.2;
uniform float pWaveSpeed = 1.0;
uniform sampler2D pNoise;

varying float grassY;

void vertex() {
	grassY = 1.0 - (VERTEX.z * 2.0 + 0.5);
	VERTEX.xy *= pow(1.0-grassY, pWaveWidthCurve) * pWaveWidthFalloff + 1.0 - pWaveWidthFalloff;
	vec3 worldPos = NODE_POSITION_WORLD;
	worldPos += texture(pNoise, worldPos.xz * 0.01).rgb * 5.0;
	float wind = texture(pNoise, worldPos.xz + TIME * pWaveSpeed * 0.1).r - 0.5;
	float waveStrength = pow(grassY, pWaveWindFalloff);
	VERTEX.x += wind * pWaveMagnitude * waveStrength;
	VERTEX.y += wind * pWaveMagnitude * waveStrength;
}

void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	ALBEDO = mix(vec3(0.026, 0.2, 0.02), vec3(0.2, 0.4, 0.1), pow(grassY, pWaveColorFalloff));
}

void light() {
	vec3 l1 = (pow(grassY, 1.0 / pWaveColorFalloff) * 0.5 + 0.25) * ATTENUATION * LIGHT_COLOR * ALBEDO;
    DIFFUSE_LIGHT += l1;
}