//! Implementation for DragEvent interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DragEvent = interfaces.DragEvent;

pub const State = DragEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// DragEvent currently has no owned state beyond its generated ancestors.
pub const InternalState = struct {};

pub const construction_args = .{"drag_init"};

/// The generated chain initializes MouseEvent before DragEvent's own part.
pub fn initOwn(
    instance: *runtime.Instance,
    allocator: std.mem.Allocator,
    comptime StateType: type,
    args: anytype,
) !void {
    _ = instance;
    _ = allocator;
    _ = StateType;
    if (@hasField(@TypeOf(args), "drag_init")) {
        const dictionary: dictionaries.DragEventInit = args.drag_init;
        // TODO(520): HTML DragEvent's constructor must retain dataTransfer.
        // The FILELIST + DATATRANSFER ownership item in
        // tmp/plans/feature-queue.md:520 owns that holder; supplied values
        // still read null until it lands. Never keep a bare pointer here.
        _ = dictionary.dataTransfer;
    }
}

/// DOM event constructor steps 1–2, including all MouseEventInit members.
/// https://html.spec.whatwg.org/multipage/dnd.html#the-dragevent-interface
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.DragEventInit)) !*runtime.Instance {
    const dictionary: dictionaries.DragEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{ .base = .{ .base = .{} } } } };
    return DragEvent.initWith(ctx.allocator, ctx, .{
        .mouse_type = @"type",
        .mouse_init = dictionary.base,
        .drag_init = dictionary,
    });
}

/// Getter for dataTransfer
pub fn get_dataTransfer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}
