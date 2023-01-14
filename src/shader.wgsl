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

struct Util {
    res: vec2<f32>,
    time: f32,
}

@group(0) @binding(0)
var<uniform> util: Util;

fn distance_from_sphere(p: vec3<f32>, c: vec3<f32>, r: f32) -> f32 {
    return length(p - c) - r;
}

fn DE(p: vec3<f32>) -> f32 {
    var c = 4.0;
    var a = p + vec3(c * .5);
    var b = vec3(c);
    var p = a - floor(a / b) * b - vec3(c * .5);
    var dst: f32;
    dst = distance_from_sphere(p, vec3<f32>(0.0), .5);

    var displacement = sin(5.0 * p.x + util.time) * cos(5.0 * p.y + util.time) * sin(5.0 * p.z + util.time) * cos(5.0 * p.z + util.time) * 0.5;

    return dst + displacement;
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

struct MarchResult {
    total_distance: f32,
    min_distance: f32,
    distance: f32,
    steps: f32,
}

fn ray_march(origin: vec3<f32>, direction: vec3<f32>) -> MarchResult {
    var max_iterations: f32 = 100.0;
    var max_distance: f32 = 1000.0;
    var min_distance: f32 = 0.001;

    var res: MarchResult = MarchResult();
    res.distance = min_distance;
    res.steps = 0.0;
    res.min_distance = max_distance;
    res.total_distance = 0.0;

    while res.steps < max_iterations {
        var p: vec3<f32> = origin + direction * res.total_distance;
        res.distance = DE(p);

        if res.distance < min_distance {
            res.steps = res.distance / min_distance;
            return res;
        }

        if res.distance > max_distance {
            break;
        }

        res.total_distance += res.distance;
        res.steps += 1.0;
        res.min_distance = min(res.min_distance, 1.0 * res.distance / res.total_distance);
    }

    return res;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var camera: vec3<f32> = vec3<f32>(-2., -2., -4.0 + util.time * 0.5);
    var uv = (in.clip_position.xy / util.res) * 2. - 1.;
    uv.x *= util.res.x / util.res.y;
    var direction: vec3<f32> = normalize(vec3<f32>(uv, 1.0));

    var res = ray_march(camera, direction);

    var normal = calc_normal(camera + direction * res.total_distance);

    var color = (normal * 0.5 + 0.5);

    var d_s = dot(normal, -normalize(vec3<f32>(5.0, 12.0, 13.0)));
    if (d_s > 0.95) {
        color = vec3<f32>(1.0);
    } 
    color *= clamp(0., 1., smoothstep(-1.0, 1.0, d_s) + 0.2);
    color *= smoothstep(0.0, 1.0, res.min_distance * min(res.total_distance, 1.0)) * 0.3 + 0.7;

    color *= smoothstep(1., 0., res.total_distance * res.total_distance * 0.0008);
    
    return vec4<f32>(color, 1.0);
}
