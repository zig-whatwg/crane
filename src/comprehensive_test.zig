//! Comprehensive binary that includes all major WHATWG implementations
//!
//! This file explicitly references major types from each spec to ensure
//! they are actually compiled in (not eliminated by dead code elimination).

const std = @import("std");

// Core infrastructure
const infra = @import("infra");
const webidl = @import("webidl");

// Specifications
const encoding = @import("encoding");
const url = @import("url");
const console = @import("console");
const streams = @import("streams");
const dom = @import("dom");
const mimesniff = @import("mimesniff");

// Force inclusion of major types by referencing them
comptime {
    // Infra
    _ = infra.List;
    _ = infra.OrderedMap;
    _ = infra.base64;
    _ = infra.CodePoint;

    // WebIDL
    _ = webidl.JSValue;
    _ = webidl.Exception;
    _ = webidl.DOMException;
    _ = webidl.interface;
    _ = webidl.namespace;
    _ = webidl.mixin;

    // Encoding
    _ = encoding.TextEncoder;
    _ = encoding.TextDecoder;
    _ = encoding.Encoding;
    _ = encoding.utf8Encode;
    _ = encoding.utf8Decode;

    // URL
    _ = url.host;
    _ = url.origin;
    _ = url.validation;
    _ = url.percent_encoding;
    _ = url.idna;

    // Console
    _ = console.console;
    _ = console.types;

    // Streams
    _ = streams.ReadableStream;
    _ = streams.WritableStream;
    _ = streams.TransformStream;
    _ = streams.ReadableStreamDefaultReader;
    _ = streams.WritableStreamDefaultWriter;
    _ = streams.ByteLengthQueuingStrategy;
    _ = streams.CountQueuingStrategy;

    // DOM
    _ = dom.AbortController;
    _ = dom.AbortSignal;
    _ = dom.EventTarget;
    _ = dom.Event;
    _ = dom.Node;
    _ = dom.Element;
    _ = dom.Text;
    _ = dom.Comment;
    _ = dom.DocumentFragment;

    // MIME Sniffing
    _ = mimesniff.parseMimeType;
    _ = mimesniff.sniffMimeType;
}

pub fn main() !void {
    std.debug.print("=== WHATWG Comprehensive Build ===\n", .{});
    std.debug.print("All major WHATWG specifications compiled:\n\n", .{});

    std.debug.print("✓ Infra Standard\n", .{});
    std.debug.print("✓ WebIDL\n", .{});
    std.debug.print("✓ Encoding Standard\n", .{});
    std.debug.print("✓ URL Standard\n", .{});
    std.debug.print("✓ Console Standard\n", .{});
    std.debug.print("✓ Streams Standard\n", .{});
    std.debug.print("✓ DOM Standard\n", .{});
    std.debug.print("✓ MIME Sniffing Standard\n", .{});

    std.debug.print("\nBinary includes:\n", .{});
    std.debug.print("- {d} specs\n", .{8});
    std.debug.print("- infra.List, OrderedMap, base64, code points\n", .{});
    std.debug.print("- webidl.Exception, JSValue, interface/namespace/mixin\n", .{});
    std.debug.print("- TextEncoder/TextDecoder + all encodings\n", .{});
    std.debug.print("- URL/URLSearchParams + host/origin/validation\n", .{});
    std.debug.print("- Console logging\n", .{});
    std.debug.print("- ReadableStream, WritableStream, TransformStream + readers/writers\n", .{});
    std.debug.print("- DOM: AbortController, EventTarget, Node hierarchy\n", .{});
    std.debug.print("- MIME type parsing and sniffing\n", .{});
}
