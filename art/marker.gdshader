shader_type canvas_item;

uniform float noise_scale;
uniform sampler2D noise_texture : repeat_enable;
uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D marker_texture : repeat_enable;

void fragment() {
	vec2 noise_uv = SCREEN_UV;
	noise_uv.x += round(TIME * 6.0) * 1.383; // 8 is fps, 1.383 is a random number to sample different points each integer multiple
	vec2 noise = texture(noise_texture, noise_uv).rg; // sample noise
	noise = (noise - 0.5) * 2.0; // remap to -1 to +1
	noise *= noise_scale;
	vec2 uv = SCREEN_UV + noise;
	
	float a = texture(screen_texture, uv).a;
	COLOR.a = a;
	COLOR.rgb = texture(marker_texture, uv * 4.0).rgb;
	//COLOR = texture(screen_texture, SCREEN_UV);
}