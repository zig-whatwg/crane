//! Preconditions shared by input/select showPicker (HTML 4.10.5.4, 4.10.7).
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const activation = @import("../user_activation.zig");

/// Compare the relevant settings object's origin with its top-level origin,
/// retaining opaque-origin identity. The caller handles file/color exemptions.
pub fn requireSameOriginWithTop(element: *runtime.Instance) !void {
    const window = activation.windowOfRealm(element.ctx) orelse return;
    const document = try interfaces.Window.get_document(window);
    const top = @import("../focus.zig").topLevelDocumentOf(document);
    if (document == top) return;
    const origin = (try dom.global_settings.shareableOriginOf(window)) orelse return error.SecurityError;
    const top_origin = (try dom.document_origin.shareable(top)) orelse return error.SecurityError;
    if (!dom.origin_record.sameOrigin(
        .{ .serialized = origin.serialized orelse "null", .record = origin },
        .{ .serialized = top_origin.serialized orelse "null", .record = top_origin },
    )) return error.SecurityError;
}

pub fn requireActivation(element: *runtime.Instance) !*runtime.Instance {
    const window = activation.windowOfRealm(element.ctx) orelse return error.NotAllowedError;
    if (!activation.hasTransientActivation(window)) return error.NotAllowedError;
    return window;
}
