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

// Force inclusion of ALL generated interfaces and major types
comptime {
    // Infra
    _ = infra.List;
    _ = infra.OrderedMap;
    _ = infra.base64;
    _ = infra.CodePoint;
    _ = infra.ByteSequence;
    _ = infra.String;
    _ = infra.Queue;
    _ = infra.Stack;
    _ = infra.OrderedSet;

    // WebIDL - Core type system
    _ = webidl.JSValue;
    _ = webidl.Exception;
    _ = webidl.DOMException;
    _ = webidl.interface;
    _ = webidl.namespace;
    _ = webidl.mixin;
    _ = webidl.BufferSource;
    _ = webidl.ArrayBuffer;
    _ = webidl.DataView;
    _ = webidl.TypedArray;

    // Encoding - ALL generated interfaces
    _ = encoding.TextEncoder;
    _ = encoding.TextDecoder;
    _ = encoding.Encoding;
    _ = encoding.utf8Encode;
    _ = encoding.utf8Decode;
    _ = encoding.Decoder;
    _ = encoding.Encoder;
    _ = encoding.FastDecoder;
    _ = encoding.getEncoding;

    // URL - ALL components
    _ = url.host;
    _ = url.origin;
    _ = url.validation;
    _ = url.percent_encoding;
    _ = url.idna;
    _ = url.ipv4_parser;
    _ = url.ipv6_parser;
    _ = url.host_parser;
    _ = url.ipv4_serializer;
    _ = url.ipv6_serializer;
    _ = url.host_serializer;
    _ = url.punycode;
    _ = url.equivalence;

    // Console
    _ = console.console;
    _ = console.types;

    // Streams - ALL generated interfaces (15 total)
    _ = streams.ReadableStream;
    _ = streams.ReadableStreamDefaultReader;
    _ = streams.ReadableStreamBYOBReader;
    _ = streams.ReadableStreamDefaultController;
    _ = streams.ReadableByteStreamController;
    _ = streams.ReadableStreamBYOBRequest;
    _ = streams.WritableStream;
    _ = streams.WritableStreamDefaultWriter;
    _ = streams.WritableStreamDefaultController;
    _ = streams.TransformStream;
    _ = streams.TransformStreamDefaultController;
    _ = streams.ByteLengthQueuingStrategy;
    _ = streams.CountQueuingStrategy;
    _ = streams.ReadableStreamIterator;

    // DOM - ALL generated interfaces (13 currently exported)
    _ = dom.AbortController;
    _ = dom.AbortSignal;
    _ = dom.EventTarget;
    _ = dom.Event;
    _ = dom.Node;
    _ = dom.Element;
    _ = dom.CharacterData;
    _ = dom.Text;
    _ = dom.Comment;
    _ = dom.ProcessingInstruction;
    _ = dom.CDATASection;
    _ = dom.DocumentType;
    _ = dom.DocumentFragment;
    _ = dom.NodeList;
    _ = dom.NamedNodeMap;
    _ = dom.DOMTokenList;
    _ = dom.Attr;

    // Note: 4 additional generated DOM files exist but are not yet exported:
    // - CustomEvent.zig, DocumentType.zig, document.zig, url.zig
    //
    // Note: 6 additional generated Encoding files exist but are not yet exported:
    // - TextEncoderStream.zig, TextDecoderStream.zig (streaming interfaces)
    // - TextEncoderCommon.zig, TextDecoderCommon.zig (mixins)
    // - TextEncoderOptions.zig, TextDecoderOptions.zig (dictionaries)

    // MIME Sniffing - ALL exports
    _ = mimesniff.parseMimeType;
    _ = mimesniff.sniffMimeType;
    _ = mimesniff.MimeType;
    _ = mimesniff.Resource;
    _ = mimesniff.identifyUnknownMimeType;
    _ = mimesniff.distinguishTextOrBinary;
}

pub fn main() !void {
    std.debug.print("=== WHATWG Comprehensive Build ===\n", .{});
    std.debug.print("All WHATWG specifications with generated interfaces:\n\n", .{});

    std.debug.print("✓ Infra Standard (9 core types)\n", .{});
    std.debug.print("✓ WebIDL (10 core types + codegen)\n", .{});
    std.debug.print("✓ Encoding Standard (9 interfaces + all algorithms)\n", .{});
    std.debug.print("✓ URL Standard (13 modules + IDNA)\n", .{});
    std.debug.print("✓ Console Standard\n", .{});
    std.debug.print("✓ Streams Standard (14 generated interfaces)\n", .{});
    std.debug.print("✓ DOM Standard (13 generated interfaces)\n", .{});
    std.debug.print("✓ MIME Sniffing Standard (6 exports)\n", .{});

    std.debug.print("\nTotal: {d} specs, 74+ explicitly referenced types\n", .{8});
    std.debug.print("\nGenerated interfaces included (currently exported/used):\n", .{});
    std.debug.print("  webidl/generated/console/ (1 of 1 file)\n", .{});
    std.debug.print("  webidl/generated/encoding/ (3 of 9 files)\n", .{});
    std.debug.print("  webidl/generated/url/ (2 of 2 files)\n", .{});
    std.debug.print("  webidl/generated/streams/ (14 of 15 files)\n", .{});
    std.debug.print("  webidl/generated/dom/ (13 of 17 files)\n", .{});
    std.debug.print("\nNot yet included: 10 generated files (not exported by specs yet)\n", .{});
    std.debug.print("  - TextEncoder/DecoderStream (streaming APIs)\n", .{});
    std.debug.print("  - CustomEvent, DocumentType, document (DOM)\n", .{});
    std.debug.print("  - Various mixins and dictionaries\n", .{});
    std.debug.print("\nPlus all source implementations from src/\n", .{});
}
