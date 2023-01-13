// Vertex shader

struct VertexInput {
    @location(0) position: vec3<f32>,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
};

@vertex
fn vs_main(
    model: VertexInput,
) -> VertexOutput {
    var out: VertexOutput;
    out.clip_position = vec4<f32>(model.position, 1.0);
    return out;
}

// Fragment shader

@group(0) @binding(0)
var<uniform> resolution: vec4<f32>;

fn distance_from_sphere(p: vec3<f32>, c: vec3<f32>, r: f32) -> f32 {
    return length(p - c) - r;
}

fn DE(p: vec3<f32>) -> f32 {
    var c = 8.0;
    var a = p + vec3(c*.5);
    var b = vec3(c);
    var p = a - floor(a / b) * b - vec3(c*.5);
    var dst: f32;
    dst = distance_from_sphere(p, vec3<f32>(0.0), 1.0);
    return dst;
}

fn calc_normal(p: vec3<f32>) -> vec3<f32> {
    var eps: f32 = 0.001;
    var n: vec3<f32> = vec3<f32>(
        DE(p + vec3<f32>(eps, 0.0, 0.0)) - DE(p - vec3<f32>(eps, 0.0, 0.0)),
        DE(p + vec3<f32>(0.0, eps, 0.0)) - DE(p - vec3<f32>(0.0, eps, 0.0)),
        DE(p + vec3<f32>(0.0, 0.0, eps)) - DE(p - vec3<f32>(0.0, 0.0, eps)),
    );
    return normalize(n);
}

fn ray_march(origin: vec3<f32>, direction: vec3<f32>) -> vec3<f32> {
    var t: f32 = 0.0;
    var i: i32 = 0;
    var max_iterations: i32 = 100;
    var max_distance: f32 = 1000.0;
    var min_distance: f32 = 0.001;

    while (i < max_iterations) {
        var p: vec3<f32> = origin + direction * t;
        var d: f32 = DE(p);
        
        if (d < min_distance) {
            return calc_normal(p) * 0.5 + 0.5 * (1. - length(p) / max_distance);
        }

        if (d > max_distance) {
            break;
        }

        t += d;
        i += 1;
    }

    return vec3<f32>(0.0);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var camera: vec3<f32> = vec3<f32>(0., 0., -4.0);
    var uv = (in.clip_position.xy / resolution.xy) * 2. - 1.;
    uv.x *= resolution.x / resolution.y;
    var direction: vec3<f32> = vec3<f32>(uv, 1.0);

    return vec4<f32>(ray_march(camera, direction), 1.0);
}
