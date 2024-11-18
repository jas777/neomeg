const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.host;
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "neomeg",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize
    });

    // const serial = b.dependency("serial", .{
    //     .target = target,
    //     .optimize = optimize
    // });
    // exe.root_module.addImport("serial", serial.module("serial"));

    exe.linkLibC();
    exe.linkSystemLibrary2("gtk4", .{ .use_pkg_config = .force });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
