// src/renderer/tri.zig
const std = @import("std");

pub const ScreenVertex = struct {
    x: i32,
    y: i32,
    z: f32, // expected in [0, 1]
};

pub const RasterTarget = struct {
    width: i32,
    height: i32,
    pixels: [*]u32, // RGBA8888
    zbuffer: [*]f32,
};

inline fn edge(ax: f32, ay: f32, bx: f32, by: f32, px: f32, py: f32) f32 {
    // Scalar 2D cross product: (B - A) x (P - A)
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax);
}

pub fn drawTriangleFlat(tgt: RasterTarget, v0_in: ScreenVertex, v1_in: ScreenVertex, v2_in: ScreenVertex, color: u32) void {
    // Copy to mutate safely
    var v0 = v0_in;
    var v1 = v1_in;
    var v2 = v2_in;

    // Compute signed area in *screen space* (y-down). Non-zero means drawable.
    const x0: f32 = @floatFromInt(v0.x);
    const y0: f32 = @floatFromInt(v0.y);
    const x1: f32 = @floatFromInt(v1.x);
    const y1: f32 = @floatFromInt(v1.y);
    const x2: f32 = @floatFromInt(v2.x);
    const y2: f32 = @floatFromInt(v2.y);

    var area = edge(x0, y0, x1, y1, x2, y2);
    if (area == 0) return; // degenerate

    // Normalize edge function sign: after this, "inside" means edge >= 0.
    var sign: f32 = 1.0;
    if (area < 0) {
        sign = -1.0;
        area = -area;
        // (we don't need to swap vertices; we just flip the edge signs consistently)
    }
    const inv_area = 1.0 / area;

    // Conservative integer bounds
    var minx: i32 = @max(0, @min(@min(v0.x, v1.x), v2.x));
    var maxx: i32 = @min(tgt.width - 1, @max(@max(v0.x, v1.x), v2.x));
    var miny: i32 = @max(0, @min(@min(v0.y, v1.y), v2.y));
    var maxy: i32 = @min(tgt.height - 1, @max(@max(v0.y, v1.y), v2.y));
    if (minx > maxx or miny > maxy) return;

    var y: i32 = miny;
    while (y <= maxy) : (y += 1) {
        var x: i32 = minx;
        while (x <= maxx) : (x += 1) {
            const px = @as(f32, @floatFromInt(x)) + 0.5;
            const py = @as(f32, @floatFromInt(y)) + 0.5;

            // Edge values, all made consistent by `sign`
            var w0 = edge(x1, y1, x2, y2, px, py) * sign;
            var w1 = edge(x2, y2, x0, y0, px, py) * sign;
            var w2 = edge(x0, y0, x1, y1, px, py) * sign;

            // Simple inside test (no top-left bias yet)
            if (!(w0 >= 0 and w1 >= 0 and w2 >= 0)) continue;

            // Barycentric (normalized)
            w0 *= inv_area;
            w1 *= inv_area;
            w2 *= inv_area;

            // Interpolate depth; scrub NaN and clamp to [0,1] to keep z-test sane
            var z = w0 * v0.z + w1 * v1.z + w2 * v2.z;
            if (std.math.isNan(z)) continue;
            if (z < 0.0) z = 0.0;
            if (z > 1.0) z = 1.0;

            const idx: i32 = y * tgt.width + x;
            if (z < tgt.zbuffer[@intCast(idx)]) {
                tgt.zbuffer[@intCast(idx)] = z;
                tgt.pixels[@intCast(idx)] = color;
            }
        }
    }
}
