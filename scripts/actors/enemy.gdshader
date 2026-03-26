shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	tex.rgb = mix(tex.rgb, flash_color, flash_amount);
	COLOR = tex;
}