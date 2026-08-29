shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// Helligkeit behalten, Farbton ersetzen — so bleiben die Schattierungen
	// des Sprites erhalten.
	float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 swapped = tint.rgb * (0.55 + 0.9 * luma);
	COLOR = vec4(mix(base.rgb, swapped, strength), base.a);
}
