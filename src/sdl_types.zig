const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub fn main() !void {
    // Print SDL_InitFlags type
    const flags = c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO;
    std.debug.print("SDL_INIT_VIDEO type: {any}\n", .{@TypeOf(c.SDL_INIT_VIDEO)});
    std.debug.print("SDL_INIT_AUDIO type: {any}\n", .{@TypeOf(c.SDL_INIT_AUDIO)});
    std.debug.print("Combined flags type: {any}\n", .{@TypeOf(flags)});
    std.debug.print("Combined flags value: {x}\n", .{flags});

    // Print function types
    const init_fn: type = @TypeOf(c.SDL_Init);
    std.debug.print("\nSDL_Init type info:\n", .{});
    std.debug.print("Return type: {any}\n", .{@typeInfo(init_fn).Fn.return_type.?});
    std.debug.print("Param type: {any}\n", .{@typeInfo(init_fn).Fn.params[0].type.?});

    // Test actual initialization
    const result = c.SDL_Init(flags);
    std.debug.print("\nInit result type: {any}\n", .{@TypeOf(result)});
    std.debug.print("Init result value: {any}\n", .{result});
    defer c.SDL_Quit();
}
