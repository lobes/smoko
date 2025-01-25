const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "smoko",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    exe.linkSystemLibrary("raylib");
    exe.linkLibC();

    // Add ApplicationServices framework for macOS
    if (target.result.os.tag == .macos) {
        exe.linkFramework("ApplicationServices");
        exe.linkFramework("CoreGraphics");
    }

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
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link the same dependencies for tests
    unit_tests.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    unit_tests.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    unit_tests.linkSystemLibrary("raylib");
    unit_tests.linkLibC();

    if (target.result.os.tag == .macos) {
        unit_tests.linkFramework("ApplicationServices");
        unit_tests.linkFramework("CoreGraphics");
    }

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
