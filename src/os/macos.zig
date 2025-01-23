const std = @import("std");
const process = std.process;
const heap = std.heap;

pub const c = @cImport({
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

pub fn createInputBlocker(callback: *const fn (
    proxy: c.CGEventTapProxy,
    event_type: c.CGEventType,
    event: c.CGEventRef,
    user_info: ?*anyopaque,
) callconv(.C) c.CGEventRef) !EventTap {
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
        callback,
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

pub fn runEventLoop(duration_secs: f64) void {
    const run_result = c.CFRunLoopRunInMode(c.kCFRunLoopDefaultMode, duration_secs, 0);
    _ = run_result;
}
