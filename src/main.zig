const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const AudioSource = struct {
    spec: c.SDL_AudioSpec,
    buffer: []const u8,
    allocator: std.mem.Allocator,

    pub fn initFromFile(allocator: std.mem.Allocator, path: []const u8) !AudioSource {
        var spec: c.SDL_AudioSpec = undefined;
        var audio_buf: [*c]u8 = undefined;
        var audio_len: u32 = undefined;

        if (!c.SDL_LoadWAV(path.ptr, &spec, &audio_buf, &audio_len)) {
            c.SDL_Log("Couldn't load audio file: %s", c.SDL_GetError());
            return error.SDLAudioLoadFailed;
        }
        errdefer c.SDL_free(audio_buf);

        // Copy to our own buffer
        const buffer = try allocator.alloc(u8, audio_len);
        errdefer allocator.free(buffer);
        @memcpy(buffer, audio_buf[0..audio_len]);
        c.SDL_free(audio_buf);

        return AudioSource{
            .spec = spec,
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    pub fn initSineWave(allocator: std.mem.Allocator, freq: f32, duration_secs: f32) !AudioSource {
        const sample_rate = 44100;
        const total_samples = @as(usize, @intFromFloat(duration_secs * @as(f32, @floatFromInt(sample_rate))));
        const buffer_size = total_samples * @sizeOf(f32);

        const buffer = try allocator.alloc(u8, buffer_size);
        errdefer allocator.free(buffer);

        // Generate sine wave
        const samples = std.mem.bytesAsSlice(f32, buffer);
        for (samples, 0..) |*sample, i| {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
            sample.* = @sin(2.0 * std.math.pi * freq * t);
        }

        var spec: c.SDL_AudioSpec = undefined;
        spec.freq = sample_rate;
        spec.format = c.SDL_AUDIO_F32;
        spec.channels = 1;

        return AudioSource{
            .spec = spec,
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: AudioSource) void {
        self.allocator.free(self.buffer);
    }
};

// Global state
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var stream: ?*c.SDL_AudioStream = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Initialize SDL
    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO)) {
        c.SDL_Log("Couldn't initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    // Set app metadata
    _ = c.SDL_SetAppMetadata("Zig Audio Player", "1.0", "com.example.zig-audio-player");

    // Create window and renderer
    if (!c.SDL_CreateWindowAndRenderer("Audio Player", 640, 480, 0, &window, &renderer)) {
        c.SDL_Log("Couldn't create window/renderer: %s", c.SDL_GetError());
        return error.SDLWindowCreationFailed;
    }
    defer {
        if (renderer) |r| c.SDL_DestroyRenderer(r);
        if (window) |w| c.SDL_DestroyWindow(w);
    }

    // Create audio source (try file first, fall back to sine wave)
    const audio_source = try (AudioSource.initFromFile(allocator, "audio.wav") catch |err| blk: {
        std.debug.print("Failed to load WAV file: {}, falling back to sine wave\n", .{err});
        break :blk AudioSource.initSineWave(allocator, 440.0, 3.0);
    });
    defer audio_source.deinit();

    // Open audio stream
    stream = c.SDL_OpenAudioDeviceStream(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &audio_source.spec, null, null);
    if (stream == null) {
        c.SDL_Log("Couldn't create audio stream: %s", c.SDL_GetError());
        return error.SDLAudioStreamFailed;
    }
    defer if (stream) |s| c.SDL_DestroyAudioStream(s);

    // Start the audio stream
    _ = c.SDL_ResumeAudioStreamDevice(stream);

    // Feed initial audio data
    if (!c.SDL_PutAudioStreamData(stream, audio_source.buffer.ptr, @intCast(audio_source.buffer.len))) {
        c.SDL_Log("Failed to feed initial audio data: %s", c.SDL_GetError());
    }

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

        // Small delay to prevent maxing out CPU
        c.SDL_Delay(1);
    }
}
