shader_type canvas_item;

// Post-processing CRT Phosphor Green shader for Godot 4
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform vec4 phosphor_color : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform float scanline_count : hint_range(50.0, 1000.0) = 360.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float curvature : hint_range(0.0, 0.15) = 0.016;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.65;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float flicker_speed : hint_range(0.0, 60.0) = 24.0;
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.015;

// Dynamic Combat & Damage FX Uniforms
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.0;
uniform float static_noise : hint_range(0.0, 1.0) = 0.0;
uniform float screen_shake : hint_range(0.0, 0.05) = 0.0;
uniform float roll_speed : hint_range(0.0, 5.0) = 0.0;
uniform vec4 alert_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);

vec2 crt_curve(vec2 uv) {
    vec2 delta = uv - 0.5;
    float delta2 = dot(delta, delta);
    float delta4 = delta2 * delta2;
    float factor = 1.0 + delta2 * curvature + delta4 * curvature;
    // Compensa a distorção em barril para manter 100% da imagem visível sem cortes
    delta *= (1.0 - curvature * 0.85);
    return 0.5 + delta * factor;
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // Screen Shake effect under heavy impact
    if (screen_shake > 0.0) {
        vec2 shake_offset = vec2(
            (fract(sin(TIME * 75.0) * 12345.67) - 0.5) * screen_shake,
            (fract(cos(TIME * 80.0) * 98765.43) - 0.5) * screen_shake
        );
        uv += shake_offset;
    }

    // Vertical V-Sync Roll (brief loss of vertical hold during EMP/heavy impact)
    if (roll_speed > 0.0) {
        uv.y = fract(uv.y + TIME * roll_speed);
    }

    // Horizontal Glitch Line Tearing
    if (glitch_intensity > 0.0) {
        float slice_y = floor(uv.y * 32.0 + TIME * 12.0);
        float slice_noise = fract(sin(slice_y * 12.9898) * 43758.5453);
        if (slice_noise < glitch_intensity * 0.45) {
            float jitter = (fract(sin(slice_y + TIME * 30.0) * 78233.14) - 0.5) * 0.06 * glitch_intensity;
            uv.x += jitter;
        }
    }

    vec2 curved_uv = crt_curve(uv);

    // Screen bezel / cutoff suave nas bordas
    if (curved_uv.x < 0.002 || curved_uv.x > 0.998 || curved_uv.y < 0.002 || curved_uv.y > 0.998) {
        COLOR = vec4(0.01, 0.03, 0.015, 1.0);
    } else {
        // Chromatic Aberration (RGB separation during shield stress / explosion shockwave)
        vec4 tex;
        if (chromatic_aberration > 0.0005) {
            float r = texture(screen_texture, curved_uv + vec2(chromatic_aberration, 0.0)).r;
            float g = texture(screen_texture, curved_uv).g;
            float b = texture(screen_texture, curved_uv - vec2(chromatic_aberration, 0.0)).b;
            tex = vec4(r, g, b, 1.0);
        } else {
            tex = texture(screen_texture, curved_uv);
        }

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

        // Static Noise / Cathode snow burst
        if (static_noise > 0.0) {
            float noise = fract(sin(dot(curved_uv + vec2(TIME * 3.0, -TIME * 2.0), vec2(12.9898, 78.233))) * 43758.5453);
            result = mix(result, vec3(noise * 0.9 + 0.1), static_noise * 0.4);
        }

        // Phosphor cathode flicker (spikes under low power or damage)
        float current_flicker_int = flicker_intensity + (glitch_intensity * 0.04);
        float flicker = 1.0 + (fract(sin(TIME * flicker_speed) * 43758.5453) - 0.5) * current_flicker_int;
        result *= flicker;

        // Alert tint overlay (ex: Red Alert pulse or hull breach warning)
        if (alert_tint.a > 0.0) {
            result = mix(result, alert_tint.rgb * (luminance * 1.5 + 0.15), alert_tint.a);
        }

        COLOR = vec4(result, 1.0);
    }
}
