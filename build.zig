const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "smoko",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .cwd_relative = "/usr/local/include/SDL3" });
    exe.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    exe.linkSystemLibrary("SDL3");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Audio example executable
    const audio_example = b.addExecutable(.{
        .name = "audio-example",
        .root_source_file = .{ .cwd_relative = "src/audio_example.zig" },
        .target = target,
        .optimize = optimize,
    });

    audio_example.addIncludePath(.{ .cwd_relative = "/usr/local/include/SDL3" });
    audio_example.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    audio_example.linkSystemLibrary("SDL3");

    b.installArtifact(audio_example);

    const run_audio = b.addRunArtifact(audio_example);
    run_audio.step.dependOn(b.getInstallStep());

    const run_audio_step = b.step("run-audio", "Run the audio example");
    run_audio_step.dependOn(&run_audio.step);

    // WAV generator executable
    const wav_gen = b.addExecutable(.{
        .name = "generate-wav",
        .root_source_file = .{ .cwd_relative = "src/generate_wav.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(wav_gen);

    const run_wav_gen = b.addRunArtifact(wav_gen);
    run_wav_gen.step.dependOn(b.getInstallStep());

    const run_wav_gen_step = b.step("run-wav", "Run the WAV generator");
    run_wav_gen_step.dependOn(&run_wav_gen.step);

    // WAV loader executable
    const wav_load = b.addExecutable(.{
        .name = "load-wav",
        .root_source_file = .{ .cwd_relative = "src/load-wav.zig" },
        .target = target,
        .optimize = optimize,
    });

    wav_load.addIncludePath(.{ .cwd_relative = "/usr/local/include/SDL3" });
    wav_load.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    wav_load.linkSystemLibrary("SDL3");

    b.installArtifact(wav_load);

    const run_wav_load = b.addRunArtifact(wav_load);
    run_wav_load.step.dependOn(&run_wav_gen.step); // Depend on WAV generation
    run_wav_load.step.dependOn(b.getInstallStep());

    const run_wav_load_step = b.step("run-wav-load", "Run the WAV loader");
    run_wav_load_step.dependOn(&run_wav_load.step);

    // Add test step
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addIncludePath(.{ .cwd_relative = "/usr/local/include/SDL3" });
    unit_tests.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    unit_tests.linkSystemLibrary("SDL3");

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const sdl_types = b.addExecutable(.{
        .name = "sdl-types",
        .root_source_file = .{ .cwd_relative = "src/sdl_types.zig" },
        .target = target,
        .optimize = optimize,
    });

    sdl_types.addIncludePath(.{ .cwd_relative = "/usr/local/include/SDL3" });
    sdl_types.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    sdl_types.linkSystemLibrary("SDL3");

    b.installArtifact(sdl_types);

    const run_types = b.addRunArtifact(sdl_types);
    run_types.step.dependOn(b.getInstallStep());

    const run_types_step = b.step("run-types", "Run the SDL type inspection");
    run_types_step.dependOn(&run_types.step);
}
