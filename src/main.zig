const std = @import("std");
const process = std.process;
const heap = std.heap;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;
const time = std.time;
const builtin = @import("builtin");
const Config = @import("config.zig").Config;
const DisplayManager = @import("display.zig").DisplayManager;
const InputBlocker = @import("input.zig").InputBlocker;

// OS-specific imports done at comptime
const os_impl = switch (builtin.os.tag) {
    .macos => struct {
        const c = @cImport({
            @cInclude("ApplicationServices/ApplicationServices.h");
            @cInclude("CoreGraphics/CoreGraphics.h");
        });

        pub const EventTap = ?c.CFMachPortRef;
        pub const Display = u32;

        // Helper functions for CoreFoundation
        pub fn releaseCF(ref: anytype) void {
            if (ref) |r| {
                c.CFRelease(@ptrCast(r));
            }
        }

        pub fn createInputBlocker() !EventTap {
            const event_mask = c.CGEventMaskBit(c.kCGEventKeyDown) |
                c.CGEventMaskBit(c.kCGEventKeyUp) |
                c.CGEventMaskBit(c.kCGEventMouseMoved) |
                c.CGEventMaskBit(c.kCGEventLeftMouseDown) |
                c.CGEventMaskBit(c.kCGEventLeftMouseUp) |
                c.CGEventMaskBit(c.kCGEventRightMouseDown) |
                c.CGEventMaskBit(c.kCGEventRightMouseUp) |
                c.CGEventMaskBit(c.kCGEventScrollWheel) |
                c.CGEventMaskBit(c.kCGEventFlagsChanged);

            const tap = c.CGEventTapCreate(
                c.kCGSessionEventTap,
                c.kCGHeadInsertEventTap,
                c.kCGEventTapOptionDefault,
                event_mask,
                eventCallback,
                null,
            );

            if (tap == null) {
                return error.FailedToCreateEventTap;
            }

            const run_loop_source = c.CFMachPortCreateRunLoopSource(
                c.kCFAllocatorDefault,
                tap,
                0,
            );

            if (run_loop_source == null) {
                releaseCF(tap);
                return error.FailedToCreateRunLoopSource;
            }
            defer releaseCF(run_loop_source);

            c.CFRunLoopAddSource(
                c.CFRunLoopGetCurrent(),
                run_loop_source,
                c.kCFRunLoopCommonModes,
            );

            c.CGEventTapEnable(tap, true);
            return tap;
        }

        pub fn disableInputBlocker(tap: EventTap) void {
            if (tap) |t| {
                c.CGEventTapEnable(t, false);
            }
        }

        pub fn getDisplays(displays: []Display, display_count: *u32) !void {
            const max_displays: u32 = @intCast(displays.len);
            const result = c.CGGetOnlineDisplayList(max_displays, displays.ptr, display_count);
            if (result != 0) return error.GetDisplayListFailed;
        }

        pub fn captureDisplay(display: Display) !void {
            const result = c.CGDisplayCapture(display);
            if (result != 0) return error.DisplayCaptureFailed;
            _ = c.CGDisplaySetDisplayMode(display, null, null);
        }

        pub fn releaseDisplay(display: Display) void {
            _ = c.CGDisplayShowCursor(display);
            _ = c.CGDisplayRelease(display);
        }

        pub fn showCursor(display: Display) void {
            _ = c.CGDisplayShowCursor(display);
        }

        pub fn openAccessibilitySettings() !void {
            const result = try process.Child.run(.{
                .allocator = heap.page_allocator,
                .argv = &[_][]const u8{
                    "open",
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                },
            });

            if (result.term.Exited != 0) {
                return error.FailedToOpenSettings;
            }
        }
    },
    .windows => struct {
        const c = @cImport({
            @cInclude("windows.h");
        });

        pub const EventTap = ?*anyopaque; // Windows equivalent would be a hook
        pub const Display = c.HMONITOR;

        pub fn createInputBlocker() !EventTap {
            // TODO: Implement Windows input blocking using SetWindowsHookEx
            return error.Unimplemented;
        }

        pub fn disableInputBlocker(tap: EventTap) void {
            _ = tap;
            // TODO: Implement Windows hook removal
        }

        pub fn getDisplays(displays: []Display, display_count: *u32) !void {
            _ = displays;
            _ = display_count;
            // TODO: Implement Windows display enumeration
            return error.Unimplemented;
        }

        pub fn captureDisplay(display: Display) !void {
            _ = display;
            // TODO: Implement Windows display capture
            return error.Unimplemented;
        }

        pub fn releaseDisplay(display: Display) void {
            _ = display;
            // TODO: Implement Windows display release
        }

        pub fn showCursor(display: Display) void {
            _ = display;
            // TODO: Implement Windows cursor show
        }

        pub fn openAccessibilitySettings() !void {
            // TODO: Open Windows accessibility settings
            return error.Unimplemented;
        }
    },
    else => @compileError("Unsupported operating system"),
};

const Global = struct {
    pub const supported_os = struct {
        pub const macos = void{};
    };

    config: Config,
    stdout: fs.File.Writer,
    arena: std.heap.ArenaAllocator,

    fn init() !Global {
        return Global{
            .config = undefined,
            .stdout = io.getStdOut().writer(),
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
        };
    }

    fn deinit(self: *Global) void {
        self.arena.deinit();
    }
};

var g: Global = undefined;

const HELP_TEXT =
    \\Usage: smoko <time>
    \\
    \\Examples:
    \\  smoko
    \\
    \\     -- Immediately blank all displays
    \\                  "Down tools. Smoko."
    \\
    \\  smoko 5
    \\
    \\     -- Display countdown in mins. Blank all displays
    \\        after countdown
    \\
    \\                 "Going on smoko in 5."
    \\
    \\
;

/// Smoko - A command-line tool for enforcing screen breaks
///
/// This program helps enforce screen breaks by:
/// 1. Optionally counting down for a specified number of minutes
/// 2. Blocking all keyboard and mouse input
/// 3. Blanking all connected displays
/// 4. Waiting for a configured duration
/// 5. Restoring displays and input
///
/// Usage:
///   smoko       - Start smoko immediately
///   smoko config - Print config and fullpath
///   smoko edit   - Open config in $EDITOR
///   smoko <N>   - Start smoko in N minutes
///   smoko -h | help - Show this help
///
/// Default configuration is stored in ~/.config/smoko/config.txt (edit with `smoko edit`).
pub fn main() !void {
    // 1. init Global
    var global = try Global.init();
    defer global.deinit();

    // 2. check OS support
    if (!@hasField(Global.supported_os, @tagName(builtin.os.tag))) {
        try global.stdout.print("Error: {s} is not supported\n", .{@tagName(builtin.os.tag)});
        return error.UnsupportedOS;
    }

    // 3. parse args
    const args = try parseArgs();

    // 4. run action based on args
    try runAction(args, &global);
}

fn init(minutes: u32) !void {
    if (minutes > 0) { // Start the countdown
        var mins_remaining: u32 = minutes;

        while (mins_remaining > 0) {
            try g.stdout.print("\rSmoko in {d} minutes.", .{mins_remaining});
            time.sleep(time.ns_per_min);
            mins_remaining -= 1;
        }
    }

    try g.stdout.print("\rTime for smoko.                 \n", .{});

    // Initialize input blocker
    g.input_blocker = try InputBlocker.init();

    try InputBlocker.block(g.config.pre_blank_countdown_secs, "Input blocked. Blanking displays in", g.stdout);

    // Initialize display manager
    g.display_manager = try DisplayManager.init(g.arena.allocator(), 16);

    if (g.display_manager) |*dm| {
        try dm.captureAll(g.stdout);
        try InputBlocker.block(g.config.post_blank_countdown_secs, "Displays blanked. Releasing input block in", g.stdout);
        dm.showAllCursors();
    }

    try g.stdout.print("Input block released. Done.\n", .{});
}

/// Creates an event tap that blocks all input events
fn createInputBlocker() !os_impl.EventTap {
    const event_mask = os_impl.c.CGEventMaskBit(os_impl.c.kCGEventKeyDown) |
        os_impl.c.CGEventMaskBit(os_impl.c.kCGEventKeyUp) |
        os_impl.c.CGEventMaskBit(os_impl.c.kCGEventMouseMoved) |
        os_impl.c.CGEventMaskBit(os_impl.c.kCGEventLeftMouseDown) |
        os_impl.c.CGEventMaskBit(os_impl.c.kCGEventLeftMouseUp) |
        os_impl.c.CGEventMaskBit(os_impl.c.kCGEventRightMouseDown) |
        os_impl.c.CGEventMaskBit(os_impl.c.kCGEventRightMouseUp) |
        os_impl.c.CGEventMaskBit(os_impl.c.kCGEventScrollWheel) |
        os_impl.c.CGEventMaskBit(os_impl.c.kCGEventFlagsChanged); // Add this to catch modifier keys

    const tap = os_impl.c.CGEventTapCreate(
        os_impl.c.kCGSessionEventTap,
        os_impl.c.kCGHeadInsertEventTap,
        os_impl.c.kCGEventTapOptionDefault,
        event_mask,
        eventCallback,
        null,
    );

    if (tap == null) {
        try g.stdout.print("\nError: Failed to create event tap. Please grant accessibility permissions in:\n", .{});
        try g.stdout.print("System Settings > Privacy & Security > Accessibility\n\n", .{});
        try g.stdout.print("Opening System Settings...\n", .{});
        try openAccessibilitySettings();
        return error.FailedToCreateEventTap;
    }

    const run_loop_source = os_impl.c.CFMachPortCreateRunLoopSource(
        os_impl.c.kCFAllocatorDefault,
        tap,
        0,
    );

    if (run_loop_source == null) {
        os_impl.releaseCF(tap);
        return error.FailedToCreateRunLoopSource;
    }
    defer os_impl.releaseCF(run_loop_source);

    os_impl.c.CFRunLoopAddSource(
        os_impl.c.CFRunLoopGetCurrent(),
        run_loop_source,
        os_impl.c.kCFRunLoopCommonModes,
    );

    os_impl.c.CGEventTapEnable(tap, true);
    return tap;
}

/// Callback function for the event tap
fn eventCallback(
    proxy: os_impl.c.CGEventTapProxy,
    event_type: os_impl.c.CGEventType,
    event: os_impl.c.CGEventRef,
    user_info: ?*anyopaque,
) callconv(.C) os_impl.c.CGEventRef {
    _ = proxy;
    _ = event_type;
    _ = event;
    _ = user_info;
    // Return null to block the event
    return null;
}

fn openAccessibilitySettings() !void {
    const result = try process.Child.run(.{
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

const Action = union(enum) {
    help,
    immediate,
    config,
    edit,
    countdown: u32,
};

fn parseArgs() !Action {
    var args = process.args();
    _ = args.skip(); // program name

    const arg = args.next() orelse return .immediate;

    if (mem.eql(u8, arg, "help") or mem.eql(u8, arg, "-h")) return .help;
    if (mem.eql(u8, arg, "config")) return .config;
    if (mem.eql(u8, arg, "edit")) return .edit;
    return Action{ .countdown = try fmt.parseInt(u32, arg, 10) };
}

fn runAction(action: Action, global: *Global) !void {
    switch (action) {
        .help => try showHelp(global),
        .immediate => try startBreak(0, global),
        .config => try showConfig(global),
        .edit => try editConfig(global),
        .countdown => |mins| try startBreak(mins, global),
    }
}

fn showHelp(global: *Global) !void {
    try global.stdout.writeAll(HELP_TEXT);
}

fn showConfig(global: *Global) !void {
    try global.config.show(global.stdout);
}

fn editConfig(global: *Global) !void {
    _ = global;
    return error.Unimplemented;
}

fn startBreak(minutes: u32, global: *Global) !void {
    if (minutes > 0) {
        try global.stdout.print("\rStarting break in {d} minutes...\n", .{minutes});
        var mins_remaining: u32 = minutes;
        while (mins_remaining > 0) : (mins_remaining -= 1) {
            try global.stdout.print("\rSmoko in {d} minutes.", .{mins_remaining});
            time.sleep(time.ns_per_min);
        }
    }

    try global.stdout.print("\rTime for smoko.                 \n", .{});

    try global.input_blocker.?.block();
    try global.stdout.print("Input blocked. Blanking displays in {d} seconds...\n", .{global.config.pre_blank_countdown_secs});
    time.sleep(global.config.pre_blank_countdown_secs * time.ns_per_s);

    try global.display_manager.?.blank();
    try global.stdout.print("Displays blanked. Break ends in {d} seconds...\n", .{global.config.post_blank_countdown_secs});
    time.sleep(global.config.post_blank_countdown_secs * time.ns_per_s);

    global.display_manager.?.restore();
    global.input_blocker.?.restore();
    try global.stdout.print("Break complete.\n", .{});
}
