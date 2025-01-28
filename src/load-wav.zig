const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

// Global state (similar to the C static variables)
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var stream: ?*c.SDL_AudioStream = null;
var wav_data: ?[*]u8 = null;
var wav_data_len: u32 = 0;

fn sdlNeg(ret: c_int) !void {
    if (ret >= 0) return;
    return error.SDLError;
}

pub fn main() !void {
    // Initialize SDL with proper error checking
    const init_flags: c.SDL_InitFlags = c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO;
    if (!c.SDL_Init(init_flags)) {
        c.SDL_Log("Couldn't initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    // Set app metadata
    _ = c.SDL_SetAppMetadata("Zig Audio Load Wave", "1.0", "com.example.zig-audio-load-wav");

    // Create window and renderer with proper error checking
    if (!c.SDL_CreateWindowAndRenderer("examples/audio/load-wav", 640, 480, 0, &window, &renderer)) {
        c.SDL_Log("Couldn't create window/renderer: %s", c.SDL_GetError());
        return error.SDLWindowCreationFailed;
    }
    defer {
        if (renderer) |r| c.SDL_DestroyRenderer(r);
        if (window) |w| c.SDL_DestroyWindow(w);
    }

    // Load the .wav file
    var spec: c.SDL_AudioSpec = undefined;

    // Load the WAV file from the zig-out/bin directory
    if (!c.SDL_LoadWAV("zig-out/bin/sample.wav", &spec, &wav_data, &wav_data_len)) {
        c.SDL_Log("Couldn't load .wav file: %s", c.SDL_GetError());
        return error.SDLLoadWAVFailed;
    }
    defer if (wav_data) |data| c.SDL_free(data);

    // Create audio stream
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

        // Audio processing - feed more data if needed
        if (stream) |s| {
            if (wav_data) |data| {
                if (c.SDL_GetAudioStreamAvailable(s) < @as(i32, @intCast(wav_data_len))) {
                    if (!c.SDL_PutAudioStreamData(s, data, @as(c_int, @intCast(wav_data_len)))) {
                        c.SDL_Log("Failed to feed audio data: %s", c.SDL_GetError());
                    }
                }
            }
        }

        // Clear the renderer
        if (renderer) |r| {
            if (!c.SDL_RenderClear(r)) {
                c.SDL_Log("Failed to clear renderer: %s", c.SDL_GetError());
            }
            if (!c.SDL_RenderPresent(r)) {
                c.SDL_Log("Failed to present renderer: %s", c.SDL_GetError());
            }
        }

        // Small delay to prevent maxing out CPU
        c.SDL_Delay(1);
    }
}
