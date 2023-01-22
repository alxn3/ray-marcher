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

fn s_max(a: f32, b: f32, k: f32) -> f32 {
    return log(exp(k * a) + exp(k * b)) / k;
}

fn s_min(a: f32, b: f32, k: f32) -> f32 {
    return -log(exp(-k * a) + exp(-k * b)) / k;
}

fn de_sphere(p: vec3<f32>, s: vec3<f32>, r: f32) -> f32 {
    return length(p - s) - r;
}

fn de_box(p: vec3<f32>, b: vec3<f32>) -> f32 {
    var q: vec3<f32> = abs(p) - b;
    return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

fn de_round_box(p: vec3<f32>, b: vec3<f32>, r: f32) -> f32 {
    var d: vec3<f32> = abs(p) - b;
    return length(max(d, vec3<f32>(0.0))) + min(max(d.x, max(d.y, d.z)), 0.0) - r;
}

fn de_box_frame(p: vec3<f32>, b: vec3<f32>, e: f32) -> f32 {
    var p = abs(p) - b;
    var q = abs(p + e) - e;
    return min(min(
        length(max(vec3<f32>(p.x, q.y, q.z), vec3<f32>(0.0))) + min(max(p.x, max(q.y, q.z)), 0.0),
        length(max(vec3<f32>(q.x, p.y, q.z), vec3<f32>(0.0))) + min(max(q.x, max(p.y, q.z)), 0.0)
    ), length(max(vec3<f32>(q.x, q.y, p.z), vec3<f32>(0.0))) + min(max(q.x, max(q.y, p.z)), 0.0));
}

fn de_torus(p: vec3<f32>, t: vec2<f32>) -> f32 {
    var q: vec2<f32> = vec2<f32>(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

fn de_capped_torus(p: vec3<f32>, sc: vec2<f32>, ra: f32, rb: f32) -> f32 {
    var p = vec3<f32>(abs(p.x), p.y, p.z);
    var k = select(dot(p.xy, sc), length(p.xy), sc.y * p.x > sc.x * p.y);
    return sqrt(dot(p, p) + ra * ra - 2.0 * ra * k) - rb;
}

fn de_link(p: vec3<f32>, le: f32, r1: f32, r2: f32) -> f32 {
    var q = vec3<f32>(p.x, max(abs(p.y) - le, 0.0), p.z);
    return length(vec2<f32>(length(q.xy) - r1, q.z)) - r2;
}

fn de_cylinder(p: vec3<f32>, c: vec3<f32>) -> f32 {
    return length(p.xz - c.xy) - c.z;
}

fn de_cone(p: vec3<f32>, c: vec2<f32>, h: f32) -> f32 {
    var q = length(p.xz);
    return max(dot(c.xy, vec2<f32>(q, p.y)), -h - p.y);
}

fn de_infinite_cone(p: vec3<f32>, c: vec2<f32>) -> f32 {
    var q = vec2<f32>(length(p.xz), -p.y);
    var d = length(q - c * max(dot(q, c), 0.0));
    return d * select(1.0, -1.0, q.x * c.y - q.y * c.x < 0.0);
}

fn de_plane(p: vec3<f32>, n: vec3<f32>, h: f32) -> f32 {
    return dot(p, n) + h;
}

fn DE(p: vec3<f32>) -> f32 {
    var c = 4.0;
    var a = p + vec3(c * .5);
    var b = vec3(c, c, c * 2.0);
    var p = a - floor(a / b) * b - vec3(c * .5);
    var dst: f32;
    // dst = de_sphere(p, vec3<f32>(0.0), .5);
    dst = de_plane(p, vec3<f32>(-9.0, 2.0, -7.0), 0.0);
    dst = max(dst, de_sphere(p, vec3<f32>(0.0, 0.0, 0.0), 1.0));

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
    if d_s > 0.95 {
        color = vec3<f32>(1.0);
    }
    color *= clamp(0., 1., smoothstep(-1.0, 1.0, d_s) + 0.2);
    color *= smoothstep(0.0, 1.0, res.min_distance * min(res.total_distance, 1.0)) * 0.3 + 0.7;

    color *= smoothstep(1., 0., res.total_distance * res.total_distance * 0.0008);

    return vec4<f32>(color, 1.0);
}
