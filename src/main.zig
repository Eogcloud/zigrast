const std = @import("std");

pub fn main() void {
    const name = "Zig Developer";
    std.debug.print("Hello, {s}!\n", .{name});

    // Basic variables and types
    const x: i32 = 42;
    var y: f64 = 3.14;
    y += 1.0;

    std.debug.print("x = {}, y = {d:.2}\n", .{ x, y });
}
