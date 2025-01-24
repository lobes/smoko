const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create static library for raylib wrapper
    const wrapper = b.addStaticLibrary(.{
        .name = "raylib_wrapper",
        .target = target,
        .optimize = optimize,
    });

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();
    wrapper.addCSourceFile(.{
        .file = b.path("src/raylib_wrapper.c"),
        .flags = flags.items,
    });
    wrapper.addIncludePath(b.path("src"));
    wrapper.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    wrapper.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    wrapper.linkSystemLibrary("raylib");
    wrapper.linkLibC();

    const exe = b.addExecutable(.{
        .name = "smoko",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(b.path("src"));
    exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    exe.linkLibrary(wrapper);
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
}
