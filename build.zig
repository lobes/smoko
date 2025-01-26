const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add renderer module first
    const renderer_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/renderer.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "smoko",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    exe.linkSystemLibrary("raylib");

    // Add module to executable
    exe.root_module.addImport("renderer", renderer_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Add test step
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    unit_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    unit_tests.linkSystemLibrary("raylib");

    // Add module to tests
    unit_tests.root_module.addImport("renderer", renderer_module);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
