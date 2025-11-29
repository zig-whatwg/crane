//! Sync Implementation Signatures Tool
//!
//! This tool safely updates function signatures in src/webidl/impls/ files
//! to match the generated stubs in src/webidl/impls_tmp/, while preserving
//! the function bodies (implementations).
//!
//! Usage:
//!   zig build sync-impl-signatures -- [options]
//!   # or directly:
//!   zig run tools/sync_impl_signatures.zig -- [options]
//!
//! Options:
//!   --dry-run, -n    Show what would change without writing
//!   --help, -h       Show help
//!   --verbose, -v    Show more details
//!
//! How it works:
//! 1. Parse both stub (impls_tmp/) and impl (impls/) files using Zig AST
//! 2. For each function in the stub:
//!    - If function exists in impl: update signature, preserve body
//!    - If function is new: add stub with NotImplemented body
//! 3. Preserve all other code (imports, types, helpers) from impl
//! 4. Write updated impl file

const std = @import("std");
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;

const IMPLS_DIR = "src/webidl/impls";
const IMPLS_TMP_DIR = "src/webidl/impls_tmp";

/// Information about a function extracted from source
const FunctionInfo = struct {
    name: []const u8,
    /// Full signature text (from 'pub fn' up to but not including '{')
    signature: []const u8,
    /// Body text (everything from '{' to matching '}', inclusive)
    body: []const u8,
    /// Start position in source (including any preceding doc comment)
    start: usize,
    /// End position in source (after closing '}')
    end: usize,
};

/// Extract functions from source using Zig AST
fn extractFunctions(allocator: Allocator, source: [:0]const u8) !std.StringHashMap(FunctionInfo) {
    var functions = std.StringHashMap(FunctionInfo).init(allocator);

    // Parse the source
    var ast = try Ast.parse(allocator, source, .zig);
    defer ast.deinit(allocator);

    // Check for parse errors
    if (ast.errors.len > 0) {
        std.debug.print("Warning: Parse errors in file, skipping...\n", .{});
        return functions;
    }

    // Iterate through all nodes looking for function declarations
    for (0..ast.nodes.len) |i| {
        const node_idx: Ast.Node.Index = @enumFromInt(i);
        const tag = ast.nodeTag(node_idx);

        // Look for fn_decl nodes
        if (tag == .fn_decl) {
            if (extractFunctionFromNode(&ast, node_idx, source)) |info| {
                try functions.put(info.name, info);
            }
        }
    }

    return functions;
}

/// Extract function details from a fn_decl node
fn extractFunctionFromNode(
    ast: *const Ast,
    node_idx: Ast.Node.Index,
    source: [:0]const u8,
) ?FunctionInfo {
    // fn_decl has node_and_node: [0] = proto, [1] = body
    const data = ast.nodeData(node_idx);
    const proto_node = data.node_and_node[0];
    const body_node = data.node_and_node[1];

    // Root node check (unlikely but defensive)
    if (proto_node == .root or body_node == .root) return null;

    // Get function name from proto first to check if it's a top-level function
    var buffer: [1]Ast.Node.Index = undefined;
    const fn_proto = ast.fullFnProto(&buffer, proto_node) orelse return null;
    const name_token = fn_proto.name_token orelse return null;
    const fn_name = ast.tokenSlice(name_token);

    // Find the start position (look for 'pub' before 'fn')
    const fn_token = ast.nodeMainToken(proto_node);
    var start_token = fn_token;

    // Check for 'pub' keyword before 'fn'
    if (fn_token > 0) {
        const prev_token = fn_token - 1;
        if (ast.tokenTag(prev_token) == .keyword_pub) {
            start_token = prev_token;
        }
    }

    const start_pos = ast.tokenStart(start_token);

    // Only process top-level functions (those starting at column 0)
    // Find the start of the line containing this function
    var line_start = start_pos;
    while (line_start > 0 and source[line_start - 1] != '\n') {
        line_start -= 1;
    }

    // Check if there's only whitespace before the function on this line
    // Top-level functions should start at column 0 (no indentation)
    var col: usize = 0;
    var pos = line_start;
    while (pos < start_pos) {
        if (source[pos] == ' ' or source[pos] == '\t') {
            col += 1;
        } else {
            // Non-whitespace before the function - it's nested
            return null;
        }
        pos += 1;
    }

    // If indented, skip (nested function)
    if (col > 0) return null;

    // Find the body's opening brace
    const body_start_token = ast.nodeMainToken(body_node);
    const brace_pos = ast.tokenStart(body_start_token);

    // Extract signature (from start to just before the opening brace)
    var sig_end = brace_pos;
    // Trim trailing whitespace from signature
    while (sig_end > start_pos and (source[sig_end - 1] == ' ' or source[sig_end - 1] == '\t' or source[sig_end - 1] == '\n' or source[sig_end - 1] == '\r')) {
        sig_end -= 1;
    }
    const signature = source[start_pos..sig_end];

    // Find matching closing brace for the body
    const body_end = findMatchingBrace(source, brace_pos) orelse return null;
    const body = source[brace_pos .. body_end + 1];

    return FunctionInfo{
        .name = fn_name,
        .signature = signature,
        .body = body,
        .start = start_pos,
        .end = body_end + 1,
    };
}

/// Find the matching closing brace
fn findMatchingBrace(source: []const u8, start: usize) ?usize {
    if (start >= source.len or source[start] != '{') return null;

    var depth: usize = 0;
    var pos = start;
    var in_string = false;
    var in_char = false;
    var in_line_comment = false;
    var prev_char: u8 = 0;

    while (pos < source.len) {
        const c = source[pos];

        // Handle line comments
        if (!in_string and !in_char and c == '/' and pos + 1 < source.len and source[pos + 1] == '/') {
            in_line_comment = true;
        }
        if (in_line_comment and c == '\n') {
            in_line_comment = false;
        }

        if (!in_line_comment) {
            // Handle string literals
            if (c == '"' and prev_char != '\\' and !in_char) {
                in_string = !in_string;
            }
            // Handle char literals
            if (c == '\'' and prev_char != '\\' and !in_string) {
                in_char = !in_char;
            }

            if (!in_string and !in_char) {
                if (c == '{') {
                    depth += 1;
                } else if (c == '}') {
                    depth -= 1;
                    if (depth == 0) {
                        return pos;
                    }
                }
            }
        }

        prev_char = c;
        pos += 1;
    }

    return null;
}

/// Merge stub signatures into impl file, preserving bodies
fn mergeSignatures(
    allocator: Allocator,
    impl_source: [:0]const u8,
    stub_functions: *const std.StringHashMap(FunctionInfo),
    impl_functions: *const std.StringHashMap(FunctionInfo),
    verbose: bool,
) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    // Track which functions we've processed
    var processed = std.StringHashMap(void).init(allocator);
    defer processed.deinit();

    // Sort impl functions by start position for ordered processing
    var impl_list: std.ArrayList(FunctionInfo) = .empty;
    defer impl_list.deinit(allocator);

    var impl_iter = impl_functions.iterator();
    while (impl_iter.next()) |entry| {
        try impl_list.append(allocator, entry.value_ptr.*);
    }

    std.mem.sort(FunctionInfo, impl_list.items, {}, struct {
        fn lessThan(_: void, a: FunctionInfo, b: FunctionInfo) bool {
            return a.start < b.start;
        }
    }.lessThan);

    var last_end: usize = 0;

    // Process each function in the impl file
    for (impl_list.items) |impl_fn| {
        // Write everything before this function
        try result.appendSlice(allocator, impl_source[last_end..impl_fn.start]);

        // Check if stub has this function with different signature
        if (stub_functions.get(impl_fn.name)) |stub_fn| {
            // Write the STUB signature (updated)
            try result.appendSlice(allocator, stub_fn.signature);
            try result.appendSlice(allocator, " ");

            // Write the IMPL body (preserved)
            try result.appendSlice(allocator, impl_fn.body);

            try processed.put(impl_fn.name, {});

            if (verbose and !std.mem.eql(u8, stub_fn.signature, impl_fn.signature)) {
                std.debug.print("    Updated: {s}\n", .{impl_fn.name});
            }
        } else {
            // Function not in stub - keep as-is
            try result.appendSlice(allocator, impl_fn.signature);
            try result.appendSlice(allocator, " ");
            try result.appendSlice(allocator, impl_fn.body);
        }

        last_end = impl_fn.end;
    }

    // Write remaining content after last function
    try result.appendSlice(allocator, impl_source[last_end..]);

    // Add any NEW functions from stub that aren't in impl
    var stub_iter = stub_functions.iterator();
    while (stub_iter.next()) |entry| {
        if (!processed.contains(entry.key_ptr.*) and !impl_functions.contains(entry.key_ptr.*)) {
            const stub_fn = entry.value_ptr.*;

            try result.appendSlice(allocator, "\n\n");
            try result.appendSlice(allocator, stub_fn.signature);
            try result.appendSlice(allocator, " ");
            try result.appendSlice(allocator, stub_fn.body);

            if (verbose) {
                std.debug.print("    Added: {s}\n", .{entry.key_ptr.*});
            }
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Process a single impl file
fn processFile(allocator: Allocator, filename: []const u8, dry_run: bool, verbose: bool) !bool {
    const impl_path = try std.fs.path.join(allocator, &.{ IMPLS_DIR, filename });
    defer allocator.free(impl_path);

    const stub_path = try std.fs.path.join(allocator, &.{ IMPLS_TMP_DIR, filename });
    defer allocator.free(stub_path);

    // Check if stub exists
    const stub_file = std.fs.cwd().openFile(stub_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return false; // No stub, nothing to do
        }
        return err;
    };
    defer stub_file.close();

    // Read files
    const impl_file = try std.fs.cwd().openFile(impl_path, .{});
    defer impl_file.close();

    const impl_bytes = try impl_file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(impl_bytes);

    const stub_bytes = try stub_file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(stub_bytes);

    // Convert to sentinel-terminated slices for AST parser
    const impl_source = try allocator.dupeZ(u8, impl_bytes);
    defer allocator.free(impl_source);

    const stub_source = try allocator.dupeZ(u8, stub_bytes);
    defer allocator.free(stub_source);

    // Extract functions from both files
    var stub_functions = try extractFunctions(allocator, stub_source);
    defer stub_functions.deinit();

    var impl_functions = try extractFunctions(allocator, impl_source);
    defer impl_functions.deinit();

    // Count changes
    var changes: usize = 0;
    var new_functions: usize = 0;

    var stub_iter = stub_functions.iterator();
    while (stub_iter.next()) |entry| {
        const fn_name = entry.key_ptr.*;
        const stub_fn = entry.value_ptr.*;

        if (impl_functions.get(fn_name)) |impl_fn| {
            if (!std.mem.eql(u8, stub_fn.signature, impl_fn.signature)) {
                changes += 1;
            }
        } else {
            new_functions += 1;
        }
    }

    if (changes == 0 and new_functions == 0) {
        return false;
    }

    std.debug.print("{s}: {d} signature(s) to update, {d} new function(s)\n", .{ filename, changes, new_functions });

    if (dry_run) {
        // Show details in dry run mode
        stub_iter = stub_functions.iterator();
        while (stub_iter.next()) |entry| {
            const fn_name = entry.key_ptr.*;
            const stub_fn = entry.value_ptr.*;

            if (impl_functions.get(fn_name)) |impl_fn| {
                if (!std.mem.eql(u8, stub_fn.signature, impl_fn.signature)) {
                    std.debug.print("  ~ {s}\n", .{fn_name});
                    if (verbose) {
                        std.debug.print("    OLD: {s}\n", .{impl_fn.signature});
                        std.debug.print("    NEW: {s}\n", .{stub_fn.signature});
                    }
                }
            } else {
                std.debug.print("  + {s} (new)\n", .{fn_name});
            }
        }
        return true;
    }

    // Merge and write
    const merged = try mergeSignatures(allocator, impl_source, &stub_functions, &impl_functions, verbose);
    defer allocator.free(merged);

    const out_file = try std.fs.cwd().createFile(impl_path, .{});
    defer out_file.close();
    try out_file.writeAll(merged);

    return true;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var dry_run = false;
    var verbose = false;
    var specific_file: ?[]const u8 = null;

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-n")) {
            dry_run = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print(
                \\Usage: sync_impl_signatures [options] [file.zig]
                \\
                \\Safely update function signatures in {s}/ to match
                \\the generated stubs in {s}/, while preserving
                \\function bodies (implementations).
                \\
                \\Options:
                \\  --dry-run, -n    Show what would change without writing
                \\  --verbose, -v    Show more details about changes
                \\  --help, -h       Show this help
                \\
                \\If no file is specified, processes all files in {s}/
                \\
            , .{ IMPLS_DIR, IMPLS_TMP_DIR, IMPLS_DIR });
            return;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            specific_file = arg;
        }
    }

    std.debug.print("Syncing impl signatures...\n", .{});
    if (dry_run) {
        std.debug.print("(DRY RUN - no files will be modified)\n", .{});
    }
    std.debug.print("\n", .{});

    var files_changed: usize = 0;

    if (specific_file) |file| {
        if (try processFile(allocator, file, dry_run, verbose)) {
            files_changed += 1;
        }
    } else {
        // Process all files
        var dir = try std.fs.cwd().openDir(IMPLS_DIR, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
            if (std.mem.eql(u8, entry.name, "root.zig")) continue;

            const name_copy = try allocator.dupe(u8, entry.name);
            defer allocator.free(name_copy);

            if (try processFile(allocator, name_copy, dry_run, verbose)) {
                files_changed += 1;
            }
        }
    }

    std.debug.print("\n", .{});
    if (files_changed == 0) {
        std.debug.print("No changes needed.\n", .{});
    } else if (dry_run) {
        std.debug.print("{d} file(s) would be updated.\n", .{files_changed});
    } else {
        std.debug.print("{d} file(s) updated.\n", .{files_changed});
    }
}
