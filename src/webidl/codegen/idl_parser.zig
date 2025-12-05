//! WebIDL Parser
//!
//! Parses WebIDL (.idl) source files into an AST (types.IDLFile).
//!
//! ## Example
//!
//! ```zig
//! const source = try std.fs.cwd().readFileAlloc(allocator, "dom.idl", 10 * 1024 * 1024);
//! defer allocator.free(source);
//!
//! const idl_file = try Parser.parse(allocator, source);
//! defer idl_file.deinit(allocator);
//!
//! for (idl_file.interfaces) |interface| {
//!     std.debug.print("Interface: {s}\n", .{interface.name});
//! }
//! ```

const std = @import("std");
const lexer = @import("lexer.zig");
const types = @import("types.zig");

const Lexer = lexer.Lexer;
const Token = lexer.Token;
const TokenType = lexer.TokenType;

/// Parser for WebIDL source
pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    current_token: Token,
    peek_token: Token,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) !Parser {
        var lex = Lexer.init(source);
        const current = try lex.nextToken();
        const peek = try lex.nextToken();
        return Parser{
            .allocator = allocator,
            .lexer = lex,
            .current_token = current,
            .peek_token = peek,
        };
    }

    /// Parse WebIDL source into IDLFile
    pub fn parse(allocator: std.mem.Allocator, source: []const u8) !types.IDLFile {
        var parser = try Parser.init(allocator, source);
        return try parser.parseIDLFile();
    }

    /// Parse the entire IDL file
    fn parseIDLFile(self: *Parser) !types.IDLFile {
        var interfaces = std.ArrayList(types.Interface).empty;
        errdefer {
            for (interfaces.items) |*iface| {
                self.freeInterface(iface);
            }
            interfaces.deinit(self.allocator);
        }

        var dictionaries = std.ArrayList(types.Dictionary).empty;
        errdefer {
            for (dictionaries.items) |*dict| {
                self.freeDictionary(dict);
            }
            dictionaries.deinit(self.allocator);
        }

        var enums = std.ArrayList(types.Enum).empty;
        errdefer {
            for (enums.items) |*enm| {
                self.freeEnum(enm);
            }
            enums.deinit(self.allocator);
        }

        var callbacks = std.ArrayList(types.Callback).empty;
        errdefer {
            for (callbacks.items) |*cb| {
                self.freeCallback(cb);
            }
            callbacks.deinit(self.allocator);
        }

        var typedefs = std.ArrayList(types.Typedef).empty;
        errdefer {
            for (typedefs.items) |*td| {
                self.freeTypedef(td);
            }
            typedefs.deinit(self.allocator);
        }

        var namespaces = std.ArrayList(types.Namespace).empty;
        errdefer {
            for (namespaces.items) |*ns| {
                self.freeNamespace(ns);
            }
            namespaces.deinit(self.allocator);
        }

        var includes = std.ArrayList(types.Includes).empty;
        errdefer {
            for (includes.items) |*inc| {
                self.allocator.free(inc.target);
                self.allocator.free(inc.mixin);
            }
            includes.deinit(self.allocator);
        }

        // Parse top-level definitions
        while (self.current_token.type != .eof) {
            // Extended attributes
            var ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
            defer ext_attrs.deinit(self.allocator);

            if (self.current_token.type == .left_bracket) {
                try self.parseExtendedAttributes(&ext_attrs);
            }

            // Check what kind of definition follows
            if (self.current_token.type == .keyword_interface or
                self.current_token.type == .keyword_namespace or
                (self.current_token.type == .keyword_partial and self.peek_token.type == .keyword_interface) or
                (self.current_token.type == .keyword_partial and self.peek_token.type == .keyword_namespace) or
                (self.current_token.type == .keyword_callback and self.peek_token.type == .keyword_interface))
            {
                const result = try self.parseInterface(ext_attrs.items);
                // Skip forward declarations (marked with __FORWARD_DECL__ prefix)
                if (std.mem.startsWith(u8, result.iface.name, "__FORWARD_DECL__")) {
                    // Forward declaration - free the allocated name and skip
                    self.allocator.free(result.iface.name);
                } else if (result.is_namespace) {
                    // Convert interface to namespace and add to namespaces list
                    const namespace = types.Namespace{
                        .name = result.iface.name,
                        .members = result.iface.members,
                        .extAttrs = result.iface.extAttrs,
                        .partial = result.iface.partial,
                    };
                    try namespaces.append(self.allocator, namespace);
                } else {
                    // Regular interface (even if empty) - keep it
                    try interfaces.append(self.allocator, result.iface);
                }
            } else if (self.current_token.type == .keyword_dictionary or
                (self.current_token.type == .keyword_partial and self.peek_token.type == .keyword_dictionary))
            {
                const dict = try self.parseDictionary(ext_attrs.items);
                try dictionaries.append(self.allocator, dict);
            } else if (self.current_token.type == .identifier and self.peek_token.type == .keyword_includes) {
                // Handle "InterfaceName includes MixinName;" syntax
                const target_name = try self.expectIdentifier();
                try self.expect(.keyword_includes);
                const mixin_name = try self.expectIdentifier();
                try self.expect(.semicolon);

                try includes.append(self.allocator, types.Includes{
                    .target = target_name,
                    .mixin = mixin_name,
                });
            } else if (self.current_token.type == .keyword_callback) {
                // Handle "callback Name = returntype (args);" - callback type definition
                const cb = try self.parseCallback(ext_attrs.items);
                try callbacks.append(self.allocator, cb);
            } else if (self.current_token.type == .keyword_enum) {
                // Handle "enum Name { ... };"
                const enm = try self.parseEnum(ext_attrs.items);
                try enums.append(self.allocator, enm);
            } else if (self.current_token.type == .keyword_typedef) {
                // Handle "typedef ..."
                const td = try self.parseTypedef(ext_attrs.items);
                try typedefs.append(self.allocator, td);
            } else if (self.current_token.type == .identifier and std.mem.eql(u8, self.current_token.lexeme, "module")) {
                // Handle legacy OMG IDL module syntax: module name { ... }
                // Skip module wrapper - we already handle namespace::Type qualified names
                try self.advance(); // skip "module"
                _ = try self.expectIdentifier(); // skip module name
                try self.expect(.left_brace); // skip '{'
                // Continue parsing top-level definitions inside module
                // The closing '}' will be encountered and we'll skip it when we see it
            } else if (self.current_token.type == .right_brace) {
                // Closing brace of a module block - skip it
                try self.advance();
                // Module blocks in OMG IDL end with };
                if (self.current_token.type == .semicolon) {
                    try self.advance();
                }
            } else if (self.current_token.type == .semicolon) {
                // Stray semicolons in OMG IDL - skip them
                try self.advance();
            } else {
                return error.UnexpectedToken;
            }
        }

        return types.IDLFile{
            .interfaces = try interfaces.toOwnedSlice(self.allocator),
            .dictionaries = try dictionaries.toOwnedSlice(self.allocator),
            .enums = try enums.toOwnedSlice(self.allocator),
            .callbacks = try callbacks.toOwnedSlice(self.allocator),
            .typedefs = try typedefs.toOwnedSlice(self.allocator),
            .namespaces = try namespaces.toOwnedSlice(self.allocator),
            .includes = try includes.toOwnedSlice(self.allocator),
        };
    }

    /// Parse extended attributes [Exposed=Window, CEReactions]
    fn parseExtendedAttributes(self: *Parser, attrs: *std.ArrayList(types.ExtendedAttribute)) !void {
        try self.expect(.left_bracket);

        while (self.current_token.type != .right_bracket and self.current_token.type != .eof) {
            const name = try self.expectIdentifier();

            var rhs: ?types.ExtAttrRHS = null;

            // Handle extended attributes with function-like syntax but no equals sign
            // e.g., Constructor(Animation source, Animatable newTarget)
            if (self.current_token.type == .left_paren) {
                try self.skipBalancedParens();
                // rhs remains null - we don't store constructor arguments
            } else if (self.current_token.type == .equals) {
                try self.advance();

                // Check for parenthesized list: Exposed=(Window,Worker)
                if (self.current_token.type == .left_paren) {
                    try self.advance();
                    var list = std.ArrayList([]const u8).empty;
                    defer list.deinit(self.allocator);

                    while (self.current_token.type != .right_paren and self.current_token.type != .eof) {
                        const item = try self.allocator.dupe(u8, self.current_token.lexeme);
                        try list.append(self.allocator, item);
                        try self.advance();

                        if (self.current_token.type == .comma) {
                            try self.advance();
                        }
                    }
                    try self.expect(.right_paren);

                    rhs = types.ExtAttrRHS{
                        .identifierList = try list.toOwnedSlice(self.allocator),
                    };
                } else {
                    // Simple identifier RHS (e.g., Exposed=Window)
                    // Or function-like syntax (e.g., LegacyFactoryFunction=Image(...))
                    const value = self.current_token.lexeme;
                    rhs = types.ExtAttrRHS{
                        .identifier = try self.allocator.dupe(u8, value),
                    };
                    try self.advance();

                    // If followed by '(', skip the entire function signature
                    // This handles extended attributes like:
                    // LegacyFactoryFunction=Image(optional unsigned long width, ...)
                    if (self.current_token.type == .left_paren) {
                        try self.skipBalancedParens();
                    }
                }
            }

            const attr = types.ExtendedAttribute{
                .name = name,
                .rhs = rhs,
            };
            try attrs.append(self.allocator, attr);

            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.expect(.right_bracket);
    }

    const ParseInterfaceResult = struct {
        iface: types.Interface,
        is_namespace: bool,
    };

    /// Parse interface definition (or namespace, which is similar)
    fn parseInterface(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !ParseInterfaceResult {
        var is_partial = false;
        var is_callback = false;
        var is_mixin = false;
        var is_namespace = false;

        // Check for modifiers
        if (self.current_token.type == .keyword_partial) {
            is_partial = true;
            try self.advance();
        }

        if (self.current_token.type == .keyword_callback) {
            is_callback = true;
            try self.advance();
        }

        // Check for namespace
        if (self.current_token.type == .keyword_namespace) {
            is_namespace = true;
            try self.advance();
        } else {
            try self.expect(.keyword_interface);
        }

        // Check for mixin
        if (self.current_token.type == .keyword_mixin) {
            is_mixin = true;
            try self.advance();
        }

        const name = try self.expectIdentifier();

        // Handle forward declarations: interface Name;
        // Common in OMG IDL - skip them by returning a marker interface
        // We use a special marker: name starts with "__FORWARD_DECL__"
        if (self.current_token.type == .semicolon) {
            try self.advance();
            const marker_name = try std.fmt.allocPrint(self.allocator, "__FORWARD_DECL__{s}", .{name});
            return ParseInterfaceResult{
                .iface = types.Interface{
                    .name = marker_name,
                    .inheritance = null,
                    .members = &.{},
                    .extAttrs = @constCast(ext_attrs),
                    .partial = is_partial,
                    .mixin = is_mixin,
                    .includes = &.{},
                },
                .is_namespace = is_namespace,
            };
        }

        // Parse inheritance
        var inheritance: ?[]const u8 = null;
        if (self.current_token.type == .colon) {
            try self.advance();
            inheritance = try self.expectIdentifier();

            // Handle legacy namespace qualification: namespace::ClassName
            if (self.current_token.type == .colon and self.peek_token.type == .colon) {
                try self.advance(); // skip first ':'
                try self.advance(); // skip second ':'
                inheritance = try self.expectIdentifier(); // get the actual class name
            }
        }

        try self.expect(.left_brace);

        // Parse members
        var members = std.ArrayList(types.Member).empty;
        errdefer {
            for (members.items) |*member| {
                self.freeMember(member);
            }
            members.deinit(self.allocator);
        }

        while (self.current_token.type != .right_brace) {
            const member = try self.parseMember();
            try members.append(self.allocator, member);
        }

        try self.expect(.right_brace);
        try self.expect(.semicolon);

        return ParseInterfaceResult{
            .iface = types.Interface{
                .name = name,
                .inheritance = inheritance,
                .members = try members.toOwnedSlice(self.allocator),
                .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
                .partial = is_partial,
                .mixin = is_mixin,
                .callback = is_callback,
            },
            .is_namespace = is_namespace,
        };
    }

    /// Parse dictionary definition
    fn parseDictionary(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Dictionary {
        var is_partial = false;

        if (self.current_token.type == .keyword_partial) {
            is_partial = true;
            try self.advance();
        }

        try self.expect(.keyword_dictionary);

        const name = try self.expectIdentifier();

        // Parse inheritance
        var inheritance: ?[]const u8 = null;
        if (self.current_token.type == .colon) {
            try self.advance();
            inheritance = try self.expectIdentifier();
        }

        try self.expect(.left_brace);

        // Parse dictionary members
        var members = std.ArrayList(types.DictionaryMember).empty;
        defer members.deinit(self.allocator);

        while (self.current_token.type != .right_brace and self.current_token.type != .eof) {
            // Parse extended attributes if present
            var member_ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
            defer member_ext_attrs.deinit(self.allocator);

            if (self.current_token.type == .left_bracket) {
                try self.parseExtendedAttributes(&member_ext_attrs);
            }

            // Check for required keyword
            var is_required = false;
            if (self.current_token.type == .identifier and std.mem.eql(u8, self.current_token.lexeme, "required")) {
                is_required = true;
                try self.advance();
            }

            // Check for extended attributes on the type (e.g., required [EnforceRange] unsigned long)
            if (self.current_token.type == .left_bracket) {
                var type_ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
                defer type_ext_attrs.deinit(self.allocator);
                try self.parseExtendedAttributes(&type_ext_attrs);
                // For now, we skip these type-level extended attributes
            }

            // Parse member type
            const member_type = try self.parseType();

            // Parse member name
            const member_name = try self.expectIdentifier();

            // Parse default value if present
            var default_value: ?types.Value = null;
            if (self.current_token.type == .equals) {
                try self.advance();
                default_value = try self.parseValue();
            }

            try self.expect(.semicolon);

            try members.append(self.allocator, types.DictionaryMember{
                .name = member_name,
                .idlType = member_type,
                .required = is_required,
                .default = default_value,
            });
        }

        try self.expect(.right_brace);

        // Trailing semicolon is optional in some specs (though required by WebIDL spec)
        if (self.current_token.type == .semicolon) {
            try self.advance();
        }

        return types.Dictionary{
            .name = name,
            .inheritance = inheritance,
            .members = try members.toOwnedSlice(self.allocator),
            .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
            .partial = is_partial,
        };
    }

    /// Parse enum definition: enum Name { "value1", "value2", ... };
    fn parseEnum(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Enum {
        try self.expect(.keyword_enum);

        const name = try self.expectIdentifier();

        try self.expect(.left_brace);

        // Parse enum values
        var values = std.ArrayList([]const u8).empty;
        defer values.deinit(self.allocator);

        while (self.current_token.type != .right_brace and self.current_token.type != .eof) {
            // Expect string literal
            if (self.current_token.type == .string_literal) {
                const value = try self.allocator.dupe(u8, self.current_token.lexeme);
                try values.append(self.allocator, value);
                try self.advance();
            } else {
                return error.ExpectedStringLiteral;
            }

            // Optional comma between values
            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.expect(.right_brace);
        try self.expect(.semicolon);

        return types.Enum{
            .name = name,
            .values = try values.toOwnedSlice(self.allocator),
            .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
        };
    }

    /// Parse callback definition: callback Name = returnType (args);
    fn parseCallback(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Callback {
        try self.expect(.keyword_callback);

        const name = try self.expectIdentifier();

        try self.expect(.equals);

        // Parse return type
        const return_type = try self.parseType();

        // Parse arguments
        try self.expect(.left_paren);

        var arguments = std.ArrayList(types.Argument).empty;
        defer arguments.deinit(self.allocator);

        while (self.current_token.type != .right_paren and self.current_token.type != .eof) {
            const arg = try self.parseArgument();
            try arguments.append(self.allocator, arg);

            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.expect(.right_paren);
        try self.expect(.semicolon);

        return types.Callback{
            .name = name,
            .idlType = return_type,
            .arguments = try arguments.toOwnedSlice(self.allocator),
            .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
        };
    }

    /// Parse typedef definition: typedef Type NewName;
    fn parseTypedef(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Typedef {
        try self.expect(.keyword_typedef);

        // Check for extended attributes on the type itself
        // e.g., typedef [EnforceRange] unsigned long GPUBufferUsageFlags;
        if (self.current_token.type == .left_bracket) {
            var type_ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
            defer type_ext_attrs.deinit(self.allocator);
            try self.parseExtendedAttributes(&type_ext_attrs);
            // For now, we skip these type-level extended attributes
        }

        // Parse the type being aliased
        const idl_type = try self.parseType();

        // Parse the typedef name
        const name = try self.expectIdentifier();

        try self.expect(.semicolon);

        return types.Typedef{
            .name = name,
            .idlType = idl_type,
            .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
        };
    }

    /// Parse interface member (attribute, operation, constructor, const)
    fn parseMember(self: *Parser) !types.Member {
        // Extended attributes for this member
        var ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
        defer ext_attrs.deinit(self.allocator);

        if (self.current_token.type == .left_bracket) {
            try self.parseExtendedAttributes(&ext_attrs);
        }

        // Check for modifiers and member type
        if (self.current_token.type == .keyword_constructor) {
            return try self.parseConstructor(ext_attrs.items);
        } else if (self.current_token.type == .keyword_const) {
            return try self.parseConstant(ext_attrs.items);
        } else if (self.current_token.type == .keyword_iterable) {
            return try self.parseIterable(ext_attrs.items);
        } else if (self.current_token.type == .keyword_async_iterable) {
            return try self.parseAsyncIterable(ext_attrs.items);
        } else if (self.current_token.type == .identifier and
            std.mem.eql(u8, self.current_token.lexeme, "async") and
            self.peek_token.type == .keyword_iterable)
        {
            // Handle "async iterable" (two tokens, not async_iterable keyword)
            try self.advance(); // consume "async"
            return try self.parseAsyncIterable(ext_attrs.items);
        } else if (self.current_token.type == .keyword_maplike or
            self.current_token.type == .keyword_setlike or
            (self.current_token.type == .keyword_readonly and
                (self.peek_token.type == .keyword_maplike or self.peek_token.type == .keyword_setlike)))
        {
            // Skip maplike/setlike declarations for now
            // Handle both: setlike<T> and readonly setlike<T>
            // TODO: Implement maplike/setlike support
            while (self.current_token.type != .semicolon and self.current_token.type != .eof) {
                try self.advance();
            }
            if (self.current_token.type == .semicolon) {
                try self.advance();
            }
            // Return a dummy constant member to keep parsing going
            // This will be filtered out later
            return types.Member{
                .type = .constant,
                .constant = types.Constant{
                    .name = try self.allocator.dupe(u8, "_skipped"),
                    .idlType = .{ .type = try self.allocator.dupe(u8, "void") },
                    .value = .null,
                    .extAttrs = &.{},
                },
            };
        } else if (self.current_token.type == .keyword_readonly or
            self.current_token.type == .keyword_attribute or
            self.current_token.type == .keyword_inherit or
            (self.current_token.type == .keyword_static and
                (self.peek_token.type == .keyword_attribute or self.peek_token.type == .keyword_readonly)))
        {
            return try self.parseAttribute(ext_attrs.items);
        } else {
            // Must be an operation
            return try self.parseOperation(ext_attrs.items);
        }
    }

    /// Parse constructor member
    fn parseConstructor(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Member {
        try self.expect(.keyword_constructor);
        try self.expect(.left_paren);

        var arguments = std.ArrayList(types.Argument).empty;
        defer arguments.deinit(self.allocator);

        // Parse arguments
        while (self.current_token.type != .right_paren) {
            const arg = try self.parseArgument();
            try arguments.append(self.allocator, arg);

            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.expect(.right_paren);
        try self.expect(.semicolon);

        return types.Member{
            .type = .constructor,
            .constructor = types.Constructor{
                .arguments = try arguments.toOwnedSlice(self.allocator),
                .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
            },
        };
    }

    /// Parse const member
    fn parseConstant(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Member {
        try self.expect(.keyword_const);

        const idl_type = try self.parseType();
        const name = try self.expectIdentifier();

        try self.expect(.equals);

        const value = try self.parseValue();

        try self.expect(.semicolon);

        return types.Member{
            .type = .constant,
            .constant = types.Constant{
                .name = name,
                .idlType = idl_type,
                .value = value,
                .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
            },
        };
    }

    /// Parse iterable declaration: iterable<K, V>; or iterable<V>;
    fn parseIterable(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Member {
        try self.expect(.keyword_iterable);
        try self.expect(.left_angle);

        // Parse first type (key for pair iterable, value for value iterable)
        const first_type = try self.parseType();

        var value_type: ?types.IDLType = null;

        // Check if this is a pair iterable (has comma and second type)
        if (self.current_token.type == .comma) {
            try self.advance(); // consume comma
            value_type = try self.parseType();
        }

        try self.expect(.right_angle);
        try self.expect(.semicolon);

        return types.Member{
            .type = .iterable,
            .iterable = types.Iterable{
                .keyType = first_type,
                .valueType = value_type,
                .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
            },
        };
    }

    /// Parse async iterable declaration: async_iterable<K, V>; or async_iterable<V>;
    /// Also supports "async iterable" (two tokens) and iteration parameters: async_iterable<V>(args);
    fn parseAsyncIterable(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Member {
        // Handle both "async_iterable" keyword and "async" + "iterable" tokens
        if (self.current_token.type == .keyword_async_iterable) {
            try self.advance();
        } else if (self.current_token.type == .keyword_iterable) {
            // Called after consuming "async", so just consume "iterable"
            try self.advance();
        } else {
            return error.ExpectedAsyncIterable;
        }
        try self.expect(.left_angle);

        // Parse first type (key for pair async iterable, value for value async iterable)
        const first_type = try self.parseType();

        var value_type: ?types.IDLType = null;

        // Check if this is a pair async iterable (has comma and second type)
        if (self.current_token.type == .comma) {
            try self.advance(); // consume comma
            value_type = try self.parseType();
        }

        try self.expect(.right_angle);

        // Parse optional iteration parameters: async_iterable<T>(args);
        var args = std.ArrayList(types.Argument).empty;
        errdefer {
            for (args.items) |*arg| {
                self.freeArgument(arg);
            }
            args.deinit(self.allocator);
        }

        if (self.current_token.type == .left_paren) {
            try self.advance(); // consume '('

            // Parse arguments (e.g., optional ReadableStreamIteratorOptions options = {})
            while (self.current_token.type != .right_paren and self.current_token.type != .eof) {
                const arg = try self.parseArgument();
                try args.append(self.allocator, arg);

                // Check for comma (more arguments)
                if (self.current_token.type == .comma) {
                    try self.advance();
                } else {
                    break;
                }
            }

            try self.expect(.right_paren);
        }

        try self.expect(.semicolon);

        return types.Member{
            .type = .async_iterable,
            .async_iterable = types.AsyncIterable{
                .keyType = first_type,
                .valueType = value_type,
                .arguments = try args.toOwnedSlice(self.allocator),
                .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
            },
        };
    }

    /// Parse attribute member
    fn parseAttribute(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Member {
        var is_static = false;
        var is_readonly = false;

        if (self.current_token.type == .keyword_static) {
            is_static = true;
            try self.advance();
        }

        if (self.current_token.type == .keyword_readonly) {
            is_readonly = true;
            try self.advance();
        }

        // Handle 'inherit' keyword (used in subinterfaces to redeclare parent attributes)
        if (self.current_token.type == .keyword_inherit) {
            try self.advance();
            // inherit attributes are treated as readonly in most implementations
            is_readonly = true;
        }

        try self.expect(.keyword_attribute);

        // Parse inline extended attributes if present (e.g., attribute [LegacyNullToEmptyString] DOMString data)
        var inline_ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
        defer inline_ext_attrs.deinit(self.allocator);

        if (self.current_token.type == .left_bracket) {
            try self.parseExtendedAttributes(&inline_ext_attrs);
        }

        const idl_type = try self.parseType();
        const name = try self.expectIdentifier();

        try self.expect(.semicolon);

        // Merge inline and member-level extended attributes
        var all_ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
        defer all_ext_attrs.deinit(self.allocator);
        try all_ext_attrs.appendSlice(self.allocator, ext_attrs);
        try all_ext_attrs.appendSlice(self.allocator, inline_ext_attrs.items);

        return types.Member{
            .type = .attribute,
            .attribute = types.Attribute{
                .name = name,
                .idlType = idl_type,
                .readonly = is_readonly,
                .static = is_static,
                .extAttrs = try all_ext_attrs.toOwnedSlice(self.allocator),
            },
        };
    }

    /// Parse operation member
    fn parseOperation(self: *Parser, ext_attrs: []const types.ExtendedAttribute) !types.Member {
        var is_static = false;
        var special: ?types.SpecialOperation = null;

        // Check for special operation keywords
        if (self.current_token.type == .keyword_getter) {
            special = .getter;
            try self.advance();
        } else if (self.current_token.type == .keyword_setter) {
            special = .setter;
            try self.advance();
        } else if (self.current_token.type == .keyword_deleter) {
            special = .deleter;
            try self.advance();
        } else if (self.current_token.type == .keyword_stringifier) {
            special = .stringifier;
            try self.advance();

            // Check for bare stringifier; declaration (no type, no params)
            if (self.current_token.type == .semicolon) {
                try self.advance();
                return types.Member{
                    .type = .operation,
                    .operation = types.Operation{
                        .name = null,
                        .idlType = types.IDLType{ .type = try self.allocator.dupe(u8, "DOMString") },
                        .arguments = &.{},
                        .special = special,
                        .static = false,
                        .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
                    },
                };
            }

            // Check for stringifier attribute (e.g., stringifier attribute DOMString value;)
            // or stringifier readonly attribute (e.g., stringifier readonly attribute USVString href;)
            if (self.current_token.type == .keyword_attribute or self.current_token.type == .keyword_readonly) {
                // Parse as an attribute, the stringifier aspect is in the extended attributes
                return try self.parseAttribute(ext_attrs);
            }
        }

        if (self.current_token.type == .keyword_static) {
            is_static = true;
            try self.advance();
        }

        const return_type = try self.parseType();

        // Operation name is optional for some special operations
        // Try to parse name - expectIdentifier accepts keywords as identifiers
        var name: ?[]const u8 = null;
        if (self.current_token.type == .identifier or
            self.current_token.type == .keyword_includes or
            self.current_token.type == .keyword_callback or
            self.current_token.type == .keyword_constructor or
            self.current_token.type == .keyword_attribute or
            self.current_token.type == .keyword_readonly or
            self.current_token.type == .keyword_static or
            self.current_token.type == .keyword_iterable or
            self.current_token.type == .keyword_maplike or
            self.current_token.type == .keyword_setlike or
            self.current_token.type == .keyword_mixin or
            self.current_token.type == .keyword_interface or
            self.current_token.type == .keyword_namespace)
        {
            name = try self.expectIdentifier();
        }

        // Handle old-style attribute syntax without 'attribute' keyword: "Type name;"
        // This is legacy WebIDL syntax but still appears in some specs
        if (self.current_token.type == .semicolon and name != null) {
            try self.advance(); // consume semicolon
            return types.Member{
                .type = .attribute,
                .attribute = types.Attribute{
                    .name = name.?,
                    .idlType = return_type,
                    .readonly = false,
                    .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
                },
            };
        }

        try self.expect(.left_paren);

        var arguments = std.ArrayList(types.Argument).empty;
        defer arguments.deinit(self.allocator);

        while (self.current_token.type != .right_paren) {
            const arg = try self.parseArgument();
            try arguments.append(self.allocator, arg);

            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.expect(.right_paren);

        // Skip legacy raises clause from old WebIDL: raises(ExceptionName)
        if (self.current_token.type == .identifier and std.mem.eql(u8, self.current_token.lexeme, "raises")) {
            try self.advance(); // skip "raises"
            if (self.current_token.type == .left_paren) {
                try self.skipBalancedParens();
            }
        }

        try self.expect(.semicolon);

        return types.Member{
            .type = .operation,
            .operation = types.Operation{
                .name = name,
                .idlType = return_type,
                .arguments = try arguments.toOwnedSlice(self.allocator),
                .static = is_static,
                .special = special,
                .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs),
            },
        };
    }

    /// Parse function/constructor argument
    fn parseArgument(self: *Parser) !types.Argument {
        var is_optional = false;
        var is_variadic = false;

        // Extended attributes
        var ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
        defer ext_attrs.deinit(self.allocator);

        if (self.current_token.type == .left_bracket) {
            try self.parseExtendedAttributes(&ext_attrs);
        }

        if (self.current_token.type == .keyword_optional) {
            is_optional = true;
            try self.advance();
        }

        // Extended attributes can also appear after 'optional' keyword
        // e.g., optional [LegacyNullToEmptyString] DOMString features
        if (self.current_token.type == .left_bracket) {
            try self.parseExtendedAttributes(&ext_attrs);
        }

        // Skip legacy parameter direction keywords (in/out/inout) from old WebIDL
        if (self.current_token.type == .identifier) {
            const lexeme = self.current_token.lexeme;
            if (std.mem.eql(u8, lexeme, "in") or
                std.mem.eql(u8, lexeme, "out") or
                std.mem.eql(u8, lexeme, "inout"))
            {
                try self.advance(); // skip the direction keyword
            }
        }

        const arg_type = try self.parseType();

        if (self.current_token.type == .ellipsis) {
            is_variadic = true;
            try self.advance();
        }

        const name = try self.expectIdentifier();

        // Default value
        var default_value: ?types.Value = null;
        if (self.current_token.type == .equals) {
            try self.advance();
            default_value = try self.parseValue();
        }

        return types.Argument{
            .name = name,
            .idlType = arg_type,
            .optional = is_optional,
            .variadic = is_variadic,
            .default = default_value,
            .extAttrs = try self.allocator.dupe(types.ExtendedAttribute, ext_attrs.items),
        };
    }

    /// Parse union type: (TypeA or TypeB or TypeC)
    fn parseUnionType(self: *Parser) !types.IDLType {
        try self.expect(.left_paren);

        var union_str = std.ArrayList(u8).empty;
        defer union_str.deinit(self.allocator);

        // Collect individual union member types
        var union_types_list = std.ArrayList(types.IDLType).empty;
        defer union_types_list.deinit(self.allocator);

        try union_str.append(self.allocator, '(');

        // Parse first type (skip extended attributes if present)
        if (self.current_token.type == .left_bracket) {
            var ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
            defer ext_attrs.deinit(self.allocator);
            try self.parseExtendedAttributes(&ext_attrs);
        }
        const first_type = try self.parseSimpleType();
        try union_str.appendSlice(self.allocator, first_type.type);
        try union_types_list.append(self.allocator, first_type);

        // Parse remaining types separated by 'or'
        while (self.current_token.type == .keyword_or) {
            try self.advance(); // consume 'or'
            try union_str.appendSlice(self.allocator, " or ");

            // Skip extended attributes if present on union member
            if (self.current_token.type == .left_bracket) {
                var ext_attrs = std.ArrayList(types.ExtendedAttribute).empty;
                defer ext_attrs.deinit(self.allocator);
                try self.parseExtendedAttributes(&ext_attrs);
            }
            const next_type = try self.parseSimpleType();
            try union_str.appendSlice(self.allocator, next_type.type);
            try union_types_list.append(self.allocator, next_type);
        }

        try self.expect(.right_paren);
        try union_str.append(self.allocator, ')');

        // Handle nullable union: (A or B)?
        var is_nullable = false;
        if (self.current_token.type == .question) {
            try self.advance();
            try union_str.append(self.allocator, '?');
            is_nullable = true;
        }

        return types.IDLType{
            .type = try union_str.toOwnedSlice(self.allocator),
            .unionTypes = try union_types_list.toOwnedSlice(self.allocator),
            .nullable = is_nullable,
        };
    }

    /// Parse a simple (non-union) type
    fn parseSimpleType(self: *Parser) !types.IDLType {
        // Handle keywords like "undefined", "any"
        if (self.current_token.type == .keyword_undefined) {
            try self.advance();
            return types.IDLType{ .type = try self.allocator.dupe(u8, "undefined") };
        }
        if (self.current_token.type == .keyword_any) {
            try self.advance();
            return types.IDLType{ .type = try self.allocator.dupe(u8, "any") };
        }

        // Handle sequence<T>
        if (self.current_token.type == .keyword_sequence) {
            try self.advance();
            try self.expect(.left_angle);

            // Collect inner type as string (simpler than recursive parsing)
            // We track depth to handle nested generics like sequence<sequence<T>>
            var inner_type_str = std.ArrayList(u8).empty;
            defer inner_type_str.deinit(self.allocator);

            var depth: usize = 1;
            var needs_space = false;
            while (depth > 0 and self.current_token.type != .eof) {
                if (self.current_token.type == .left_angle) {
                    depth += 1;
                    try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                    try self.advance();
                    needs_space = false;
                } else if (self.current_token.type == .right_angle) {
                    depth -= 1;
                    if (depth > 0) {
                        try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                        try self.advance();
                        needs_space = false;
                    }
                } else {
                    // Add space before this token if needed (for multi-word types like "unsigned long")
                    if (needs_space and inner_type_str.items.len > 0) {
                        try inner_type_str.append(self.allocator, ' ');
                    }
                    try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                    try self.advance();
                    needs_space = true; // Next token might need a space
                }
            }

            try self.expect(.right_angle); // Consume final '>'

            // Handle nullable sequence<T>?
            const is_nullable = if (self.current_token.type == .question) blk: {
                try self.advance();
                break :blk true;
            } else false;

            // Return with populated generic field
            const inner_type_owned = try inner_type_str.toOwnedSlice(self.allocator);
            const trimmed = std.mem.trim(u8, inner_type_owned, " \t\n");
            const final_inner = try self.allocator.dupe(u8, trimmed);
            self.allocator.free(inner_type_owned);

            return types.IDLType{
                .type = try self.allocator.dupe(u8, "sequence"),
                .generic = final_inner,
                .nullable = is_nullable,
            };
        }

        // Handle record<K, V>
        if (self.current_token.type == .keyword_record) {
            try self.advance();
            try self.expect(.left_angle);

            // Collect inner types as string (K, V)
            // Need to track depth for nested generics like record<K, sequence<V>>
            var inner_type_str = std.ArrayList(u8).empty;
            defer inner_type_str.deinit(self.allocator);

            var depth: usize = 1;
            var needs_space = false;
            while (depth > 0 and self.current_token.type != .eof) {
                if (self.current_token.type == .left_angle) {
                    depth += 1;
                    try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                    try self.advance();
                    needs_space = false;
                } else if (self.current_token.type == .right_angle) {
                    depth -= 1;
                    if (depth > 0) {
                        try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                        try self.advance();
                        needs_space = false;
                    }
                } else {
                    // Add space before this token if needed (for multi-word types like "unsigned long")
                    if (needs_space and inner_type_str.items.len > 0 and self.current_token.type != .comma) {
                        try inner_type_str.append(self.allocator, ' ');
                    }
                    try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                    try self.advance();
                    needs_space = (self.current_token.type != .comma); // Don't add space after comma
                }
            }

            try self.expect(.right_angle); // Consume final '>'

            // Handle nullable record<K,V>?
            const is_nullable = if (self.current_token.type == .question) blk: {
                try self.advance();
                break :blk true;
            } else false;

            // Store the inner types in the generic field
            const inner_type_owned = try inner_type_str.toOwnedSlice(self.allocator);
            const trimmed = std.mem.trim(u8, inner_type_owned, " \t\n");
            const final_inner = try self.allocator.dupe(u8, trimmed);
            self.allocator.free(inner_type_owned);

            return types.IDLType{
                .type = try self.allocator.dupe(u8, "record"),
                .generic = final_inner,
                .nullable = is_nullable,
            };
        }

        // Parse identifier (possibly multi-word like "unsigned long")
        if (self.current_token.type != .identifier) {
            return error.ExpectedIdentifier;
        }

        var type_name = std.ArrayList(u8).empty;
        defer type_name.deinit(self.allocator);

        const base_type_name = self.current_token.lexeme;
        try type_name.appendSlice(self.allocator, base_type_name);
        try self.advance();

        // Handle namespace qualification: namespace::Type
        // For types like "stylesheets::MediaList", we just use the qualified name
        if (self.current_token.type == .colon and self.peek_token.type == .colon) {
            try type_name.appendSlice(self.allocator, "::");
            try self.advance(); // skip first ':'
            try self.advance(); // skip second ':'
            if (self.current_token.type == .identifier) {
                try type_name.appendSlice(self.allocator, self.current_token.lexeme);
                try self.advance();
            }
        }

        // Handle generic types like Promise<T>, FrozenArray<T>, ObservableArray<T>
        // Check if this is a known generic wrapper type
        const is_generic_wrapper = std.mem.eql(u8, base_type_name, "Promise") or
            std.mem.eql(u8, base_type_name, "FrozenArray") or
            std.mem.eql(u8, base_type_name, "ObservableArray");

        if (self.current_token.type == .left_angle) {
            if (is_generic_wrapper) {
                // Handle known generic wrappers by collecting inner type string
                try self.advance(); // consume '<'

                // Collect inner type as string
                var inner_type_str = std.ArrayList(u8).empty;
                defer inner_type_str.deinit(self.allocator);

                var depth: usize = 1;
                while (depth > 0 and self.current_token.type != .eof) {
                    if (self.current_token.type == .left_angle) {
                        depth += 1;
                        try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                        try self.advance();
                    } else if (self.current_token.type == .right_angle) {
                        depth -= 1;
                        if (depth > 0) {
                            try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                            try self.advance();
                        }
                    } else {
                        try inner_type_str.appendSlice(self.allocator, self.current_token.lexeme);
                        try self.advance();
                    }
                }

                try self.expect(.right_angle); // consume '>'

                // Handle nullable?
                const is_nullable = if (self.current_token.type == .question) blk: {
                    try self.advance();
                    break :blk true;
                } else false;

                const inner_type_owned = try inner_type_str.toOwnedSlice(self.allocator);
                const trimmed = std.mem.trim(u8, inner_type_owned, " \t\n");
                const final_inner = try self.allocator.dupe(u8, trimmed);
                self.allocator.free(inner_type_owned);

                return types.IDLType{
                    .type = try self.allocator.dupe(u8, base_type_name),
                    .generic = final_inner,
                    .nullable = is_nullable,
                };
            } else {
                // Unknown generic type - concatenate as string for backward compatibility
                try type_name.append(self.allocator, '<');
                try self.advance();
                var depth: usize = 1;
                while (depth > 0 and self.current_token.type != .eof) {
                    if (self.current_token.type == .left_angle) {
                        depth += 1;
                    } else if (self.current_token.type == .right_angle) {
                        depth -= 1;
                    }
                    if (depth > 0) {
                        try type_name.appendSlice(self.allocator, self.current_token.lexeme);
                    }
                    try self.advance();
                }
                try type_name.append(self.allocator, '>');
            }
        }
        // Handle multi-word types like "unsigned long"
        else if (self.current_token.type == .identifier) {
            const next_word = self.current_token.lexeme;
            if (std.mem.eql(u8, next_word, "short") or
                std.mem.eql(u8, next_word, "long") or
                std.mem.eql(u8, next_word, "double") or
                std.mem.eql(u8, next_word, "float"))
            {
                try type_name.append(self.allocator, ' ');
                try type_name.appendSlice(self.allocator, next_word);
                try self.advance();

                // Handle "long long"
                if (self.current_token.type == .identifier and std.mem.eql(u8, self.current_token.lexeme, "long")) {
                    try type_name.append(self.allocator, ' ');
                    try type_name.appendSlice(self.allocator, "long");
                    try self.advance();
                }
            }
        }

        // Handle nullable (?)
        const is_nullable = if (self.current_token.type == .question) blk: {
            try self.advance();
            break :blk true;
        } else false;

        return types.IDLType{
            .type = try type_name.toOwnedSlice(self.allocator),
            .nullable = is_nullable,
        };
    }

    /// Parse WebIDL type
    fn parseType(self: *Parser) !types.IDLType {
        // Handle union types: (A or B or C)
        if (self.current_token.type == .left_paren) {
            return try self.parseUnionType();
        }

        // Otherwise, parse as simple type
        return try self.parseSimpleType();
    }

    /// Parse value (for constants and defaults)
    fn parseValue(self: *Parser) !types.Value {
        if (self.current_token.type == .integer_literal) {
            // Auto-detect base (0x prefix means hex, otherwise decimal)
            const value = try std.fmt.parseInt(i64, self.current_token.lexeme, 0);
            try self.advance();
            return types.Value{ .integer = value };
        } else if (self.current_token.type == .float_literal) {
            const value = try std.fmt.parseFloat(f64, self.current_token.lexeme);
            try self.advance();
            return types.Value{ .float = value };
        } else if (self.current_token.type == .keyword_true) {
            try self.advance();
            return types.Value{ .boolean = true };
        } else if (self.current_token.type == .keyword_false) {
            try self.advance();
            return types.Value{ .boolean = false };
        } else if (self.current_token.type == .keyword_null) {
            try self.advance();
            return types.Value.null;
        } else if (self.current_token.type == .string_literal) {
            const str = try self.allocator.dupe(u8, self.current_token.lexeme);
            try self.advance();
            return types.Value{ .string = str };
        } else if (self.current_token.type == .left_brace) {
            // Empty object literal {}
            try self.expect(.left_brace);
            try self.expect(.right_brace);
            return types.Value.null;
        } else if (self.current_token.type == .left_bracket) {
            // Empty array literal []
            try self.expect(.left_bracket);
            try self.expect(.right_bracket);
            return types.Value.null;
        } else {
            return error.UnexpectedToken;
        }
    }

    /// Expect a specific token type and advance
    fn expect(self: *Parser, token_type: TokenType) !void {
        if (self.current_token.type != token_type) {
            return error.UnexpectedToken;
        }
        try self.advance();
    }

    /// Expect an identifier and return its value
    /// Also accepts keywords that can be used as identifiers (like 'callback', 'interface', 'namespace' as parameter names)
    fn expectIdentifier(self: *Parser) ![]const u8 {
        // Allow identifier or certain keywords that can be used as identifiers
        // WebIDL allows most keywords to be used as identifiers in certain contexts
        const is_valid = self.current_token.type == .identifier or
            self.current_token.type == .keyword_callback or
            self.current_token.type == .keyword_getter or
            self.current_token.type == .keyword_setter or
            self.current_token.type == .keyword_deleter or
            self.current_token.type == .keyword_stringifier or
            self.current_token.type == .keyword_interface or
            self.current_token.type == .keyword_namespace or
            self.current_token.type == .keyword_constructor or
            self.current_token.type == .keyword_attribute or
            self.current_token.type == .keyword_readonly or
            self.current_token.type == .keyword_static or
            self.current_token.type == .keyword_iterable or
            self.current_token.type == .keyword_maplike or
            self.current_token.type == .keyword_setlike or
            self.current_token.type == .keyword_mixin or
            self.current_token.type == .keyword_includes;

        if (!is_valid) {
            return error.ExpectedIdentifier;
        }
        const value = try self.allocator.dupe(u8, self.current_token.lexeme);
        try self.advance();
        return value;
    }

    /// Advance to next token
    fn advance(self: *Parser) !void {
        self.current_token = self.peek_token;
        self.peek_token = try self.lexer.nextToken();
    }

    /// Skip balanced parentheses - useful for extended attributes with function-like syntax
    /// Assumes current token is '(' and advances past the matching ')'
    fn skipBalancedParens(self: *Parser) !void {
        if (self.current_token.type != .left_paren) {
            return error.ExpectedLeftParen;
        }

        var depth: u32 = 1;
        try self.advance(); // Skip the initial '('

        while (depth > 0 and self.current_token.type != .eof) {
            if (self.current_token.type == .left_paren) {
                depth += 1;
            } else if (self.current_token.type == .right_paren) {
                depth -= 1;
            }

            if (depth > 0) {
                try self.advance();
            }
        }

        if (depth != 0) {
            return error.UnbalancedParentheses;
        }

        // Advance past the final ')'
        try self.advance();
    }

    // Memory management helpers
    pub fn freeInterface(self: *Parser, iface: *types.Interface) void {
        self.allocator.free(iface.name);
        if (iface.inheritance) |inheritance| {
            self.allocator.free(inheritance);
        }
        for (iface.includes) |include| {
            self.allocator.free(include);
        }
        self.allocator.free(iface.includes);
        for (iface.members) |*member| {
            self.freeMember(member);
        }
        self.allocator.free(iface.members);
        for (iface.extAttrs) |*attr| {
            self.freeExtendedAttribute(attr);
        }
        self.allocator.free(iface.extAttrs);
    }

    pub fn freeDictionary(self: *Parser, dict: *types.Dictionary) void {
        self.allocator.free(dict.name);
        if (dict.inheritance) |inheritance| {
            self.allocator.free(inheritance);
        }
        for (dict.members) |*member| {
            self.freeDictionaryMember(member);
        }
        self.allocator.free(dict.members);
        for (dict.extAttrs) |*attr| {
            self.freeExtendedAttribute(attr);
        }
        self.allocator.free(dict.extAttrs);
    }

    pub fn freeNamespace(self: *Parser, ns: *types.Namespace) void {
        self.allocator.free(ns.name);
        for (ns.members) |*member| {
            self.freeMember(member);
        }
        self.allocator.free(ns.members);
        for (ns.extAttrs) |*attr| {
            self.freeExtendedAttribute(attr);
        }
        self.allocator.free(ns.extAttrs);
    }

    pub fn freeEnum(self: *Parser, enm: *types.Enum) void {
        self.allocator.free(enm.name);
        for (enm.values) |value| {
            self.allocator.free(value);
        }
        self.allocator.free(enm.values);
        for (enm.extAttrs) |*attr| {
            self.freeExtendedAttribute(attr);
        }
        self.allocator.free(enm.extAttrs);
    }

    pub fn freeCallback(self: *Parser, cb: *types.Callback) void {
        self.allocator.free(cb.name);
        self.freeIDLType(&cb.idlType);
        for (cb.arguments) |*arg| {
            self.freeArgument(arg);
        }
        self.allocator.free(cb.arguments);
        for (cb.extAttrs) |*attr| {
            self.freeExtendedAttribute(attr);
        }
        self.allocator.free(cb.extAttrs);
    }

    pub fn freeTypedef(self: *Parser, td: *types.Typedef) void {
        self.allocator.free(td.name);
        self.freeIDLType(&td.idlType);
        for (td.extAttrs) |*attr| {
            self.freeExtendedAttribute(attr);
        }
        self.allocator.free(td.extAttrs);
    }

    fn freeDictionaryMember(self: *Parser, member: *types.DictionaryMember) void {
        self.allocator.free(member.name);
        self.freeIDLType(&member.idlType);
        if (member.default) |*value| {
            self.freeValue(value);
        }
        for (member.extAttrs) |*attr| {
            self.freeExtendedAttribute(attr);
        }
        self.allocator.free(member.extAttrs);
    }

    fn freeMember(self: *Parser, member: *types.Member) void {
        switch (member.type) {
            .attribute => if (member.attribute) |*attr| {
                self.allocator.free(attr.name);
                self.freeIDLType(&attr.idlType);
                for (attr.extAttrs) |*ext_attr| {
                    self.freeExtendedAttribute(ext_attr);
                }
                self.allocator.free(attr.extAttrs);
            },
            .operation => if (member.operation) |*op| {
                if (op.name) |name| {
                    self.allocator.free(name);
                }
                self.freeIDLType(&op.idlType);
                for (op.arguments) |*arg| {
                    self.freeArgument(arg);
                }
                self.allocator.free(op.arguments);
                for (op.extAttrs) |*ext_attr| {
                    self.freeExtendedAttribute(ext_attr);
                }
                self.allocator.free(op.extAttrs);
            },
            .constructor => if (member.constructor) |*ctor| {
                for (ctor.arguments) |*arg| {
                    self.freeArgument(arg);
                }
                self.allocator.free(ctor.arguments);
                for (ctor.extAttrs) |*ext_attr| {
                    self.freeExtendedAttribute(ext_attr);
                }
                self.allocator.free(ctor.extAttrs);
            },
            .constant => if (member.constant) |*cnst| {
                self.allocator.free(cnst.name);
                self.freeIDLType(&cnst.idlType);
                self.freeValue(&cnst.value);
                for (cnst.extAttrs) |*ext_attr| {
                    self.freeExtendedAttribute(ext_attr);
                }
                self.allocator.free(cnst.extAttrs);
            },
            .iterable => if (member.iterable) |*iter| {
                self.freeIDLType(&iter.keyType);
                if (iter.valueType) |*vtype| {
                    self.freeIDLType(vtype);
                }
                for (iter.extAttrs) |*ext_attr| {
                    self.freeExtendedAttribute(ext_attr);
                }
                self.allocator.free(iter.extAttrs);
            },
            .async_iterable => if (member.async_iterable) |*async_iter| {
                self.freeIDLType(&async_iter.keyType);
                if (async_iter.valueType) |*vtype| {
                    self.freeIDLType(vtype);
                }
                for (async_iter.arguments) |*arg| {
                    self.freeArgument(arg);
                }
                self.allocator.free(async_iter.arguments);
                for (async_iter.extAttrs) |*ext_attr| {
                    self.freeExtendedAttribute(ext_attr);
                }
                self.allocator.free(async_iter.extAttrs);
            },
        }
    }

    fn freeArgument(self: *Parser, arg: *types.Argument) void {
        self.allocator.free(arg.name);
        self.freeIDLType(&arg.idlType);
        if (arg.default) |*value| {
            self.freeValue(value);
        }
        for (arg.extAttrs) |*ext_attr| {
            self.freeExtendedAttribute(ext_attr);
        }
        self.allocator.free(arg.extAttrs);
    }

    fn freeIDLType(self: *Parser, idl_type: *types.IDLType) void {
        self.allocator.free(idl_type.type);

        if (idl_type.generic) |generic| {
            self.allocator.free(generic);
        }

        if (idl_type.unionTypes) |union_types| {
            for (union_types) |*ut| {
                self.freeIDLType(ut);
            }
            self.allocator.free(union_types);
        }

        if (idl_type.sequence) |seq| {
            self.freeIDLType(seq);
            self.allocator.destroy(seq);
        }

        if (idl_type.record) |rec| {
            self.freeIDLType(rec.key);
            self.allocator.destroy(rec.key);
            self.freeIDLType(rec.value);
            self.allocator.destroy(rec.value);
        }
    }

    fn freeValue(self: *Parser, value: *types.Value) void {
        switch (value.*) {
            .string => |str| self.allocator.free(str),
            else => {},
        }
    }

    fn freeExtendedAttribute(self: *Parser, attr: *types.ExtendedAttribute) void {
        self.allocator.free(attr.name);
        if (attr.rhs) |*rhs| {
            switch (rhs.*) {
                .identifier => |id| self.allocator.free(id),
                .identifierList => |list| {
                    for (list) |id| {
                        self.allocator.free(id);
                    }
                    self.allocator.free(list);
                },
                .string => |str| self.allocator.free(str),
                .integer => {},
            }
        }
    }
};

// Tests
const testing = std.testing;

test "parser: simple interface" {
    const source =
        \\interface EventTarget {
        \\  constructor();
        \\};
    ;

    const idl_file = try Parser.parse(testing.allocator, source);
    defer {
        for (idl_file.interfaces) |*iface| {
            var parser = Parser{
                .allocator = testing.allocator,
                .lexer = undefined,
                .current_token = undefined,
                .peek_token = undefined,
            };
            parser.freeInterface(iface);
        }
        testing.allocator.free(idl_file.interfaces);
        testing.allocator.free(idl_file.dictionaries);
    }

    try testing.expectEqual(@as(usize, 1), idl_file.interfaces.len);
    try testing.expectEqualStrings("EventTarget", idl_file.interfaces[0].name);
    try testing.expectEqual(@as(usize, 1), idl_file.interfaces[0].members.len);
    try testing.expectEqual(types.MemberType.constructor, idl_file.interfaces[0].members[0].type);
}

test "parser: interface with inheritance" {
    const source =
        \\interface CustomEvent : Event {
        \\};
    ;

    const idl_file = try Parser.parse(testing.allocator, source);
    defer {
        for (idl_file.interfaces) |*iface| {
            var parser = Parser{
                .allocator = testing.allocator,
                .lexer = undefined,
                .current_token = undefined,
                .peek_token = undefined,
            };
            parser.freeInterface(iface);
        }
        testing.allocator.free(idl_file.interfaces);
        testing.allocator.free(idl_file.dictionaries);
    }

    try testing.expectEqual(@as(usize, 1), idl_file.interfaces.len);
    try testing.expectEqualStrings("CustomEvent", idl_file.interfaces[0].name);
    try testing.expectEqualStrings("Event", idl_file.interfaces[0].inheritance.?);
}

test "parser: interface with attributes" {
    const source =
        \\interface Event {
        \\  readonly attribute DOMString type;
        \\  attribute boolean cancelable;
        \\};
    ;

    const idl_file = try Parser.parse(testing.allocator, source);
    defer {
        for (idl_file.interfaces) |*iface| {
            var parser = Parser{
                .allocator = testing.allocator,
                .lexer = undefined,
                .current_token = undefined,
                .peek_token = undefined,
            };
            parser.freeInterface(iface);
        }
        testing.allocator.free(idl_file.interfaces);
        testing.allocator.free(idl_file.dictionaries);
    }

    try testing.expectEqual(@as(usize, 2), idl_file.interfaces[0].members.len);

    const attr1 = idl_file.interfaces[0].members[0].attribute.?;
    try testing.expectEqualStrings("type", attr1.name);
    try testing.expectEqualStrings("DOMString", attr1.idlType.type);
    try testing.expect(attr1.readonly);

    const attr2 = idl_file.interfaces[0].members[1].attribute.?;
    try testing.expectEqualStrings("cancelable", attr2.name);
    try testing.expectEqualStrings("boolean", attr2.idlType.type);
    try testing.expect(!attr2.readonly);
}

test "parser: interface with operations" {
    const source =
        \\interface EventTarget {
        \\  undefined addEventListener(DOMString type);
        \\  boolean dispatchEvent(Event event);
        \\};
    ;

    const idl_file = try Parser.parse(testing.allocator, source);
    defer {
        for (idl_file.interfaces) |*iface| {
            var parser = Parser{
                .allocator = testing.allocator,
                .lexer = undefined,
                .current_token = undefined,
                .peek_token = undefined,
            };
            parser.freeInterface(iface);
        }
        testing.allocator.free(idl_file.interfaces);
        testing.allocator.free(idl_file.dictionaries);
    }

    try testing.expectEqual(@as(usize, 2), idl_file.interfaces[0].members.len);

    const op1 = idl_file.interfaces[0].members[0].operation.?;
    try testing.expectEqualStrings("addEventListener", op1.name.?);
    try testing.expectEqualStrings("undefined", op1.idlType.type);
    try testing.expectEqual(@as(usize, 1), op1.arguments.len);

    const op2 = idl_file.interfaces[0].members[1].operation.?;
    try testing.expectEqualStrings("dispatchEvent", op2.name.?);
    try testing.expectEqualStrings("boolean", op2.idlType.type);
}

test "parser: interface with constants" {
    const source =
        \\interface Event {
        \\  const unsigned short NONE = 0;
        \\  const unsigned short CAPTURING_PHASE = 1;
        \\};
    ;

    const idl_file = try Parser.parse(testing.allocator, source);
    defer {
        for (idl_file.interfaces) |*iface| {
            var parser = Parser{
                .allocator = testing.allocator,
                .lexer = undefined,
                .current_token = undefined,
                .peek_token = undefined,
            };
            parser.freeInterface(iface);
        }
        testing.allocator.free(idl_file.interfaces);
        testing.allocator.free(idl_file.dictionaries);
    }

    try testing.expectEqual(@as(usize, 2), idl_file.interfaces[0].members.len);

    const cnst1 = idl_file.interfaces[0].members[0].constant.?;
    try testing.expectEqualStrings("NONE", cnst1.name);
    try testing.expectEqual(@as(i64, 0), cnst1.value.integer);

    const cnst2 = idl_file.interfaces[0].members[1].constant.?;
    try testing.expectEqualStrings("CAPTURING_PHASE", cnst2.name);
    try testing.expectEqual(@as(i64, 1), cnst2.value.integer);
}
