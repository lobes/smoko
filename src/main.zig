const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const builtin = @import("builtin");

// Add macOS framework imports
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("ApplicationServices/ApplicationServices.h");
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("unistd.h");
});

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

    // Create an event tap to capture all input first
    const tap = try createInputBlocker();
    defer c.CFRelease(tap);

    // Block input for 10 seconds
    try stdout.print("Input blocked. Sleeping display in 10 seconds...\n", .{});
    var time_remaining: f64 = 10.0;
    while (time_remaining > 0) {
        const run_result = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, 0.1, 0);
        _ = run_result;
        time_remaining -= 0.1;
    }

    // Put displays to sleep
    const result = try displaySleepNow();
    if (result.term.Exited != 0) {
        try stdout.print("\nFailed to put display to sleep\n", .{});
        return error.SetDisplaysToSleepFailed;
    }

    // Block input for another 10 seconds
    try stdout.print("Display sleeping. Releasing input block in 10 seconds...\n", .{});
    time_remaining = 10.0;
    while (time_remaining > 0) {
        const run_result = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, 0.1, 0);
        _ = run_result;
        time_remaining -= 0.1;
    }

    // Disable input blocking
    c.CGEventTapEnable(tap, false);
    try stdout.print("Input block released. Done.\n", .{});
}

/// Brings the specified process to the foreground
pub fn activateProcess(pid: c.pid_t) !void {
    // Get the ProcessSerialNumber for the given pid
    var psn: c.ProcessSerialNumber = undefined;
    if (c.GetProcessForPID(pid, &psn) != 0) {
        return error.ProcessNotFound;
    }

    // Set the process as the frontmost one
    if (c.SetFrontProcess(&psn) != 0) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\nError: Failed to set process as frontmost. Please grant accessibility permissions in:\n", .{});
        try stdout.print("System Settings > Privacy & Security > Accessibility\n\n", .{});
        try stdout.print("Opening System Settings...\n", .{});
        try openAccessibilitySettings();
        return error.FailedToSetFrontProcess;
    }
}

/// Creates an event tap that blocks all input events
fn createInputBlocker() !c.CFMachPortRef {
    const event_mask = c.CGEventMaskBit(c.kCGEventKeyDown) |
        c.CGEventMaskBit(c.kCGEventKeyUp) |
        c.CGEventMaskBit(c.kCGEventMouseMoved) |
        c.CGEventMaskBit(c.kCGEventLeftMouseDown) |
        c.CGEventMaskBit(c.kCGEventLeftMouseUp) |
        c.CGEventMaskBit(c.kCGEventRightMouseDown) |
        c.CGEventMaskBit(c.kCGEventRightMouseUp) |
        c.CGEventMaskBit(c.kCGEventScrollWheel);

    const tap = c.CGEventTapCreate(
        c.kCGSessionEventTap,
        c.kCGHeadInsertEventTap,
        c.kCGEventTapOptionDefault,
        event_mask,
        eventCallback,
        null,
    );

    if (tap == null) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\nError: Failed to create event tap. Please grant accessibility permissions in:\n", .{});
        try stdout.print("System Settings > Privacy & Security > Accessibility\n\n", .{});
        try stdout.print("Opening System Settings...\n", .{});
        try openAccessibilitySettings();
        return error.FailedToCreateEventTap;
    }

    const run_loop_source = c.CFMachPortCreateRunLoopSource(
        c.kCFAllocatorDefault,
        tap,
        0,
    );

    if (run_loop_source == null) {
        c.CFRelease(tap);
        return error.FailedToCreateRunLoopSource;
    }
    defer c.CFRelease(run_loop_source);

    c.CFRunLoopAddSource(
        c.CFRunLoopGetCurrent(),
        run_loop_source,
        c.kCFRunLoopCommonModes,
    );

    c.CGEventTapEnable(tap, true);
    return tap;
}

/// Callback function for the event tap
fn eventCallback(
    proxy: c.CGEventTapProxy,
    event_type: c.CGEventType,
    event: c.CGEventRef,
    user_info: ?*anyopaque,
) callconv(.C) c.CGEventRef {
    _ = proxy;
    _ = event_type;
    _ = event;
    _ = user_info;
    // Return null to block the event
    return null;
}

fn displaySleepNow() !std.process.Child.RunResult {
    return std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{ "pmset", "displaysleepnow" },
    });
}

fn openAccessibilitySettings() !void {
    const result = try std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{
            "open",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        },
    });

    if (result.term.Exited != 0) {
        return error.FailedToOpenSettings;
    }
}
