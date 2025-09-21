shader_type spatial;

// Water properties
uniform float mix_factor = 0.8;
uniform vec4 color_deep : source_color = vec4(0.1, 0.3, 0.5, 1.0);
uniform vec4 color_shallow : source_color = vec4(0.2, 0.5, 0.8, 1.0);
uniform vec4 color_3 : source_color = vec4(0.2, 0.6, 0.8, 1.0);
uniform float fresnel_strength = 2.0;
uniform float wave_speed = 0.8;
uniform float wave_height = 0.1;
uniform float noise_scale = 0.5;

uniform float square_size = 32.0;

varying vec3 world_position;


float random (vec2 uv) { return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123) ; }


// Helper function for 2D hashing
vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// Improved gradient noise
float gradient_noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float a = dot(hash22(i), f);
    float b = dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float c = dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float d = dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));

    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise with multiple octaves
float fractal_noise(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;

    for(int i = 0; i < 3; i++) {
        value += gradient_noise(uv) * amplitude;
        uv *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// Domain warping for organic patterns
float organic_noise(vec2 uv) {
    vec2 q = vec2(
        fractal_noise(uv),
        fractal_noise(uv + vec2(5.2, 1.3))
    );

    vec2 r = vec2(
        fractal_noise(uv + 4.0 * q + vec2(1.7, 9.2)),
        fractal_noise(uv + 4.0 * q + vec2(8.3, 2.8))
    );

    return fractal_noise(uv + 4.0 * r);
}

float fresnel(float amount, vec3 normal, vec3 view) {
    return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0 )), amount);
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Organic displacement using domain warping
    float displacement = organic_noise(world_position.xz * noise_scale + vec2(TIME * wave_speed)) * wave_height;
    VERTEX.y += displacement * 0.5;

    // Secondary high-frequency waves
    VERTEX.y += sin(TIME * 2.0 + world_position.x * 3.0 + world_position.z * 3.0) * wave_height * 0.2;
}

void fragment() {
    // Create flowing organic pattern
    vec2 uv = world_position.xz * noise_scale;
    float pattern = organic_noise(uv + vec2(TIME * wave_speed));

	//random square pattern
	vec2 tiled_uvs = vec2(trunc(UV.x/(1.0/square_size)), trunc(UV.y/(1.0/square_size)));

    // Create directional flow
    vec2 flow_dir = vec2(0.8, 0.6);
    float flow = organic_noise(uv * 0.5 + flow_dir * TIME * 0.3);

    // Combine patterns
    float water_mask = smoothstep(-0.5, 0.5, pattern * 0.8 + flow * 0.4);

    // Color blending
    vec3 base_color = mix(color_shallow.rgb, color_deep.rgb, water_mask);

    // Fresnel effect
    float fresnel = fresnel(fresnel_strength, NORMAL, VIEW);
    base_color += fresnel * 0.3;

	// Rnd noise

	vec3 squares = mix(mix(color_deep.rgb, color_shallow.rgb, sin(TIME + tiled_uvs.x - tiled_uvs.y * random(tiled_uvs))/2.5), color_3.rgb, sin(TIME + tiled_uvs.x - tiled_uvs.y * random(tiled_uvs.yx))/2.0);

    // Final output
	ALBEDO = mix(squares, base_color, mix_factor);
    METALLIC = 0.0;
    ROUGHNESS = 0.0;//mix(0.3, 0.6, 1.0 - fresnel);
    ALPHA = 1.0;
}