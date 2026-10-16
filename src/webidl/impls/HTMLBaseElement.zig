//! Implementation for HTMLBaseElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLBaseElement = interfaces.HTMLBaseElement;

pub const State = HTMLBaseElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLBaseElement.init(ctx.allocator, ctx);
    errdefer HTMLBaseElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// HTML 4.2.3, href getter steps 1-5. Unlike ordinary URL reflection this
/// uses the fallback base URL, ignoring every base element (including self).
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const dom = @import("dom");
    const sniffing = @import("html_core").parser.encoding_sniffing;
    const allocator = instance.ctx.allocator;
    // Steps 1-2: the node document and href, or the empty string. The IDL
    // result is a USVString even when parsing fails (step 4).
    const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return error.InvalidStateError;
    const input = try dom.reflection.get(runtime.USVString, instance, .{ .name = "href" });
    errdefer if (input.len != 0) allocator.free(input);
    // Step 3: fallback URL and character encoding, never Node.baseURI.
    const url = try interfaces.Document.get_URL(document);
    defer document.ctx.allocator.free(url);
    const fallback = dom.document_lifecycle.aboutFallbackBaseUrl(document) orelse url;
    var encoding_name = try interfaces.Document.get_characterSet(document);
    defer encoding_name.deinit(document.ctx.allocator);
    const encoding = sniffing.lookup(encoding_name.asSlice()) orelse sniffing.utf_8;
    const serialized = try @import("api_parser").encodingParseAndSerialize(allocator, input, fallback, encoding);
    // Step 4 transfers the original string; step 5 transfers the serialization.
    if (serialized) |result| {
        if (input.len != 0) allocator.free(input);
        return result;
    }
    return input;
}
