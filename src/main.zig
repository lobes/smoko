const std = @import("std");
const doom = @import("doom.zig");
const Renderer = @import("renderer").Renderer;
const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize window with Doom's original resolution
    ray.InitWindow(320, 200, "SMOKO DOOM");
    ray.SetTargetFPS(60);
    defer ray.CloseWindow();

    var r = try Renderer.init(allocator, .{
        .width = 320,
        .height = 200,
        .vsync = true,
    });
    defer r.deinit();

    // Create texture for displaying our renderer's buffer
    const image = ray.Image{
        .data = @ptrCast(r.buffer.ptr),
        .width = @intCast(r.width),
        .height = @intCast(r.height),
        .mipmaps = 1,
        .format = ray.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
    };
    const texture = ray.LoadTextureFromImage(image);
    defer ray.UnloadTexture(texture);

    // Draw a test pattern
    for (0..r.buffer.len) |i| {
        const x = @mod(i, r.width);
        const y = i / r.width;
        r.buffer[i] = if (@mod(x + y, 2) == 0) 0xFF0000FF else 0x000000FF;
    }

    var game = try doom.Game.init(allocator, &r);
    defer game.deinit();

    // Game loop
    while (!ray.WindowShouldClose()) {
        // Handle input
        if (ray.IsKeyDown(ray.KEY_W)) game.player.moveForward(5.0);
        if (ray.IsKeyDown(ray.KEY_S)) game.player.moveForward(-5.0);
        if (ray.IsKeyDown(ray.KEY_A)) game.player.rotate(-0.1);
        if (ray.IsKeyDown(ray.KEY_D)) game.player.rotate(0.1);

        game.update(ray.GetFrameTime());
        try game.render();

        // Update texture with our renderer's buffer
        ray.UpdateTexture(texture, r.buffer.ptr);

        // Draw to screen
        ray.BeginDrawing();
        ray.ClearBackground(ray.BLACK);
        ray.DrawTexture(texture, 0, 0, ray.WHITE);
        ray.EndDrawing();
    }
}
