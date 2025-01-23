const std = @import("std");
const os = @import("os/os.zig").os;
const builtin = @import("builtin");

pub const InputBlocker = struct {
    tap: os.EventTap,

    pub fn init() !InputBlocker {
        const tap = try os.createInputBlocker(eventCallback);
        return InputBlocker{ .tap = tap };
    }

    pub fn deinit(self: *InputBlocker) void {
        os.disableInputBlocker(self.tap);
    }

    pub fn block(seconds: u32, message: []const u8, writer: anytype) !void {
        try writer.print("{s} {d} seconds...\n", .{ message, seconds });

        var time_remaining: f64 = @floatFromInt(seconds);
        while (time_remaining > 0) {
            os.runEventLoop(0.1);
            time_remaining -= 0.1;
        }
    }
};

// Use concrete types for C callback
const CGEventTapProxy = if (builtin.os.tag == .macos)
    os.c.CGEventTapProxy
else
    *anyopaque;

const CGEventType = if (builtin.os.tag == .macos)
    os.c.CGEventType
else
    c_int;

const CGEventRef = if (builtin.os.tag == .macos)
    os.c.CGEventRef
else
    ?*anyopaque;

fn eventCallback(
    proxy: CGEventTapProxy,
    event_type: CGEventType,
    _: CGEventRef,
    user_info: ?*anyopaque,
) callconv(.C) CGEventRef {
    _ = proxy;
    _ = event_type;
    _ = user_info;
    return null;
}
