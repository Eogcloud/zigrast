const std = @import("std");
const math3d = @import("../math/mod.zig");

pub const Vertex = struct {
    position: math3d.Vec3,
    color: u32,

    pub fn init(position: math3d.Vec3, color: u32) Vertex {
        return Vertex{
            .position = position,
            .color = color,
        };
    }
};

pub const Triangle = struct {
    indices: [3]u32,

    pub fn init(a: u32, b: u32, c: u32) Triangle {
        return Triangle{
            .indices = .{ a, b, c },
        };
    }
};

pub const Mesh = struct {
    vertices: []Vertex,
    triangles: []Triangle,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Mesh {
        return Mesh{
            .vertices = &.{},
            .triangles = &.{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Mesh) void {
        if (self.vertices.len > 0) self.allocator.free(self.vertices);
        if (self.triangles.len > 0) self.allocator.free(self.triangles);
    }

    pub fn setVertices(self: *Mesh, vertices: []const Vertex) !void {
        if (self.vertices.len > 0) self.allocator.free(self.vertices);
        self.vertices = try self.allocator.dupe(Vertex, vertices);
    }

    pub fn setTriangles(self: *Mesh, triangles: []const Triangle) !void {
        if (self.triangles.len > 0) self.allocator.free(self.triangles);
        self.triangles = try self.allocator.dupe(Triangle, triangles);
    }

    // Helper function to create a cube mesh
    pub fn createCube(allocator: std.mem.Allocator) !Mesh {
        var mesh = Mesh.init(allocator);

        const vertices = [_]Vertex{
            // Front face
            Vertex.init(math3d.Vec3.init(-1, -1, 1), 0xFF0000FF), // 0: Red
            Vertex.init(math3d.Vec3.init(1, -1, 1), 0x00FF00FF), // 1: Green
            Vertex.init(math3d.Vec3.init(1, 1, 1), 0x0000FFFF), // 2: Blue
            Vertex.init(math3d.Vec3.init(-1, 1, 1), 0xFFFF00FF), // 3: Yellow

            // Back face
            Vertex.init(math3d.Vec3.init(-1, -1, -1), 0xFF00FFFF), // 4: Magenta
            Vertex.init(math3d.Vec3.init(1, -1, -1), 0x00FFFFFF), // 5: Cyan
            Vertex.init(math3d.Vec3.init(1, 1, -1), 0xFFFFFFFF), // 6: White
            Vertex.init(math3d.Vec3.init(-1, 1, -1), 0x808080FF), // 7: Gray
        };

        const triangles = [_]Triangle{
            // Front face
            Triangle.init(0, 1, 2), Triangle.init(0, 2, 3),
            // Back face
            Triangle.init(4, 6, 5), Triangle.init(4, 7, 6),
            // Left face
            Triangle.init(4, 0, 3), Triangle.init(4, 3, 7),
            // Right face
            Triangle.init(1, 5, 6), Triangle.init(1, 6, 2),
            // Top face
            Triangle.init(3, 2, 6), Triangle.init(3, 6, 7),
            // Bottom face
            Triangle.init(4, 1, 0), Triangle.init(4, 5, 1),
        };

        try mesh.setVertices(&vertices);
        try mesh.setTriangles(&triangles);

        return mesh;
    }
};
