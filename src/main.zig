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
    \\                  "Down tools. Smoko."
    \\
    \\  smoko 5
    \\
    \\     -- Display countdown in mins. Set all displays to sleep
    \\        after countdown
    \\
    \\                 "Going on smoko in 5."
    \\
    \\
;

// Testing direct .h bindings. Feels smooth
const c = @cImport(@cInclude("stdio.h"));
pub fn main() !void {
    // _ = c.printf("c stdio\n");

    // Gettings args
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const args = try std.process.argsAlloc(arena_state.allocator());

    // No extra args, sleep immediately
    if (args.len == 1) try sleepDisplays(0);

    var i: u32 = 1;
    while (args.len > i) : (i += 1) {
        if (std.fmt.parseInt(u32, args[i], 10)) |number| {
            try sleepDisplays(number);
        } else |_| continue;

        // Print usage
        if (mem.eql(u8, args[i], "-h") or mem.eql(u8, args[i], "--help")) {
            try std.io.getStdOut().writer().writeAll(HELP_TEXT);
            return std.process.cleanExit();
        }
    }
}

fn sleepDisplays(minutes: u32) anyerror!void {
    // Convert minutes to nanoseconds and sleep
    var mins_remaining: u32 = minutes;
    const stdout = std.io.getStdOut().writer();

    while (mins_remaining > 0) {
        try stdout.print("\rSmoko in {d} minutes.", .{mins_remaining});
        std.time.sleep(std.time.ns_per_min);
        mins_remaining -= 1;
    }

    try stdout.print("\rTime for smoko.                 \n", .{});
    std.time.sleep(std.time.ns_per_s * 3);

    const result = try std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "pmset", "displaysleepnow" },
    });

    if (result.term.Exited != 0) {
        try stdout.print("\nFailed to put display to sleep\n", .{});
        return error.SetDisplaysToSleepFailed;
    }
}
