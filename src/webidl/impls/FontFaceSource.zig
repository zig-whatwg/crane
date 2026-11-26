//! Implementation for the FontFaceSource mixin (CSS Font Loading §3.3):
//! readonly attribute FontFaceSet fonts, shared by Document and
//! WorkerGlobalScope.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const FontFaceSource = interfaces.FontFaceSource;

pub const State = FontFaceSource.State;

pub const ImplError = error{
    InvalidStateError,
    OutOfMemory,
};

pub const InternalState = struct {};

/// Getter for fonts (CSS Font Loading §3.3).
pub fn get_fonts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    if (dom.document_internals.getInternal(instance)) |internal| {
        const fonts = internal.fonts_kept.get() orelse blk: {
            const made = interfaces.FontFaceSet.initWith(internal.allocator, instance.ctx, .{ .font_document = instance }) catch return error.OutOfMemory;
            internal.fonts_kept.made(made);
            break :blk made;
        };
        internal.fonts_kept.handOut(instance, fonts, .{ .name = "fonts" });
        return fonts;
    }
    if (try dom.document_internals.workerFontsOf(instance)) |fonts| {
        return fonts;
    }
    return error.InvalidStateError;
}
