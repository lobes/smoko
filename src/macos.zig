const std = @import("std");

/// MacOS-specific functionality for setting all displays to sleep
/// Uses the `pmset` command line tool
/// Error set for macOS operations
pub const MacOSError = error{
    SetDisplaysToSleepFailed,
};

/// Attempts to put the display to sleep using `pmset displaysleepnow`
/// Takes minutes as input and waits that duration before sleeping
/// Returns an error if the operation fails
pub fn setDisplaysToSleep(minutes: u32) !void {
    std.debug.print("Waiting {d} minutes before putting display to sleep...\n", .{minutes});

    // Convert minutes to nanoseconds and sleep
    // Use u64 to avoid integer overflow
    const ns_per_minute: u64 = @as(u64, std.time.ns_per_s) * 60;
    const total_ns: u64 = ns_per_minute * minutes;
    std.time.sleep(total_ns);

    std.debug.print("Time's up! Putting display to sleep...\n", .{});

    const result = try std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "pmset", "displaysleepnow" },
    });

    if (result.term.Exited != 0) {
        std.debug.print("Failed to put display to sleep\n", .{});
        return error.SetDisplaysToSleepFailed;
    }
}

test "macos - module compiles" {
    // This test ensures the module at least compiles
    // More specific tests will be added as we implement functionality
    _ = setDisplaysToSleep;
}
