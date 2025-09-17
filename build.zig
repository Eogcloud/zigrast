const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigrast",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link SDL3 (using local vendored copy)
    exe.linkSystemLibrary("SDL3.dll");
    exe.linkLibC();

    // Add SDL3 include and lib paths (local vendored copy - x86_64)
    exe.addIncludePath(b.path("libs/SDL3/SDL3-3.2.22/x86_64-w64-mingw32/include"));
    exe.addLibraryPath(b.path("libs/SDL3/SDL3-3.2.22/x86_64-w64-mingw32/lib"));

    // Copy SDL3.dll to output directory automatically
    b.installBinFile("libs/SDL3/SDL3-3.2.22/x86_64-w64-mingw32/bin/SDL3.dll", "SDL3.dll");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
