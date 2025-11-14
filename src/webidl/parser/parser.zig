const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lexer.zig").Token;
const TokenType = @import("lexer.zig").TokenType;
const ast = @import("ast.zig");
const AST = ast.AST;
const Definition = ast.Definition;
const Interface = ast.Interface;
const InterfaceMixin = ast.InterfaceMixin;
const InterfaceMember = ast.InterfaceMember;
const Attribute = ast.Attribute;
const Operation = ast.Operation;
const SpecialOperation = ast.SpecialOperation;
const Argument = ast.Argument;
const Type = ast.Type;
const Constructor = ast.Constructor;
const Stringifier = ast.Stringifier;
const Iterable = ast.Iterable;
const AsyncIterable = ast.AsyncIterable;
const Maplike = ast.Maplike;
const Setlike = ast.Setlike;
const Dictionary = ast.Dictionary;
const DictionaryMember = ast.DictionaryMember;
const Enum = ast.Enum;
const Typedef = ast.Typedef;
const Callback = ast.Callback;
const CallbackInterface = ast.CallbackInterface;
const ExtendedAttribute = ast.ExtendedAttribute;
const ExtendedAttrValue = ast.ExtendedAttrValue;
const NamedArgList = ast.NamedArgList;
const IncludesStatement = ast.IncludesStatement;
const Namespace = ast.Namespace;
const NamespaceMember = ast.NamespaceMember;
const Const = ast.Const;
const Value = ast.Value;
const ParseError = @import("error.zig").ParseError;
const reportError = @import("error.zig").reportError;
const reportErrorSimple = @import("error.zig").reportErrorSimple;

pub const Parser = struct {
    lexer: *Lexer,
    current: Token,
    previous: Token,
    allocator: Allocator,
    filename: []const u8,
    had_error: bool,
    panic_mode: bool,

    pub fn init(allocator: Allocator, lexer: *Lexer, filename: []const u8) !Parser {
        var parser = Parser{
            .lexer = lexer,
            .current = undefined,
            .previous = undefined,
            .allocator = allocator,
            .filename = filename,
            .had_error = false,
            .panic_mode = false,
        };

        parser.current = try lexer.nextToken();
        return parser;
    }

    pub fn parse(self: *Parser) !AST {
        var definitions = infra.List(Definition).init(self.allocator);
        errdefer {
            for (definitions.items) |*def| {
                def.deinit();
            }
            definitions.deinit();
        }

        while (!self.check(.eof)) {
            if (self.parseDefinition()) |def| {
                try definitions.append( def);
            } else |err| {
                if (self.panic_mode) {
                    self.synchronize();
                } else {
                    return err;
                }
            }
        }

        if (self.had_error) {
            return ParseError.UnexpectedToken;
        }

        return AST{
            .definitions = try definitions.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    fn parseDefinition(self: *Parser) !Definition {
        // Skip legacy pragma statements
        if (self.match(.pragma)) {
            // Skip everything until semicolon or newline
            while (!self.check(.semicolon) and !self.check(.eof)) {
                _ = self.advance();
            }
            _ = self.match(.semicolon);
            // Recursively try next definition
            return try self.parseDefinition();
        }

        // Handle legacy module blocks
        if (self.match(.module)) {
            // Skip module name
            _ = self.advance();
            _ = try self.consume(.lbrace, "Expected '{'");

            // Parse definitions inside module until we hit the closing brace
            var definitions = infra.List(Definition).init(self.allocator);
            errdefer {
                for (definitions.items) |*def| {
                    def.deinit();
                }
                definitions.deinit();
            }

            while (!self.check(.rbrace) and !self.check(.eof)) {
                const def = try self.parseDefinition();
                try definitions.append( def);
            }

            _ = try self.consume(.rbrace, "Expected '}'");
            _ = self.match(.semicolon);

            // For now, return the first definition in the module
            // (This is a simplification - ideally we'd return all definitions)
            if (definitions.items.len > 0) {
                const first_def = definitions.items[0];
                // Clean up the rest
                for (definitions.items[1..]) |*def| {
                    def.deinit();
                }
                definitions.deinit();
                return first_def;
            } else {
                definitions.deinit();
                return try self.parseDefinition();
            }
        }

        const ext_attrs = try self.parseExtendedAttributeList();

        if (self.match(.partial)) {
            return try self.parsePartialDefinition(ext_attrs);
        }

        if (self.match(.callback)) {
            if (self.match(.interface)) {
                return try self.parseCallbackInterface(ext_attrs);
            }
            return try self.parseCallback(ext_attrs);
        }

        if (self.match(.interface)) {
            if (self.previous.lexeme.len > 0 and self.check(.mixin)) {
                _ = try self.consume(.mixin, "Expected 'mixin'");
                return try self.parseInterfaceMixin(ext_attrs, false);
            }
            return try self.parseInterface(ext_attrs, false);
        }

        if (self.match(.dictionary)) {
            return try self.parseDictionary(ext_attrs, false);
        }

        if (self.match(.@"enum")) {
            return try self.parseEnum(ext_attrs);
        }

        if (self.match(.typedef)) {
            return try self.parseTypedef(ext_attrs);
        }

        if (self.match(.namespace)) {
            return try self.parseNamespace(ext_attrs, false);
        }

        if (self.check(.identifier)) {
            // Lookahead: check if pattern is "identifier includes ..."
            // Save complete parser and lexer state
            const checkpoint_current = self.current;
            const checkpoint_previous = self.previous;
            const checkpoint_lexer_pos = self.lexer.current;
            const checkpoint_lexer_line = self.lexer.line;
            const checkpoint_lexer_column = self.lexer.column;

            self.advance(); // consume identifier temporarily
            const has_includes = self.check(.includes);

            // Restore complete state
            self.current = checkpoint_current;
            self.previous = checkpoint_previous;
            self.lexer.current = checkpoint_lexer_pos;
            self.lexer.line = checkpoint_lexer_line;
            self.lexer.column = checkpoint_lexer_column;

            if (has_includes) {
                const name = try self.consume(.identifier, "Expected identifier");
                _ = try self.consume(.includes, "Expected 'includes'");
                const mixin_name = try self.consume(.identifier, "Expected mixin name");
                _ = try self.consume(.semicolon, "Expected ';'");

                return Definition{
                    .includes = IncludesStatement{
                        .interface = name.lexeme,
                        .mixin = mixin_name.lexeme,
                    },
                };
            }
        }

        return self.fail("Expected definition");
    }

    fn parsePartialDefinition(self: *Parser, ext_attrs: []ExtendedAttribute) !Definition {
        if (self.match(.interface)) {
            if (self.match(.mixin)) {
                return try self.parseInterfaceMixin(ext_attrs, true);
            }
            return try self.parseInterface(ext_attrs, true);
        }

        if (self.match(.dictionary)) {
            return try self.parseDictionary(ext_attrs, true);
        }

        if (self.match(.namespace)) {
            return try self.parseNamespace(ext_attrs, true);
        }

        return self.fail("Expected interface, dictionary, or namespace after 'partial'");
    }

    fn parseInterface(self: *Parser, ext_attrs: []ExtendedAttribute, partial: bool) !Definition {
        const name = try self.consume(.identifier, "Expected interface name");

        var inherits: ?[]const u8 = null;
        if (self.match(.colon)) {
            const parent = try self.consume(.identifier, "Expected parent interface name");

            // Check for namespace qualifier (e.g., stylesheets::StyleSheet)
            if (self.match(.double_colon)) {
                const qualified_ident = try self.consumeIdentifierOrKeyword("Expected identifier after '::'");

                // Combine namespace::identifier into a single string
                inherits = try std.fmt.allocPrint(self.allocator, "{s}::{s}", .{ parent.lexeme, qualified_ident.lexeme });
            } else {
                // Duplicate the string so it can be freed consistently
                inherits = try std.fmt.allocPrint(self.allocator, "{s}", .{parent.lexeme});
            }
        }

        // Check for forward declaration (interface Foo;)
        if (self.match(.semicolon)) {
            return Definition{
                .interface = Interface{
                    .name = name.lexeme,
                    .inherits = inherits,
                    .members = &.{}, // Empty slice
                    .extended_attributes = ext_attrs,
                    .partial = partial,
                },
            };
        }

        _ = try self.consume(.lbrace, "Expected '{'");

        var members = infra.List(InterfaceMember).init(self.allocator);
        errdefer {
            for (members.items) |*member| {
                member.deinit();
            }
            members.deinit();
        }

        while (!self.check(.rbrace) and !self.check(.eof)) {
            const member = try self.parseInterfaceMember();
            try members.append( member);
        }

        _ = try self.consume(.rbrace, "Expected '}'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Definition{
            .interface = Interface{
                .name = name.lexeme,
                .inherits = inherits,
                .members = try members.toOwnedSlice(),
                .extended_attributes = ext_attrs,
                .partial = partial,
            },
        };
    }

    fn parseInterfaceMixin(self: *Parser, ext_attrs: []ExtendedAttribute, partial: bool) !Definition {
        const name = try self.consume(.identifier, "Expected mixin name");

        _ = try self.consume(.lbrace, "Expected '{'");

        var members = infra.List(InterfaceMember).init(self.allocator);
        errdefer {
            for (members.items) |*member| {
                member.deinit();
            }
            members.deinit();
        }

        while (!self.check(.rbrace) and !self.check(.eof)) {
            const member = try self.parseInterfaceMember();
            try members.append( member);
        }

        _ = try self.consume(.rbrace, "Expected '}'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Definition{
            .interface_mixin = InterfaceMixin{
                .name = name.lexeme,
                .members = try members.toOwnedSlice(),
                .extended_attributes = ext_attrs,
                .partial = partial,
            },
        };
    }

    fn parseInterfaceMember(self: *Parser) !InterfaceMember {
        const member_ext_attrs = try self.parseExtendedAttributeList();

        if (self.match(.constructor)) {
            return InterfaceMember{ .constructor = try self.parseConstructor(member_ext_attrs) };
        }

        if (self.match(.stringifier)) {
            if (self.check(.semicolon)) {
                _ = try self.consume(.semicolon, "Expected ';'");
                // Cleanup unused extended attributes
                for (member_ext_attrs) |*attr| {
                    var mut_attr = attr.*;
                    mut_attr.deinit();
                }
                self.allocator.free(member_ext_attrs);
                return InterfaceMember{ .stringifier = Stringifier{ .keyword = {} } };
            }

            if (self.match(.readonly)) {
                if (self.match(.attribute)) {
                    const attr = try self.parseAttributeRest(member_ext_attrs, true, false, true, false);
                    return InterfaceMember{ .stringifier = Stringifier{ .attribute = attr } };
                }
            } else if (self.match(.attribute)) {
                const attr = try self.parseAttributeRest(member_ext_attrs, false, false, true, false);
                return InterfaceMember{ .stringifier = Stringifier{ .attribute = attr } };
            }

            const op = try self.parseOperation(member_ext_attrs, false, .stringifier);
            return InterfaceMember{ .stringifier = Stringifier{ .operation = op } };
        }

        if (self.match(.static)) {
            if (self.match(.readonly) and self.match(.attribute)) {
                return InterfaceMember{ .attribute = try self.parseAttributeRest(member_ext_attrs, true, true, false, false) };
            } else if (self.match(.attribute)) {
                return InterfaceMember{ .attribute = try self.parseAttributeRest(member_ext_attrs, false, true, false, false) };
            } else {
                return InterfaceMember{ .operation = try self.parseOperation(member_ext_attrs, true, null) };
            }
        }

        if (self.match(.iterable)) {
            // Cleanup unused extended attributes
            for (member_ext_attrs) |*attr| {
                var mut_attr = attr.*;
                mut_attr.deinit();
            }
            self.allocator.free(member_ext_attrs);
            return InterfaceMember{ .iterable = try self.parseIterable() };
        }

        if (self.match(.async)) {
            _ = try self.consume(.iterable, "Expected 'iterable'");
            // Cleanup unused extended attributes
            for (member_ext_attrs) |*attr| {
                var mut_attr = attr.*;
                mut_attr.deinit();
            }
            self.allocator.free(member_ext_attrs);
            return InterfaceMember{ .async_iterable = try self.parseAsyncIterable() };
        }

        // Also support async_iterable as a single token (some specs use this)
        if (self.match(.async_iterable)) {
            // Cleanup unused extended attributes
            for (member_ext_attrs) |*attr| {
                var mut_attr = attr.*;
                mut_attr.deinit();
            }
            self.allocator.free(member_ext_attrs);
            return InterfaceMember{ .async_iterable = try self.parseAsyncIterable() };
        }

        if (self.match(.readonly)) {
            if (self.match(.maplike)) {
                // Cleanup unused extended attributes
                for (member_ext_attrs) |*attr| {
                    var mut_attr = attr.*;
                    mut_attr.deinit();
                }
                self.allocator.free(member_ext_attrs);
                return InterfaceMember{ .maplike = try self.parseMaplike(true) };
            } else if (self.match(.setlike)) {
                // Cleanup unused extended attributes
                for (member_ext_attrs) |*attr| {
                    var mut_attr = attr.*;
                    mut_attr.deinit();
                }
                self.allocator.free(member_ext_attrs);
                return InterfaceMember{ .setlike = try self.parseSetlike(true) };
            } else if (self.match(.attribute)) {
                return InterfaceMember{ .attribute = try self.parseAttributeRest(member_ext_attrs, true, false, false, false) };
            }
        }

        if (self.match(.maplike)) {
            // Cleanup unused extended attributes
            for (member_ext_attrs) |*attr| {
                var mut_attr = attr.*;
                mut_attr.deinit();
            }
            self.allocator.free(member_ext_attrs);
            return InterfaceMember{ .maplike = try self.parseMaplike(false) };
        }

        if (self.match(.setlike)) {
            // Cleanup unused extended attributes
            for (member_ext_attrs) |*attr| {
                var mut_attr = attr.*;
                mut_attr.deinit();
            }
            self.allocator.free(member_ext_attrs);
            return InterfaceMember{ .setlike = try self.parseSetlike(false) };
        }

        if (self.match(.inherit)) {
            _ = try self.consume(.attribute, "Expected 'attribute'");
            return InterfaceMember{ .attribute = try self.parseAttributeRest(member_ext_attrs, false, false, false, true) };
        }

        if (self.match(.attribute)) {
            return InterfaceMember{ .attribute = try self.parseAttributeRest(member_ext_attrs, false, false, false, false) };
        }

        if (self.match(.const_kw)) {
            // Cleanup unused extended attributes
            for (member_ext_attrs) |*attr| {
                var mut_attr = attr.*;
                mut_attr.deinit();
            }
            self.allocator.free(member_ext_attrs);
            return InterfaceMember{ .const_member = try self.parseConst() };
        }

        const special = self.parseSpecialOperation();
        if (special) |spec| {
            return InterfaceMember{ .operation = try self.parseOperation(member_ext_attrs, false, spec) };
        }

        // Try to parse as operation, but handle the case where it might be an attribute without the 'attribute' keyword
        // This is for older IDL syntax like: DOMString type;
        // Lookahead to check if this is "Type name ;" pattern (attribute) vs "Type name (...)" pattern (operation)
        const checkpoint_current = self.current;
        const checkpoint_previous = self.previous;
        const checkpoint_lexer_pos = self.lexer.current;
        const checkpoint_lexer_line = self.lexer.line;
        const checkpoint_lexer_column = self.lexer.column;

        // Try to parse as attribute first
        var type_result = self.parseType() catch {
            // Restore and try as operation
            self.current = checkpoint_current;
            self.previous = checkpoint_previous;
            self.lexer.current = checkpoint_lexer_pos;
            self.lexer.line = checkpoint_lexer_line;
            self.lexer.column = checkpoint_lexer_column;
            return InterfaceMember{ .operation = try self.parseOperation(member_ext_attrs, false, null) };
        };
        errdefer type_result.deinit();

        // Check if followed by identifier and semicolon (attribute pattern)
        if (self.check(.identifier) or self.isKeywordAllowedAsIdentifier()) {
            const name_token = self.consumeIdentifierOrKeyword("Expected name") catch {
                // Cleanup type before backtracking
                type_result.deinit();
                // Restore and parse as operation
                self.current = checkpoint_current;
                self.previous = checkpoint_previous;
                self.lexer.current = checkpoint_lexer_pos;
                self.lexer.line = checkpoint_lexer_line;
                self.lexer.column = checkpoint_lexer_column;
                return InterfaceMember{ .operation = try self.parseOperation(member_ext_attrs, false, null) };
            };

            if (self.check(.semicolon)) {
                // This is an attribute without 'attribute' keyword
                _ = try self.consume(.semicolon, "Expected ';'");
                return InterfaceMember{ .attribute = Attribute{
                    .name = name_token.lexeme,
                    .type = type_result,
                    .readonly = false,
                    .static = false,
                    .stringifier = false,
                    .inherit = false,
                    .extended_attributes = member_ext_attrs,
                } };
            }
        }

        // Not an attribute pattern, cleanup type and restore to parse as operation
        type_result.deinit();
        self.current = checkpoint_current;
        self.previous = checkpoint_previous;
        self.lexer.current = checkpoint_lexer_pos;
        self.lexer.line = checkpoint_lexer_line;
        self.lexer.column = checkpoint_lexer_column;
        return InterfaceMember{ .operation = try self.parseOperation(member_ext_attrs, false, null) };
    }

    fn parseAttributeRest(self: *Parser, ext_attrs: []ExtendedAttribute, readonly: bool, static: bool, stringifier: bool, inherit: bool) !Attribute {
        const type_val = try self.parseType();
        const name = try self.consumeIdentifierOrKeyword("Expected attribute name");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Attribute{
            .name = name.lexeme,
            .type = type_val,
            .readonly = readonly,
            .static = static,
            .stringifier = stringifier,
            .inherit = inherit,
            .extended_attributes = ext_attrs,
        };
    }

    fn parseOperation(self: *Parser, ext_attrs: []ExtendedAttribute, static: bool, special: ?SpecialOperation) !Operation {
        const return_type = try self.parseReturnType();

        var name: ?[]const u8 = null;
        // Check for identifier or keyword that can be used as operation name
        if (self.check(.identifier) or self.isKeywordAllowedAsIdentifier()) {
            const name_token = try self.consumeIdentifierOrKeyword("Expected operation name");
            name = name_token.lexeme;
        }

        _ = try self.consume(.lparen, "Expected '('");
        const arguments = try self.parseArgumentList();
        _ = try self.consume(.rparen, "Expected ')'");

        // Legacy: skip raises(Exception) clause
        if (self.match(.raises)) {
            _ = try self.consume(.lparen, "Expected '('");
            // Skip exception types - could be identifier or parenthesized list
            if (self.match(.lparen)) {
                // raises((Exception1, Exception2))
                while (!self.check(.rparen) and !self.check(.eof)) {
                    _ = self.match(.identifier);
                    _ = self.match(.double_colon); // Handle namespace::Exception
                    _ = self.match(.identifier);
                    _ = self.match(.comma);
                }
                _ = try self.consume(.rparen, "Expected ')'");
            } else {
                // raises(Exception) or raises(namespace::Exception)
                _ = try self.consume(.identifier, "Expected exception name");
                if (self.match(.double_colon)) {
                    _ = try self.consume(.identifier, "Expected exception name after '::'");
                }
            }
            _ = try self.consume(.rparen, "Expected ')'");
        }

        _ = try self.consume(.semicolon, "Expected ';'");

        return Operation{
            .name = name,
            .return_type = return_type,
            .arguments = arguments,
            .static = static,
            .special = special,
            .extended_attributes = ext_attrs,
        };
    }

    fn parseConstructor(self: *Parser, ext_attrs: []ExtendedAttribute) !Constructor {
        _ = try self.consume(.lparen, "Expected '('");
        const arguments = try self.parseArgumentList();
        _ = try self.consume(.rparen, "Expected ')'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Constructor{
            .arguments = arguments,
            .extended_attributes = ext_attrs,
        };
    }

    fn parseConst(self: *Parser) !Const {
        const type_val = try self.parseType();
        const name = try self.consumeIdentifierOrKeyword("Expected constant name");
        _ = try self.consume(.equals, "Expected '='");
        const value = try self.parseConstValue();
        _ = try self.consume(.semicolon, "Expected ';'");

        return Const{
            .name = name.lexeme,
            .type = type_val,
            .value = value,
        };
    }

    fn parseSpecialOperation(self: *Parser) ?SpecialOperation {
        if (self.match(.getter)) return .getter;
        if (self.match(.setter)) return .setter;
        if (self.match(.deleter)) return .deleter;
        return null;
    }

    fn parseIterable(self: *Parser) !Iterable {
        _ = try self.consume(.lt, "Expected '<'");

        const first_type = try self.parseType();

        if (self.match(.comma)) {
            const second_type = try self.parseType();
            _ = try self.consume(.gt, "Expected '>'");
            _ = try self.consume(.semicolon, "Expected ';'");

            return Iterable{
                .key_type = first_type,
                .value_type = second_type,
            };
        }

        _ = try self.consume(.gt, "Expected '>'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Iterable{
            .key_type = null,
            .value_type = first_type,
        };
    }

    fn parseAsyncIterable(self: *Parser) !AsyncIterable {
        _ = try self.consume(.lt, "Expected '<'");

        const first_type = try self.parseType();
        var key_type: ?Type = null;
        var value_type: Type = first_type;

        if (self.match(.comma)) {
            const second_type = try self.parseType();
            key_type = first_type;
            value_type = second_type;
        }

        _ = try self.consume(.gt, "Expected '>'");

        var arguments: []Argument = &[_]Argument{};
        if (self.match(.lparen)) {
            arguments = try self.parseArgumentList();
            _ = try self.consume(.rparen, "Expected ')'");
        }

        _ = try self.consume(.semicolon, "Expected ';'");

        return AsyncIterable{
            .key_type = key_type,
            .value_type = value_type,
            .arguments = arguments,
        };
    }

    fn parseMaplike(self: *Parser, readonly: bool) !Maplike {
        _ = try self.consume(.lt, "Expected '<'");
        const key_type = try self.parseType();
        _ = try self.consume(.comma, "Expected ','");
        const value_type = try self.parseType();
        _ = try self.consume(.gt, "Expected '>'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Maplike{
            .key_type = key_type,
            .value_type = value_type,
            .readonly = readonly,
        };
    }

    fn parseSetlike(self: *Parser, readonly: bool) !Setlike {
        _ = try self.consume(.lt, "Expected '<'");
        const value_type = try self.parseType();
        _ = try self.consume(.gt, "Expected '>'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Setlike{
            .value_type = value_type,
            .readonly = readonly,
        };
    }

    fn parseDictionary(self: *Parser, ext_attrs: []ExtendedAttribute, partial: bool) !Definition {
        const name = try self.consume(.identifier, "Expected dictionary name");

        var inherits: ?[]const u8 = null;
        if (self.match(.colon)) {
            const parent = try self.consume(.identifier, "Expected parent interface name");

            // Check for namespace qualifier (e.g., stylesheets::StyleSheet)
            if (self.match(.double_colon)) {
                const qualified_ident = try self.consumeIdentifierOrKeyword("Expected identifier after '::'");

                // Combine namespace::identifier into a single string
                inherits = try std.fmt.allocPrint(self.allocator, "{s}::{s}", .{ parent.lexeme, qualified_ident.lexeme });
            } else {
                // Duplicate the string so it can be freed consistently
                inherits = try std.fmt.allocPrint(self.allocator, "{s}", .{parent.lexeme});
            }
        }

        _ = try self.consume(.lbrace, "Expected '{'");

        var members = infra.List(DictionaryMember).init(self.allocator);
        errdefer {
            for (members.items) |*member| {
                member.deinit();
            }
            members.deinit();
        }

        while (!self.check(.rbrace) and !self.check(.eof)) {
            const member = try self.parseDictionaryMember();
            try members.append( member);
        }

        _ = try self.consume(.rbrace, "Expected '}'");
        // Semicolon is technically required by WebIDL spec, but some files omit it
        _ = self.match(.semicolon);

        return Definition{
            .dictionary = Dictionary{
                .name = name.lexeme,
                .inherits = inherits,
                .members = try members.toOwnedSlice(),
                .extended_attributes = ext_attrs,
                .partial = partial,
            },
        };
    }

    fn parseDictionaryMember(self: *Parser) !DictionaryMember {
        const ext_attrs = try self.parseExtendedAttributeList();

        const required = self.match(.required);
        const type_val = try self.parseType();
        const name = try self.consumeIdentifierOrKeyword("Expected member name");

        var default_value: ?Value = null;
        if (self.match(.equals)) {
            default_value = try self.parseDefaultValue();
        }

        _ = try self.consume(.semicolon, "Expected ';'");

        return DictionaryMember{
            .name = name.lexeme,
            .type = type_val,
            .required = required,
            .default_value = default_value,
            .extended_attributes = ext_attrs,
        };
    }

    fn parseEnum(self: *Parser, ext_attrs: []ExtendedAttribute) !Definition {
        const name = try self.consume(.identifier, "Expected enum name");
        _ = try self.consume(.lbrace, "Expected '{'");

        var values = infra.List([]const u8).init(self.allocator);
        errdefer values.deinit();

        while (!self.check(.rbrace) and !self.check(.eof)) {
            const value = try self.consume(.string_literal, "Expected string literal");
            const unquoted = value.lexeme[1 .. value.lexeme.len - 1];
            try values.append( unquoted);

            if (!self.match(.comma)) {
                break;
            }
        }

        _ = try self.consume(.rbrace, "Expected '}'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Definition{
            .enum_def = Enum{
                .name = name.lexeme,
                .values = try values.toOwnedSlice(),
                .extended_attributes = ext_attrs,
            },
        };
    }

    fn parseTypedef(self: *Parser, ext_attrs: []ExtendedAttribute) !Definition {
        const type_val = try self.parseType();
        const name = try self.consumeIdentifierOrKeyword("Expected typedef name");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Definition{
            .typedef = Typedef{
                .name = name.lexeme,
                .type = type_val,
                .extended_attributes = ext_attrs,
            },
        };
    }

    fn parseCallback(self: *Parser, ext_attrs: []ExtendedAttribute) !Definition {
        const name = try self.consume(.identifier, "Expected callback name");
        _ = try self.consume(.equals, "Expected '='");
        const return_type = try self.parseReturnType();
        _ = try self.consume(.lparen, "Expected '('");
        const arguments = try self.parseArgumentList();
        _ = try self.consume(.rparen, "Expected ')'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Definition{
            .callback = Callback{
                .name = name.lexeme,
                .return_type = return_type,
                .arguments = arguments,
                .extended_attributes = ext_attrs,
            },
        };
    }

    fn parseCallbackInterface(self: *Parser, ext_attrs: []ExtendedAttribute) !Definition {
        const name = try self.consume(.identifier, "Expected callback interface name");
        _ = try self.consume(.lbrace, "Expected '{'");

        var members = infra.List(InterfaceMember).init(self.allocator);
        errdefer {
            for (members.items) |*member| {
                member.deinit();
            }
            members.deinit();
        }

        while (!self.check(.rbrace) and !self.check(.eof)) {
            const member = try self.parseInterfaceMember();
            try members.append( member);
        }

        _ = try self.consume(.rbrace, "Expected '}'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Definition{
            .callback_interface = CallbackInterface{
                .name = name.lexeme,
                .members = try members.toOwnedSlice(),
                .extended_attributes = ext_attrs,
            },
        };
    }

    fn parseNamespace(self: *Parser, ext_attrs: []ExtendedAttribute, partial: bool) !Definition {
        const name = try self.consume(.identifier, "Expected namespace name");
        _ = try self.consume(.lbrace, "Expected '{'");

        var members = infra.List(NamespaceMember).init(self.allocator);
        errdefer {
            for (members.items) |*member| {
                member.deinit();
            }
            members.deinit();
        }

        while (!self.check(.rbrace) and !self.check(.eof)) {
            const member = try self.parseNamespaceMember();
            try members.append( member);
        }

        _ = try self.consume(.rbrace, "Expected '}'");
        _ = try self.consume(.semicolon, "Expected ';'");

        return Definition{
            .namespace = Namespace{
                .name = name.lexeme,
                .members = try members.toOwnedSlice(),
                .extended_attributes = ext_attrs,
                .partial = partial,
            },
        };
    }

    fn parseNamespaceMember(self: *Parser) !NamespaceMember {
        const ext_attrs = try self.parseExtendedAttributeList();

        if (self.match(.readonly) and self.match(.attribute)) {
            return NamespaceMember{ .attribute = try self.parseAttributeRest(ext_attrs, true, false, false, false) };
        }

        if (self.match(.attribute)) {
            return NamespaceMember{ .attribute = try self.parseAttributeRest(ext_attrs, false, false, false, false) };
        }

        if (self.match(.const_kw)) {
            return NamespaceMember{ .const_member = try self.parseConst() };
        }

        return NamespaceMember{ .operation = try self.parseOperation(ext_attrs, false, null) };
    }

    fn parseExtendedAttributeList(self: *Parser) ![]ExtendedAttribute {
        if (!self.match(.lbracket)) {
            return &[_]ExtendedAttribute{};
        }

        var attrs = infra.List(ExtendedAttribute).init(self.allocator);
        errdefer {
            for (attrs.items) |*attr| {
                attr.deinit();
            }
            attrs.deinit();
        }

        while (!self.check(.rbracket) and !self.check(.eof)) {
            const attr = try self.parseExtendedAttribute();
            try attrs.append( attr);

            if (!self.match(.comma)) {
                break;
            }
        }

        _ = try self.consume(.rbracket, "Expected ']'");

        return try attrs.toOwnedSlice();
    }

    fn parseExtendedAttribute(self: *Parser) !ExtendedAttribute {
        const name = try self.consume(.identifier, "Expected extended attribute name");

        if (self.match(.equals)) {
            if (self.match(.lparen)) {
                // Lookahead to determine if this is an identifier list or argument list
                // Save state
                const checkpoint_current = self.current;
                const checkpoint_previous = self.previous;
                const checkpoint_lexer_pos = self.lexer.current;
                const checkpoint_lexer_line = self.lexer.line;
                const checkpoint_lexer_column = self.lexer.column;

                var is_identifier_list = false;
                if (self.check(.identifier)) {
                    self.advance();
                    // If followed by comma or rparen, it's an identifier list
                    // If followed by identifier or other type tokens, it's an argument list
                    is_identifier_list = self.check(.comma) or self.check(.rparen);
                } else if (self.check(.integer_literal) or self.check(.float_literal) or self.check(.string_literal)) {
                    // Literal values followed by comma means it's a value list like ReflectRange=(0, 8)
                    self.advance();
                    is_identifier_list = self.check(.comma) or self.check(.rparen);
                }

                // Restore state
                self.current = checkpoint_current;
                self.previous = checkpoint_previous;
                self.lexer.current = checkpoint_lexer_pos;
                self.lexer.line = checkpoint_lexer_line;
                self.lexer.column = checkpoint_lexer_column;

                if (is_identifier_list) {
                    // Parse as identifier list
                    var idents = infra.List([]const u8).init(self.allocator);
                    errdefer idents.deinit();

                    while (!self.check(.rparen) and !self.check(.eof)) {
                        // Accept identifiers, integers, floats, or strings
                        const value = if (self.check(.identifier))
                            try self.consume(.identifier, "Expected value")
                        else if (self.check(.integer_literal))
                            try self.consume(.integer_literal, "Expected value")
                        else if (self.check(.float_literal))
                            try self.consume(.float_literal, "Expected value")
                        else if (self.check(.string_literal))
                            try self.consume(.string_literal, "Expected value")
                        else
                            return self.fail("Expected identifier or literal value");

                        try idents.append( value.lexeme);

                        if (!self.match(.comma)) {
                            break;
                        }
                    }

                    _ = try self.consume(.rparen, "Expected ')'");

                    return ExtendedAttribute{
                        .name = name.lexeme,
                        .value = ExtendedAttrValue{ .identifier_list = try idents.toOwnedSlice() },
                    };
                } else {
                    // Parse as argument list
                    const args = try self.parseArgumentList();
                    _ = try self.consume(.rparen, "Expected ')'");

                    if (self.check(.identifier)) {
                        const ident = try self.consume(.identifier, "Expected identifier");
                        return ExtendedAttribute{
                            .name = name.lexeme,
                            .value = ExtendedAttrValue{
                                .named_arg_list = NamedArgList{
                                    .name = ident.lexeme,
                                    .args = args,
                                },
                            },
                        };
                    }

                    return ExtendedAttribute{
                        .name = name.lexeme,
                        .value = ExtendedAttrValue{ .argument_list = args },
                    };
                }
            } else if (self.check(.asterisk)) {
                // Handle Exposed=* case
                const asterisk = try self.consume(.asterisk, "Expected '*'");
                return ExtendedAttribute{
                    .name = name.lexeme,
                    .value = ExtendedAttrValue{ .identifier = asterisk.lexeme },
                };
            } else if (self.check(.string_literal)) {
                // Handle Reflect="aria-activedescendant" case
                const value = try self.consume(.string_literal, "Expected string literal");
                return ExtendedAttribute{
                    .name = name.lexeme,
                    .value = ExtendedAttrValue{ .identifier = value.lexeme },
                };
            } else if (self.check(.integer_literal)) {
                // Handle ReflectDefault=20 case
                const value = try self.consume(.integer_literal, "Expected integer literal");
                return ExtendedAttribute{
                    .name = name.lexeme,
                    .value = ExtendedAttrValue{ .identifier = value.lexeme },
                };
            } else if (self.check(.float_literal)) {
                // Handle ReflectDefault=1.0 case
                const value = try self.consume(.float_literal, "Expected float literal");
                return ExtendedAttribute{
                    .name = name.lexeme,
                    .value = ExtendedAttrValue{ .identifier = value.lexeme },
                };
            } else if (self.check(.identifier)) {
                const value = try self.consume(.identifier, "Expected identifier");

                // Check for LegacyFactoryFunction=Image(...) pattern
                if (self.match(.lparen)) {
                    const args = try self.parseArgumentList();
                    _ = try self.consume(.rparen, "Expected ')'");

                    return ExtendedAttribute{
                        .name = name.lexeme,
                        .value = ExtendedAttrValue{
                            .named_arg_list = NamedArgList{
                                .name = value.lexeme,
                                .args = args,
                            },
                        },
                    };
                }

                return ExtendedAttribute{
                    .name = name.lexeme,
                    .value = ExtendedAttrValue{ .identifier = value.lexeme },
                };
            } else if (self.match(.lparen)) {
                var idents = infra.List([]const u8).init(self.allocator);
                errdefer idents.deinit();

                while (!self.check(.rparen) and !self.check(.eof)) {
                    const ident = try self.consume(.identifier, "Expected identifier");
                    try idents.append( ident.lexeme);

                    if (!self.match(.comma)) {
                        break;
                    }
                }

                _ = try self.consume(.rparen, "Expected ')'");

                return ExtendedAttribute{
                    .name = name.lexeme,
                    .value = ExtendedAttrValue{ .identifier_list = try idents.toOwnedSlice() },
                };
            }
        } else if (self.match(.lparen)) {
            const args = try self.parseArgumentList();
            _ = try self.consume(.rparen, "Expected ')'");

            return ExtendedAttribute{
                .name = name.lexeme,
                .value = ExtendedAttrValue{ .argument_list = args },
            };
        }

        return ExtendedAttribute{
            .name = name.lexeme,
            .value = null,
        };
    }

    fn parseType(self: *Parser) ParseError!Type {
        return try self.parseUnionType();
    }

    fn parseUnionType(self: *Parser) ParseError!Type {
        if (self.match(.lparen)) {
            var types = infra.List(Type).init(self.allocator);
            errdefer {
                for (types.items) |*t| {
                    t.deinit();
                }
                types.deinit();
            }

            while (!self.check(.rparen) and !self.check(.eof)) {
                const type_val = try self.parseSingleType();
                try types.append( type_val);

                if (self.match(.or_kw)) {
                    continue;
                }
                break;
            }

            _ = try self.consume(.rparen, "Expected ')'");

            const nullable = self.match(.question);

            if (types.items.len == 1) {
                const single = types.items[0];
                types.deinit();
                if (nullable) {
                    const nullable_type = try self.allocator.create(Type);
                    nullable_type.* = single;
                    return Type{ .nullable = nullable_type };
                }
                return single;
            }

            const union_type = Type{ .union_type = try types.toOwnedSlice() };
            if (nullable) {
                const nullable_type = try self.allocator.create(Type);
                nullable_type.* = union_type;
                return Type{ .nullable = nullable_type };
            }

            return union_type;
        }

        return try self.parseSingleType();
    }

    fn parseSingleType(self: *Parser) ParseError!Type {
        // Extended attributes can appear before types (e.g., [EnforceRange] unsigned long)
        // We parse them but don't store them in the Type struct for now
        const ext_attrs = try self.parseExtendedAttributeList();
        defer {
            for (ext_attrs) |*attr| {
                var mut_attr = attr.*;
                mut_attr.deinit();
            }
            self.allocator.free(ext_attrs);
        }

        const base_type = try self.parseNonNullableType();

        if (self.match(.question)) {
            const nullable_type = try self.allocator.create(Type);
            nullable_type.* = base_type;
            return Type{ .nullable = nullable_type };
        }

        return base_type;
    }

    fn parseNonNullableType(self: *Parser) ParseError!Type {
        if (self.match(.any)) return Type{ .any = {} };
        if (self.match(.undefined)) return Type{ .undefined = {} };
        if (self.match(.boolean)) return Type{ .boolean = {} };
        if (self.match(.byte)) return Type{ .byte = {} };
        if (self.match(.octet)) return Type{ .octet = {} };
        if (self.match(.bigint)) return Type{ .bigint = {} };
        if (self.match(.dom_string)) return Type{ .dom_string = {} };
        if (self.match(.byte_string)) return Type{ .byte_string = {} };
        if (self.match(.usv_string)) return Type{ .usv_string = {} };
        if (self.match(.object)) return Type{ .object = {} };
        if (self.match(.symbol)) return Type{ .symbol = {} };

        if (self.match(.unrestricted)) {
            if (self.match(.float)) {
                return Type{ .unrestricted_float = {} };
            } else if (self.match(.double)) {
                return Type{ .unrestricted_double = {} };
            }
            return self.fail("Expected 'float' or 'double' after 'unrestricted'");
        }

        if (self.match(.float)) return Type{ .float = {} };
        if (self.match(.double)) return Type{ .double = {} };

        if (self.match(.unsigned)) {
            if (self.match(.short)) {
                return Type{ .unsigned_short = {} };
            } else if (self.match(.long)) {
                if (self.match(.long)) {
                    return Type{ .unsigned_long_long = {} };
                }
                return Type{ .unsigned_long = {} };
            }
            return self.fail("Expected 'short' or 'long' after 'unsigned'");
        }

        if (self.match(.short)) return Type{ .short = {} };

        if (self.match(.long)) {
            if (self.match(.long)) {
                return Type{ .long_long = {} };
            }
            return Type{ .long = {} };
        }

        if (self.match(.sequence)) {
            _ = try self.consume(.lt, "Expected '<'");
            var inner = try self.parseType();
            errdefer inner.deinit();
            _ = try self.consume(.gt, "Expected '>'");

            const seq_type = try self.allocator.create(Type);
            seq_type.* = inner;
            return Type{ .sequence = seq_type };
        }

        if (self.match(.frozen_array)) {
            _ = try self.consume(.lt, "Expected '<'");
            var inner = try self.parseType();
            errdefer inner.deinit();
            _ = try self.consume(.gt, "Expected '>'");

            const frozen_type = try self.allocator.create(Type);
            frozen_type.* = inner;
            return Type{ .frozen_array = frozen_type };
        }

        if (self.match(.observable_array)) {
            _ = try self.consume(.lt, "Expected '<'");
            var inner = try self.parseType();
            errdefer inner.deinit();
            _ = try self.consume(.gt, "Expected '>'");

            const obs_type = try self.allocator.create(Type);
            obs_type.* = inner;
            return Type{ .observable_array = obs_type };
        }

        if (self.match(.record)) {
            _ = try self.consume(.lt, "Expected '<'");
            var key_type = try self.parseType();
            errdefer key_type.deinit();
            _ = try self.consume(.comma, "Expected ','");
            var value_type = try self.parseType();
            errdefer value_type.deinit();
            _ = try self.consume(.gt, "Expected '>'");

            const key_ptr = try self.allocator.create(Type);
            key_ptr.* = key_type;
            const value_ptr = try self.allocator.create(Type);
            value_ptr.* = value_type;

            return Type{
                .record = .{
                    .key = key_ptr,
                    .value = value_ptr,
                },
            };
        }

        if (self.match(.promise)) {
            _ = try self.consume(.lt, "Expected '<'");
            var inner = try self.parseType();
            errdefer inner.deinit();
            _ = try self.consume(.gt, "Expected '>'");

            const promise_type = try self.allocator.create(Type);
            promise_type.* = inner;
            return Type{ .promise = promise_type };
        }

        if (self.check(.identifier)) {
            const ident = try self.consume(.identifier, "Expected identifier");

            // Check for namespace qualifier (e.g., stylesheets::MediaList, dom::DOMString)
            if (self.match(.double_colon)) {
                const qualified_ident = try self.consumeIdentifierOrKeyword("Expected identifier after '::'");

                // Combine namespace::identifier into a single string
                const combined = try std.fmt.allocPrint(self.allocator, "{s}::{s}", .{ ident.lexeme, qualified_ident.lexeme });

                return Type{ .identifier = combined };
            }

            // Duplicate the string so it can be freed consistently
            const duplicated = try std.fmt.allocPrint(self.allocator, "{s}", .{ident.lexeme});
            return Type{ .identifier = duplicated };
        }

        return self.fail("Expected type");
    }

    fn parseReturnType(self: *Parser) ParseError!Type {
        if (self.match(.undefined)) {
            return Type{ .undefined = {} };
        }
        return try self.parseType();
    }

    fn parseArgumentList(self: *Parser) ![]Argument {
        var args = infra.List(Argument).init(self.allocator);
        errdefer {
            for (args.items) |*arg| {
                arg.deinit();
            }
            args.deinit();
        }

        while (!self.check(.rparen) and !self.check(.eof)) {
            const arg = try self.parseArgument();
            try args.append( arg);

            if (!self.match(.comma)) {
                break;
            }
        }

        return try args.toOwnedSlice();
    }

    fn parseArgument(self: *Parser) ParseError!Argument {
        const ext_attrs = try self.parseExtendedAttributeList();

        const optional = self.match(.optional);

        // Legacy: skip 'in' keyword (old-style parameter attribute)
        _ = self.match(.in);

        const type_val = try self.parseType();

        const variadic = self.match(.ellipsis);

        const name = try self.consumeIdentifierOrKeyword("Expected argument name");

        var default_value: ?Value = null;
        if (self.match(.equals)) {
            default_value = try self.parseDefaultValue();
        }

        return Argument{
            .name = name.lexeme,
            .type = type_val,
            .optional = optional,
            .variadic = variadic,
            .default_value = default_value,
            .extended_attributes = ext_attrs,
        };
    }

    fn parseDefaultValue(self: *Parser) !Value {
        if (self.match(.null_kw)) return Value{ .null_value = {} };
        if (self.match(.true_kw)) return Value{ .boolean = true };
        if (self.match(.false_kw)) return Value{ .boolean = false };
        if (self.match(.infinity_kw)) return Value{ .infinity = true };
        if (self.match(.negative_infinity_kw)) return Value{ .negative_infinity = true };
        if (self.match(.nan_kw)) return Value{ .nan = {} };

        if (self.check(.string_literal)) {
            const str = try self.consume(.string_literal, "Expected string");
            const unquoted = str.lexeme[1 .. str.lexeme.len - 1];
            return Value{ .string = unquoted };
        }

        if (self.check(.integer_literal)) {
            const int = try self.consume(.integer_literal, "Expected integer");
            // Use base 0 to auto-detect (supports 0x for hex)
            const parsed = try std.fmt.parseInt(i64, int.lexeme, 0);
            return Value{ .integer = .{ .value = parsed, .lexeme = int.lexeme } };
        }

        if (self.check(.float_literal)) {
            const flt = try self.consume(.float_literal, "Expected float");
            const parsed = try std.fmt.parseFloat(f64, flt.lexeme);
            return Value{ .float = .{ .value = parsed, .lexeme = flt.lexeme } };
        }

        if (self.match(.lbracket)) {
            _ = try self.consume(.rbracket, "Expected ']'");
            return Value{ .empty_sequence = {} };
        }

        if (self.match(.lbrace)) {
            _ = try self.consume(.rbrace, "Expected '}'");
            return Value{ .empty_dictionary = {} };
        }

        if (self.check(.minus)) {
            _ = try self.consume(.minus, "Expected '-'");
            if (self.check(.integer_literal)) {
                const int = try self.consume(.integer_literal, "Expected integer");
                // Use base 0 to auto-detect (supports 0x for hex)
                const parsed = try std.fmt.parseInt(i64, int.lexeme, 0);
                // For negative values, store the lexeme with minus prefix
                const neg_lexeme = try std.fmt.allocPrint(self.allocator, "-{s}", .{int.lexeme});
                return Value{ .integer = .{ .value = -parsed, .lexeme = neg_lexeme, .lexeme_allocated = true } };
            } else if (self.check(.float_literal)) {
                const flt = try self.consume(.float_literal, "Expected float");
                const parsed = try std.fmt.parseFloat(f64, flt.lexeme);
                // For negative values, store the lexeme with minus prefix
                const neg_lexeme = try std.fmt.allocPrint(self.allocator, "-{s}", .{flt.lexeme});
                return Value{ .float = .{ .value = -parsed, .lexeme = neg_lexeme, .lexeme_allocated = true } };
            }
        }

        return self.fail("Expected default value");
    }

    fn parseConstValue(self: *Parser) !Value {
        return try self.parseDefaultValue();
    }

    fn match(self: *Parser, token_type: TokenType) bool {
        if (self.check(token_type)) {
            self.advance();
            return true;
        }
        return false;
    }

    fn check(self: *Parser, token_type: TokenType) bool {
        return self.current.type == token_type;
    }

    fn advance(self: *Parser) void {
        self.previous = self.current;
        self.current = self.lexer.nextToken() catch {
            return;
        };
    }

    fn consume(self: *Parser, token_type: TokenType, message: []const u8) !Token {
        if (self.check(token_type)) {
            const token = self.current;
            self.advance();
            return token;
        }

        return self.fail(message);
    }

    fn isKeywordAllowedAsIdentifier(self: *Parser) bool {
        return switch (self.current.type) {
            .callback,
            .attribute,
            .readonly,
            .const_kw,
            .getter,
            .setter,
            .deleter,
            .stringifier,
            .inherit,
            .static,
            .iterable,
            .maplike,
            .setlike,
            .namespace,
            .partial,
            .dictionary,
            .@"enum",
            .typedef,
            .interface,
            .mixin,
            .required,
            .optional,
            .async,
            // Type keywords (for legacy namespace qualifiers like dom::DOMString)
            .dom_string,
            .byte_string,
            .usv_string,
            .any,
            .boolean,
            .byte,
            .octet,
            .short,
            .unsigned,
            .long,
            .float,
            .double,
            .unrestricted,
            .bigint,
            .object,
            .symbol,
            .undefined,
            // Legacy keywords
            .in,
            .raises,
            .pragma,
            .module,
            // Keywords that can be used as identifiers
            .includes,
            .constructor,
            => true,
            else => false,
        };
    }

    fn consumeIdentifierOrKeyword(self: *Parser, message: []const u8) !Token {
        // In WebIDL, many keywords can be used as identifiers in certain contexts
        // (like argument names, attribute names, etc.)
        if (self.check(.identifier)) {
            return try self.consume(.identifier, message);
        }

        // Allow keywords to be used as identifiers
        if (self.isKeywordAllowedAsIdentifier()) {
            const token = self.current;
            self.advance();
            return token;
        }

        return self.fail(message);
    }

    fn synchronize(self: *Parser) void {
        self.panic_mode = false;

        while (self.current.type != .eof) {
            // If previous was semicolon and current is a definition keyword, we're synchronized
            if (self.previous.type == .semicolon) {
                switch (self.current.type) {
                    .interface, .dictionary, .@"enum", .callback, .typedef, .namespace, .partial => return,
                    else => {
                        // Previous was semicolon but current is not a definition keyword
                        // This might be an includes statement or invalid syntax - advance past it
                        self.advance();
                        continue;
                    },
                }
            }

            switch (self.current.type) {
                .interface, .dictionary, .@"enum", .callback, .typedef, .namespace, .partial => return,
                else => {},
            }

            self.advance();
        }
    }

    fn fail(self: *Parser, message: []const u8) ParseError {
        if (self.panic_mode) return ParseError.UnexpectedToken;

        self.panic_mode = true;
        self.had_error = true;

        reportErrorSimple(self.filename, self.current, message);

        return ParseError.UnexpectedToken;
    }
};

test "memory leak check - namespace qualified type" {
    const allocator = std.testing.allocator;
    const source = "typedef dom::DOMString MyString;";

    var lexer = Lexer.init(allocator, source);
    var parser = try Parser.init(allocator, &lexer, "test.idl");

    var parsed_ast = try parser.parse();
    defer parsed_ast.deinit();

    try std.testing.expect(parsed_ast.definitions.len == 1);
}
