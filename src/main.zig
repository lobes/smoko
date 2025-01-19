const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const builtin = @import("builtin");

const HELP_TEXT =
    \\Usage: smoko <time>
    \\
    \\Examples:
    \\  smoko
    \\
    \\     -- Immediately set all displays to sleep
    \\
    \\                 "Down tools. Smoko."
    \\
    \\  smoko [1h5m|1015pm|2100]
    \\
    \\     -- Handles many time formats:
    \\          - 0h0m will execute now (may aswell just type smoko)
    \\          - 0000 will execute at midnight
    \\          - 0000pm will execute at noon
    \\     -- Display countdown in mins. Set all displays to sleep
    \\        after countdown
    \\
    \\                 "Going on smoko in 5."
    \\
    \\
;

const c = @cImport(@cInclude("stdio.h"));
pub fn main() !void {
    // Testing direct .h bindings. Feels smooth
    // _ = c.printf("c stdio\n");

    // Gettings args
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const args = try std.process.argsAlloc(arena_state.allocator());
    if (args.len == 1) try sleepDisplays(1);
    var i: u32 = 1;
    while (args.len > i) : (i += 1) {
        if (mem.eql(u8, args[i], "-h") or mem.eql(u8, args[i], "-h")) {
            try std.io.getStdOut().writer().writeAll(HELP_TEXT);
            return std.process.cleanExit();
        } else {
            const number = std.fmt.parseInt(u32, args[i], 0) catch continue;
            try sleepDisplays(number);
        }
    }
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}

fn sleepDisplays(minutes: u32) anyerror!void {
    // Convert minutes to nanoseconds and sleep
    // Use u64 to avoid integer overflow
    const ns_per_minute: u64 = @as(u64, std.time.ns_per_min);
    const total_ns: u64 = ns_per_minute * minutes;

    std.time.sleep(total_ns);
    std.debug.print("Time for smoko.\n", .{});
    std.time.sleep(std.time.ns_per_s * 7);

    const result = try std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "pmset", "displaysleepnow" },
    });

    if (result.term.Exited != 0) {
        std.debug.print("Failed to put display to sleep\n", .{});
        return error.SetDisplaysToSleepFailed;
    }
}
