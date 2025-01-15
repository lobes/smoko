const std = @import("std");
const macos = @import("macos.zig");

pub fn main() !void {
    // Add command line argument parsing
    // TODO: Add timer functionality

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Ensure we have exactly 2 arguments (program name + delay minutes)
    if (args.len != 2) {
        std.debug.print("Usage: {s} <minutes>\n", .{args[0]});
        std.debug.print("Example: {s} 47 - Put displays to sleep after 47 minutes\n", .{args[0]});
        std.process.exit(1);
    }

    // Parse the minutes argument
    const minutes = std.fmt.parseInt(u32, args[1], 10) catch {
        std.debug.print("Error: Minutes must be a positive number\n", .{});
        std.process.exit(1);
    };

    std.debug.print("Will put displays to sleep in {d} minutes\n", .{minutes});

    try macos.setDisplaysToSleep(minutes);
}

test "simple test" {
    // TODO: Replace this test with more relevant ones
    // For now, we just ensure everything compiles
    _ = macos;
}
