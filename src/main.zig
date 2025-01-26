const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

// Global state (similar to the C static variables)
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var stream: ?*c.SDL_AudioStream = null;
var current_sine_sample: i32 = 0;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Initialize SDL
    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO)) {
        c.SDL_Log("Couldn't initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    // Set app metadata
    _ = c.SDL_SetAppMetadata("Zig Audio Simple Playback", "1.0", "com.example.zig-audio-simple-playback");

    // Create window and renderer
    if (!c.SDL_CreateWindowAndRenderer("examples/audio/simple-playback", 640, 480, 0, &window, &renderer)) {
        c.SDL_Log("Couldn't create window/renderer: %s", c.SDL_GetError());
        return error.SDLWindowCreationFailed;
    }
    defer {
        if (renderer) |r| c.SDL_DestroyRenderer(r);
        if (window) |w| c.SDL_DestroyWindow(w);
    }

    // Setup audio specification
    var spec: c.SDL_AudioSpec = undefined;
    spec.channels = 1;
    spec.format = c.SDL_AUDIO_F32;
    spec.freq = 8000;

    // Open audio stream
    stream = c.SDL_OpenAudioDeviceStream(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, null, null);
    if (stream == null) {
        c.SDL_Log("Couldn't create audio stream: %s", c.SDL_GetError());
        return error.SDLAudioStreamFailed;
    }
    defer if (stream) |s| c.SDL_DestroyAudioStream(s);

    // Start the audio stream
    _ = c.SDL_ResumeAudioStreamDevice(stream);

    // Main loop
    main_loop: while (true) {
        // Handle events
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => break :main_loop,
                else => {},
            }
        }

        // Audio processing
        const minimum_audio = @as(i32, 8000 * @sizeOf(f32)) / 2;
        if (c.SDL_GetAudioStreamAvailable(stream) < minimum_audio) {
            var samples: [512]f32 = undefined;

            // Generate 440Hz sine wave
            for (0..samples.len) |i| {
                const freq: f32 = 440.0;
                const phase = @as(f32, @floatFromInt(current_sine_sample)) * freq / 8000.0;
                samples[i] = @sin(phase * 2.0 * std.math.pi);
                current_sine_sample += 1;
            }

            // Wrap around to avoid floating-point errors
            current_sine_sample = @rem(current_sine_sample, 8000);

            // Feed the audio data
            if (!c.SDL_PutAudioStreamData(stream, &samples, @sizeOf(@TypeOf(samples)))) {
                c.SDL_Log("Failed to feed audio data: %s", c.SDL_GetError());
            }
        }

        // Small delay to prevent maxing out CPU
        c.SDL_Delay(1);
    }
}
