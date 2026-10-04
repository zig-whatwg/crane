//! Multi-stage WebIDL processing pipeline
//!
//! Stage 1: Parse all IDL files → IR
//! Stage 2: Merge partial interfaces
//! Stage 3: Generate Zig code
//! Stage 4: Generate root.zig files

const std = @import("std");
const parser = @import("parser.zig");
const ir_mod = @import("ir.zig");
const argument_unions = @import("argument_unions.zig");
const generator = @import("generator.zig");
const format = @import("format.zig");
const types = @import("types.zig");
const config_mod = @import("config.zig");
const host = @import("host");
const CodegenConfig = config_mod.CodegenConfig;

/// The CodegenConfig getters of every directory a run writes.
const output_dir_getters = .{ "getInterfacesPath", "getImplsPath", "getTypedefsPath", "getDictionariesPath", "getEnumsPath", "getCallbacksPath", "getNamespacesPath", "getMixinsPath" };

/// `namespace` with every operation's argument and return types that name a
/// typedef of a simple (non-union) type replaced by that type, through
/// typedefs of typedefs - CSSOM's `CSSOMString escape(CSSOMString ident)`
/// becomes DOMString in, DOMString out. A typedef of a union, a sequence or
/// a record is left as it is (the namespace writer maps it to a JSValue).
fn resolveNamespaceTypedefs(arena: std.mem.Allocator, namespace: types.Namespace, ir: *const ir_mod.IR) !types.Namespace {
    var resolved = namespace;
    const members = try arena.dupe(types.Member, namespace.members);
    for (members) |*member| {
        var operation = member.operation orelse continue;
        operation.idlType = resolveSimpleTypedef(operation.idlType, ir);
        const arguments = try arena.dupe(types.Argument, operation.arguments);
        for (arguments) |*argument| argument.idlType = resolveSimpleTypedef(argument.idlType, ir);
        operation.arguments = arguments;
        member.operation = operation;
    }
    resolved.members = members;
    return resolved;
}

fn resolveSimpleTypedef(idl_type: types.IDLType, ir: *const ir_mod.IR) types.IDLType {
    var current = idl_type;
    var depth: usize = 0;
    while (depth < 16) : (depth += 1) {
        if (current.unionTypes != null or current.sequence != null or current.record != null or current.generic != null) return current;
        if (ir_mod.TypeRegistry.isPrimitiveName(current.type)) return current;
        const typedef = ir.typedefs.get(current.type) orelse return current;
        const target = typedef.idlType;
        if (target.unionTypes != null or target.sequence != null or target.record != null or target.generic != null) return current;
        const nullable = current.nullable or target.nullable;
        current = target;
        current.nullable = nullable;
    }
    return current;
}

/// An `includes` statement and where it is.
const IncludesStatement = struct {
    file: []const u8,
    position: usize,
    statement: types.Includes,

    fn lessThan(_: void, a: IncludesStatement, b: IncludesStatement) bool {
        return switch (std.mem.order(u8, a.file, b.file)) {
            .lt => true,
            .gt => false,
            .eq => a.position < b.position,
        };
    }
};

/// One IDL file found in a source directory.
pub const SourceFile = struct {
    /// The directory it was found in, as given.
    dir: []const u8,
    /// Its name in that directory; also its source key in the IR.
    name: []const u8,
    /// Found in a source after the first: Crane's own IDL beside webref's
    /// (specs/supplementary), which may not restate a member silently
    /// (ir.zig mergeInterfacePartial, member_overrides.zig).
    supplementary: bool = false,

    fn lessThan(_: void, a: SourceFile, b: SourceFile) bool {
        return std.mem.lessThan(u8, a.name, b.name);
    }
};

/// List every `.idl` file in `sources`, sorted by file name: the stable key
/// the IR orders partial definitions by, so that nothing depends on
/// directory enumeration order or on the order the sources are named in.
/// Names are owned by `allocator`; free them with `freeSourceFiles`.
fn collectSourceFiles(allocator: std.mem.Allocator, sources: []const []const u8) ![]SourceFile {
    const io = host.io();
    var files = std.ArrayList(SourceFile).empty;
    errdefer freeSourceFiles(allocator, files.items);
    errdefer files.deinit(allocator);

    for (sources, 0..) |source_dir, source_index| {
        var dir = try host.cwd().openDir(io, source_dir, .{ .iterate = true });
        defer dir.close(io);
        var iter = dir.iterate();
        while (try iter.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".idl")) continue;
            const name = try allocator.dupe(u8, entry.name);
            errdefer allocator.free(name);
            try files.append(allocator, .{ .dir = source_dir, .name = name, .supplementary = source_index > 0 });
        }
    }

    std.mem.sort(SourceFile, files.items, {}, SourceFile.lessThan);

    // A file name is the source key of everything it defines, so two sources
    // may not both carry one: the second copy would define every name twice.
    for (files.items[0..files.items.len -| 1], files.items[@min(1, files.items.len)..]) |a, b| {
        if (std.mem.eql(u8, a.name, b.name)) {
            std.debug.print("  error: {s} is in both {s} and {s}\n", .{ a.name, a.dir, b.dir });
            return error.DuplicateSourceFile;
        }
    }

    return files.toOwnedSlice(allocator);
}

fn freeSourceFiles(allocator: std.mem.Allocator, files: []const SourceFile) void {
    for (files) |file| allocator.free(file.name);
}

/// Process a directory of IDL files through the complete pipeline.
pub fn processDirectory(
    allocator: std.mem.Allocator,
    input_dir: []const u8,
    cfg: *CodegenConfig,
) !void {
    return processSources(allocator, &.{input_dir}, cfg);
}

/// Process every IDL file in `sources` (e.g. specs/idl and specs/supplementary)
/// as ONE model: a name in any source resolves against the definitions of all
/// of them, and every root.zig lists every source's entries.
pub fn processSources(
    allocator: std.mem.Allocator,
    source_dirs: []const []const u8,
    cfg: *CodegenConfig,
) !void {
    std.debug.print("Stage 1: Parsing all IDL files from {d} source(s)\n", .{source_dirs.len});
    for (source_dirs) |source_dir| std.debug.print("    from {s}\n", .{source_dir});

    const source_files = try collectSourceFiles(allocator, source_dirs);
    defer {
        freeSourceFiles(allocator, source_files);
        allocator.free(source_files);
    }
    return processFiles(allocator, source_files, cfg);
}

/// Process these IDL files as ONE model. The model does not depend on the
/// order they are given in (see ir.zig, "Merging").
pub fn processFiles(
    allocator: std.mem.Allocator,
    source_files: []const SourceFile,
    cfg: *CodegenConfig,
) !void {
    // Stage 1: Parse all files into IR
    var ir = try ir_mod.IR.init(allocator);
    defer ir.deinit();

    // Keep all parsed IDL data alive until we're done (they contain strings referenced by IR)
    var parsed_files = std.ArrayList(parser.ParsedIDL).empty;
    defer {
        for (parsed_files.items) |*parsed| {
            parsed.deinit();
        }
        parsed_files.deinit(allocator);
    }

    var includes = std.ArrayList(IncludesStatement).empty;
    defer includes.deinit(allocator);

    for (source_files) |source_file| {
        const file_path = try std.fs.path.join(allocator, &.{ source_file.dir, source_file.name });
        defer allocator.free(file_path);

        // Parse the file
        const parsed_idl = parser.parseIDLFile(allocator, file_path) catch |err| {
            // A file left out would change the model without a trace.
            std.debug.print("  error: failed to parse {s}: {}\n", .{ file_path, err });
            return err;
        };
        // Owned by parsed_files from here, whatever the adds below do.
        try parsed_files.append(allocator, parsed_idl);

        const idl_file = parsed_idl.value;
        if (source_file.supplementary) try ir.markSupplementary(source_file.name);

        // Add to IR
        for (idl_file.interfaces) |iface| {
            try ir.addInterface(iface, source_file.name);
        }

        for (idl_file.dictionaries) |dict| {
            try ir.addDictionary(dict, source_file.name);
        }

        for (idl_file.typedefs) |typedef| {
            try ir.addTypedef(typedef, source_file.name);
        }

        for (idl_file.enums) |enum_type| {
            try ir.addEnum(enum_type, source_file.name);
        }

        for (idl_file.callbacks) |callback| {
            try ir.addCallback(callback, source_file.name);
        }

        for (idl_file.namespaces) |namespace| {
            try ir.addNamespace(namespace, source_file.name);
        }

        for (idl_file.includes, 0..) |inc, position| {
            try includes.append(allocator, .{ .file = source_file.name, .position = position, .statement = inc });
        }
    }

    // Every definition is in: resolve duplicate definitions, or fail.
    try ir.finish();

    std.debug.print("  ✓ Parsed {d} IDL files\n", .{parsed_files.items.len});

    // Stage 1.5: Process includes statements to merge mixins
    std.debug.print("\nStage 1.5: Processing mixin includes\n", .{});

    // An includer takes its mixins' members in the order of its `includes`
    // statements, ordered by (file name, position in the file) - never by
    // the order the files were read in.
    std.mem.sort(IncludesStatement, includes.items, {}, IncludesStatement.lessThan);
    for (includes.items) |inc| try ir.processIncludes(&.{inc.statement});

    // Stage 1.6: a union argument the binding must convert in argument order
    // becomes a named union typedef (argument_unions.zig) - after the
    // includes, so an includer's mixin operations are named too. A union with
    // a Trusted Type member is named first, in every position.
    try argument_unions.nameTrustedTypeUnions(&ir);
    try argument_unions.nameArgumentUnions(&ir);

    // Stage 2: Report merging statistics
    std.debug.print("\nStage 2: Partial interface merging\n", .{});

    var multi_source_count: usize = 0;
    var source_iter = ir.source_map.iterator();
    while (source_iter.next()) |entry| {
        if (entry.value_ptr.items.len > 1) {
            multi_source_count += 1;
            if (multi_source_count <= 10) { // Show first 10 examples
                std.debug.print("  ✓ {s} extended by {d} specs: ", .{ entry.key_ptr.*, entry.value_ptr.items.len });
                for (entry.value_ptr.items, 0..) |source, i| {
                    if (i > 0) std.debug.print(", ", .{});
                    const basename = std.fs.path.basename(source);
                    const name_only = basename[0 .. basename.len - 4]; // remove .idl
                    std.debug.print("{s}", .{name_only});
                }
                std.debug.print("\n", .{});
            }
        }
    }

    if (multi_source_count > 10) {
        std.debug.print("  ... and {d} more interfaces extended across specs\n", .{multi_source_count - 10});
    }
    std.debug.print("  ✓ Total interfaces with partials: {d}\n", .{multi_source_count});

    // Stage 3: Generate code
    const interfaces_path_or_null = try cfg.getInterfacesPath();
    const output_label = if (interfaces_path_or_null) |path| path else "nowhere (no --interfaces or --dest-root specified)";
    std.debug.print("\nStage 3: Generating Zig code to {s}\n", .{output_label});

    // Collect interface names for root.zig generation
    var interface_names = std.ArrayList([]const u8).empty;
    defer interface_names.deinit(allocator);

    var iface_iter = ir.interfaces.iterator();
    var generated_count: usize = 0;

    while (iface_iter.next()) |entry| {
        const merged_iface = entry.value_ptr;

        // Convert back to types.Interface for generation
        const types_iface = try merged_iface.toTypes(allocator);
        defer {
            allocator.free(types_iface.name);
            if (types_iface.inheritance) |inh| allocator.free(inh);
            allocator.free(types_iface.members);
            allocator.free(types_iface.extAttrs);
            allocator.free(types_iface.includes);
        }

        // Collect interface name for root.zig
        const name_copy = try allocator.dupe(u8, types_iface.name);
        try interface_names.append(allocator, name_copy);

        // Get primary source file (the one with the non-partial definition)
        const sources = ir.source_map.get(entry.key_ptr.*).?;
        const primary_source = sources.items[merged_iface.base_source_index];

        try generator.generateInterface(
            allocator,
            types_iface,
            primary_source,
            &ir,
            cfg,
        );

        generated_count += 1;
    }

    std.debug.print("  ✓ Generated {d} interface files\n", .{generated_count});

    // Stage 3.5: Generate typedefs
    var typedef_names = std.ArrayList([]const u8).empty;
    defer typedef_names.deinit(allocator);

    if (try cfg.getTypedefsPath()) |typedefs_path| {
        var typedef_iter = ir.typedefs.iterator();
        var typedef_count: usize = 0;

        while (typedef_iter.next()) |entry| {
            const typedef = entry.value_ptr.*;

            const name_copy = try allocator.dupe(u8, typedef.name);
            try typedef_names.append(allocator, name_copy);

            // The buffer source typedefs re-export the hand-written unions in
            // webidl/types/buffer_sources.zig instead of being generated from
            // their IDL; their files are still written here, so that a
            // from-scratch regeneration produces every file root.zig imports.
            if (generator.isSpecialTypedef(typedef.name)) {
                try generator.generateSpecialTypedef(typedef.name, typedefs_path);
                continue;
            }

            try generator.generateTypedef(allocator, typedef, typedefs_path, &ir);

            typedef_count += 1;
        }

        if (typedef_count > 0) {
            std.debug.print("  ✓ Generated {d} typedef files to {s}\n", .{ typedef_count, typedefs_path });
        }
    }

    // Stage 3.6: Generate dictionaries
    var dictionary_names = std.ArrayList([]const u8).empty;
    defer dictionary_names.deinit(allocator);

    if (try cfg.getDictionariesPath()) |dictionaries_path| {
        var dict_iter = ir.dictionaries.iterator();
        var dict_count: usize = 0;

        while (dict_iter.next()) |entry| {
            const dict = entry.value_ptr.*;
            try generator.generateDictionary(allocator, dict, dictionaries_path, &ir);

            const name_copy = try allocator.dupe(u8, dict.name);
            try dictionary_names.append(allocator, name_copy);

            dict_count += 1;
        }

        if (dict_count > 0) {
            std.debug.print("  ✓ Generated {d} dictionary files to {s}\n", .{ dict_count, dictionaries_path });
        }
    }

    // Stage 3.7: Generate enums
    var enum_names = std.ArrayList([]const u8).empty;
    defer enum_names.deinit(allocator);

    if (try cfg.getEnumsPath()) |enums_path| {
        var enum_iter = ir.enums.iterator();
        var enum_count: usize = 0;

        while (enum_iter.next()) |entry| {
            const enum_type = entry.value_ptr.*;
            try generator.generateEnum(allocator, enum_type, enums_path);

            const name_copy = try allocator.dupe(u8, enum_type.name);
            try enum_names.append(allocator, name_copy);

            enum_count += 1;
        }

        if (enum_count > 0) {
            std.debug.print("  ✓ Generated {d} enum files to {s}\n", .{ enum_count, enums_path });
        }
    }

    // Stage 3.8: Generate callbacks
    var callback_names = std.ArrayList([]const u8).empty;
    defer callback_names.deinit(allocator);

    if (try cfg.getCallbacksPath()) |callbacks_path| {
        var callback_iter = ir.callbacks.iterator();
        var callback_count: usize = 0;

        while (callback_iter.next()) |entry| {
            const callback = entry.value_ptr.*;
            try generator.generateCallback(allocator, callback, callbacks_path, &ir.type_registry);

            const name_copy = try allocator.dupe(u8, callback.name);
            try callback_names.append(allocator, name_copy);

            callback_count += 1;
        }

        if (callback_count > 0) {
            std.debug.print("  ✓ Generated {d} callback files to {s}\n", .{ callback_count, callbacks_path });
        }
    }

    // Stage 3.9: Generate namespaces
    var namespace_names = std.ArrayList([]const u8).empty;
    defer namespace_names.deinit(allocator);

    // Stage 3.10: Generate mixins
    var mixin_names = std.ArrayList([]const u8).empty;
    defer mixin_names.deinit(allocator);

    if (try cfg.getNamespacesPath()) |namespaces_path| {
        var namespace_iter = ir.namespaces.iterator();
        var namespace_count: usize = 0;

        while (namespace_iter.next()) |entry| {
            // Namespaces do not import the typedefs module: their operations
            // take a typedef of a simple type as that type.
            var resolve_arena = std.heap.ArenaAllocator.init(allocator);
            defer resolve_arena.deinit();
            const namespace = try resolveNamespaceTypedefs(resolve_arena.allocator(), entry.value_ptr.*, &ir);
            try generator.generateNamespace(allocator, namespace, namespaces_path);

            // Generate impl stub if requested
            if (try cfg.getImplsPath()) |impls_path_for_ns| {
                try generator.generateNamespaceImpl(allocator, namespace, impls_path_for_ns);
            }

            const name_copy = try allocator.dupe(u8, namespace.name);
            try namespace_names.append(allocator, name_copy);

            namespace_count += 1;
        }

        if (namespace_count > 0) {
            std.debug.print("  ✓ Generated {d} namespace files to {s}\n", .{ namespace_count, namespaces_path });
        }
    }

    // Generate mixin files
    if (try cfg.getMixinsPath()) |mixins_path| {
        // Collect mixins from the type registry
        var mixin_count: usize = 0;

        // Iterate through all types and find mixins
        var type_iter = ir.type_registry.types.iterator();
        while (type_iter.next()) |entry| {
            const type_name = entry.key_ptr.*;
            const type_kind = entry.value_ptr.*;

            if (type_kind.kind == .mixin) {
                // Find the mixin definition in interfaces (mixins are stored as interfaces)
                if (ir.interfaces.get(type_name)) |mixin| {
                    try generator.generateMixin(allocator, mixins_path, mixin, &ir);

                    const name_copy = try allocator.dupe(u8, type_name);
                    try mixin_names.append(allocator, name_copy);

                    mixin_count += 1;
                }
            }
        }

        if (mixin_count > 0) {
            std.debug.print("  ✓ Generated {d} mixin files to {s}\n", .{ mixin_count, mixins_path });
        }
    }

    // Stage 4: Generate root.zig files
    std.debug.print("\nStage 4: Generating root.zig files\n", .{});

    // Every root is written, even for a directory no definition went into.
    inline for (output_dir_getters) |getter| {
        if (try @field(CodegenConfig, getter)(cfg)) |path| try host.cwd().createDirPath(host.io(), path);
    }

    if (try cfg.getInterfacesPath()) |interfaces_path| {
        try generator.generateInterfacesRoot(allocator, interfaces_path, interface_names.items);
        std.debug.print("  ✓ Generated {s}/root.zig\n", .{interfaces_path});
    }

    if (try cfg.getImplsPath()) |impls_path| {
        try generator.generateImplsRoot(allocator, impls_path, interface_names.items, namespace_names.items);
        std.debug.print("  ✓ Generated {s}/root.zig\n", .{impls_path});
    }

    if (try cfg.getTypedefsPath()) |typedefs_path| {
        try generator.generateTypedefsRoot(allocator, typedefs_path, typedef_names.items);
        std.debug.print("  ✓ Generated {s}/root.zig\n", .{typedefs_path});
    }

    if (try cfg.getDictionariesPath()) |dictionaries_path| {
        try generator.generateDictionariesRoot(allocator, dictionaries_path, dictionary_names.items);
        std.debug.print("  ✓ Generated {s}/root.zig\n", .{dictionaries_path});
    }

    if (try cfg.getEnumsPath()) |enums_path| {
        try generator.generateEnumsRoot(allocator, enums_path, enum_names.items);
        std.debug.print("  ✓ Generated {s}/root.zig\n", .{enums_path});
    }

    if (try cfg.getCallbacksPath()) |callbacks_path| {
        try generator.generateCallbacksRoot(allocator, callbacks_path, callback_names.items);
        std.debug.print("  ✓ Generated {s}/root.zig\n", .{callbacks_path});
    }

    if (try cfg.getNamespacesPath()) |namespaces_path| {
        // Always generate namespaces root even if empty (required for build)
        try generator.generateNamespacesRoot(allocator, namespaces_path, namespace_names.items);
        std.debug.print("  ✓ Generated {s}/root.zig\n", .{namespaces_path});
    }

    if (try cfg.getMixinsPath()) |mixins_path| {
        // Always generate mixins root even if empty (required for build)
        try generator.generateMixinsRoot(allocator, mixins_path, mixin_names.items);
        std.debug.print("  ✓ Generated {s}/root.zig\n", .{mixins_path});
    }

    // Clean up all names
    for (interface_names.items) |name| {
        allocator.free(name);
    }
    for (typedef_names.items) |name| {
        allocator.free(name);
    }
    for (dictionary_names.items) |name| {
        allocator.free(name);
    }
    for (enum_names.items) |name| {
        allocator.free(name);
    }
    for (callback_names.items) |name| {
        allocator.free(name);
    }
    for (namespace_names.items) |name| {
        allocator.free(name);
    }
    for (mixin_names.items) |name| {
        allocator.free(name);
    }

    // Note: V8 bindings are generated at comptime (no files generated)
    // See src/v8/interface.zig - V8Interface() function for comptime binding generation

    // Stage 5: format everything written, so it is byte for byte what is
    // committed (the writers' raw output is not zig fmt-clean).
    std.debug.print("\nStage 5: Formatting generated files\n", .{});
    inline for (output_dir_getters) |getter| {
        if (try @field(CodegenConfig, getter)(cfg)) |path| try format.formatDir(allocator, host.io(), path);
    }

    std.debug.print("\n✨ Pipeline complete!\n", .{});
}
