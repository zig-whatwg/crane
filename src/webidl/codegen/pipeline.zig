//! Multi-stage WebIDL processing pipeline
//!
//! Stage 1: Parse all IDL files → IR
//! Stage 2: Merge partial interfaces
//! Stage 3: Generate Zig code
//! Stage 4: Generate root.zig files

const std = @import("std");
const parser = @import("parser.zig");
const ir_mod = @import("ir.zig");
const generator = @import("generator.zig");
const types = @import("types.zig");
const config_mod = @import("config.zig");
const CodegenConfig = config_mod.CodegenConfig;

/// Process a directory of IDL files through the complete pipeline
pub fn processDirectory(
    allocator: std.mem.Allocator,
    input_dir: []const u8,
    cfg: *CodegenConfig,
) !void {
    std.debug.print("Stage 1: Parsing all IDL files from {s}\n", .{input_dir});

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

    var dir = try std.fs.cwd().openDir(input_dir, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    var file_count: usize = 0;

    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".idl")) continue;

        const file_path = try std.fs.path.join(allocator, &.{ input_dir, entry.name });
        defer allocator.free(file_path);

        // Parse the file
        const parsed_idl = parser.parseIDLFile(allocator, file_path) catch |err| {
            std.debug.print("  ⚠️  Failed to parse {s}: {}\n", .{ entry.name, err });
            continue;
        };

        const idl_file = parsed_idl.value;

        // Add to IR
        for (idl_file.interfaces) |iface| {
            ir.addInterface(iface, entry.name) catch |err| {
                if (err == error.DuplicateInterface) {
                    // Skip duplicate interfaces (some specs have errors)
                    continue;
                } else {
                    return err;
                }
            };
        }

        for (idl_file.dictionaries) |dict| {
            try ir.addDictionary(dict, entry.name);
        }

        for (idl_file.typedefs) |typedef| {
            try ir.addTypedef(typedef, entry.name);
        }

        for (idl_file.enums) |enum_type| {
            try ir.addEnum(enum_type, entry.name);
        }

        for (idl_file.callbacks) |callback| {
            try ir.addCallback(callback, entry.name);
        }

        for (idl_file.namespaces) |namespace| {
            try ir.addNamespace(namespace, entry.name);
        }

        // Keep parsed data alive
        try parsed_files.append(allocator, parsed_idl);
        file_count += 1;
    }

    std.debug.print("  ✓ Parsed {d} IDL files from source directory\n", .{file_count});

    // Also parse supplementary IDL files from supplementary/ directory (for missing types)
    blk: {
        const supplementary_dir = "supplementary";
        var supplementary_count: usize = 0;

        var supp_dir = std.fs.cwd().openDir(supplementary_dir, .{ .iterate = true }) catch |err| {
            // supplementary/ directory doesn't exist, that's OK - skip supplementary parsing
            if (err == error.FileNotFound) {
                break :blk;
            }
            return err;
        };
        defer supp_dir.close();

        var supp_iter = supp_dir.iterate();
        while (try supp_iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".idl")) continue;

            const file_path = try std.fs.path.join(allocator, &.{ supplementary_dir, entry.name });
            defer allocator.free(file_path);

            // Parse the file
            const parsed_idl = parser.parseIDLFile(allocator, file_path) catch |err| {
                std.debug.print("  ⚠️  Failed to parse supplementary {s}: {}\n", .{ entry.name, err });
                continue;
            };

            const idl_file = parsed_idl.value;

            // Add to IR
            for (idl_file.interfaces) |iface| {
                ir.addInterface(iface, entry.name) catch |err| {
                    if (err == error.DuplicateInterface) {
                        continue;
                    } else {
                        return err;
                    }
                };
            }

            for (idl_file.dictionaries) |dict| {
                try ir.addDictionary(dict, entry.name);
            }

            for (idl_file.typedefs) |typedef| {
                try ir.addTypedef(typedef, entry.name);
            }

            for (idl_file.enums) |enum_type| {
                try ir.addEnum(enum_type, entry.name);
            }

            for (idl_file.callbacks) |callback| {
                try ir.addCallback(callback, entry.name);
            }

            for (idl_file.namespaces) |namespace| {
                try ir.addNamespace(namespace, entry.name);
            }

            // Keep parsed data alive
            try parsed_files.append(allocator, parsed_idl);
            supplementary_count += 1;
        }

        if (supplementary_count > 0) {
            std.debug.print("  ✓ Parsed {d} supplementary IDL files from {s}\n", .{ supplementary_count, supplementary_dir });
        }
    }

    // Stage 1.5: Process includes statements to merge mixins
    std.debug.print("\nStage 1.5: Processing mixin includes\n", .{});

    // Process includes arrays from IDL files
    for (parsed_files.items) |parsed_file| {
        try ir.processIncludes(parsed_file.value.includes);
    }

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
            try generator.generateTypedef(allocator, typedef, typedefs_path);

            const name_copy = try allocator.dupe(u8, typedef.name);
            try typedef_names.append(allocator, name_copy);

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
            try generator.generateDictionary(allocator, dict, dictionaries_path);

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
            try generator.generateCallback(allocator, callback, callbacks_path);

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

    if (try cfg.getNamespacesPath()) |namespaces_path| {
        var namespace_iter = ir.namespaces.iterator();
        var namespace_count: usize = 0;

        while (namespace_iter.next()) |entry| {
            const namespace = entry.value_ptr.*;
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

    // Stage 4: Generate root.zig files
    std.debug.print("\nStage 4: Generating root.zig files\n", .{});

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

    // Note: V8 bindings are generated at comptime (no files generated)
    // See src/v8/interface.zig - V8Interface() function for comptime binding generation

    std.debug.print("\n✨ Pipeline complete!\n", .{});
}
