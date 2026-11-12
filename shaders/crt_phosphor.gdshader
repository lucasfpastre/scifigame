shader_type canvas_item;

// Post-processing CRT Phosphor Green shader for Godot 4
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform vec4 phosphor_color : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform float scanline_count : hint_range(50.0, 1000.0) = 360.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float curvature : hint_range(0.0, 0.15) = 0.025;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.9;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float flicker_speed : hint_range(0.0, 60.0) = 24.0;
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.015;

vec2 crt_curve(vec2 uv) {
    vec2 delta = uv - 0.5;
    float delta2 = dot(delta, delta);
    float delta4 = delta2 * delta2;
    float factor = 1.0 + delta2 * curvature + delta4 * curvature;
    return 0.5 + delta * factor;
}

void fragment() {
    vec2 curved_uv = crt_curve(SCREEN_UV);

    // Screen bezel / cutoff
    if (curved_uv.x < 0.005 || curved_uv.x > 0.995 || curved_uv.y < 0.005 || curved_uv.y > 0.995) {
        COLOR = vec4(0.01, 0.03, 0.015, 1.0);
    } else {
        vec4 tex = texture(screen_texture, curved_uv);

        // Green Phosphor conversion & color tint
        float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
        vec3 tinted = luminance * phosphor_color.rgb;
        vec3 result = mix(tex.rgb, tinted, 0.75);

        // Scanlines
        float scanline = sin(curved_uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
        result -= result * (1.0 - scanline) * scanline_intensity;

        // Corner Vignette
        vec2 vig_uv = curved_uv * (1.0 - curved_uv.yx);
        float vig = vig_uv.x * vig_uv.y * 15.0;
        vig = clamp(pow(vig, 0.25 * vignette_intensity), 0.0, 1.0);
        result *= vig;

        // Subtle phosphor cathode flicker
        float flicker = 1.0 + (fract(sin(TIME * flicker_speed) * 43758.5453) - 0.5) * flicker_intensity;
        result *= flicker;

        COLOR = vec4(result, 1.0);
    }
}
