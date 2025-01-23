const std = @import("std");
const os = @import("os/os.zig").os;

pub const DisplayManager = struct {
    displays: []os.Display,
    display_count: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_displays: u32) !DisplayManager {
        var displays = try allocator.alloc(os.Display, max_displays);
        var display_count: u32 = 0;

        try os.getDisplays(displays, &display_count);

        return DisplayManager{
            .displays = displays[0..display_count],
            .display_count = display_count,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DisplayManager) void {
        self.allocator.free(self.displays);
    }

    pub fn captureAll(self: *DisplayManager, writer: anytype) !void {
        try writer.print("Found {d} displays:\n", .{self.display_count});

        for (self.displays, 0..) |display, i| {
            try writer.print("Capturing display {d}...\n", .{i});
            os.captureDisplay(display) catch |err| {
                try writer.print("\nFailed to capture display {d}: {any}\n", .{ i, err });
                continue;
            };
        }
    }

    pub fn releaseAll(self: *DisplayManager) void {
        for (self.displays) |display| {
            os.releaseDisplay(display);
        }
    }

    pub fn showAllCursors(self: *DisplayManager) void {
        for (self.displays) |display| {
            os.showCursor(display);
        }
    }
};
