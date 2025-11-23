//! WebIDL Code Generator Root Module
//!
//! This module exports all code generation functionality.

pub const config = @import("config.zig");
pub const types = @import("types.zig");
pub const parser = @import("parser.zig");
pub const idl_parser = @import("idl_parser.zig");
pub const idl_scanner = @import("idl_scanner.zig");
pub const lexer = @import("lexer.zig");
pub const writer = @import("writer.zig");
pub const files = @import("files.zig");
pub const refs = @import("refs.zig");
pub const extattr = @import("extattr.zig");
pub const generator = @import("generator.zig");
pub const ir = @import("ir.zig");
pub const pipeline = @import("pipeline.zig");
pub const spec_priority = @import("spec_priority.zig");
pub const adapter = @import("adapter.zig");
pub const overload = @import("overload.zig");
pub const property_classifier = @import("property_classifier.zig");
// v8_bindings removed - will be replaced by proper JS bindings system (epic webidl-gbjt)

// Re-export commonly used functions
pub const generateInterface = generator.generateInterface;
pub const generateFromFile = generator.generateFromFile;
pub const generateFromDirectory = generator.generateFromDirectory;

// Multi-stage pipeline
pub const processDirectory = pipeline.processDirectory;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
