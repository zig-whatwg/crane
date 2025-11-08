const std = @import("std");
const Allocator = std.mem.Allocator;

pub const AST = struct {
    definitions: []Definition,
    allocator: Allocator,

    pub fn deinit(self: *AST) void {
        for (self.definitions) |*def| {
            def.deinit(self.allocator);
        }
        self.allocator.free(self.definitions);
    }
};

pub const Definition = union(enum) {
    interface: Interface,
    interface_mixin: InterfaceMixin,
    dictionary: Dictionary,
    enum_def: Enum,
    typedef: Typedef,
    callback: Callback,
    callback_interface: CallbackInterface,
    includes: IncludesStatement,
    namespace: Namespace,

    pub fn deinit(self: *Definition, allocator: Allocator) void {
        switch (self.*) {
            .interface => |*i| i.deinit(allocator),
            .interface_mixin => |*m| m.deinit(allocator),
            .dictionary => |*d| d.deinit(allocator),
            .enum_def => |*e| e.deinit(allocator),
            .typedef => |*t| t.deinit(allocator),
            .callback => |*c| c.deinit(allocator),
            .callback_interface => |*ci| ci.deinit(allocator),
            .includes => {},
            .namespace => |*n| n.deinit(allocator),
        }
    }
};

pub const Interface = struct {
    name: []const u8,
    inherits: ?[]const u8,
    members: []InterfaceMember,
    extended_attributes: []ExtendedAttribute,
    partial: bool,

    pub fn deinit(self: *Interface, allocator: Allocator) void {
        if (self.inherits) |inherits_str| {
            allocator.free(inherits_str);
        }
        for (self.members) |*member| {
            member.deinit(allocator);
        }
        allocator.free(self.members);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const InterfaceMixin = struct {
    name: []const u8,
    members: []InterfaceMember,
    extended_attributes: []ExtendedAttribute,
    partial: bool,

    pub fn deinit(self: *InterfaceMixin, allocator: Allocator) void {
        for (self.members) |*member| {
            member.deinit(allocator);
        }
        allocator.free(self.members);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const InterfaceMember = union(enum) {
    attribute: Attribute,
    operation: Operation,
    const_member: Const,
    constructor: Constructor,
    stringifier: Stringifier,
    iterable: Iterable,
    maplike: Maplike,
    setlike: Setlike,
    async_iterable: AsyncIterable,

    pub fn deinit(self: *InterfaceMember, allocator: Allocator) void {
        switch (self.*) {
            .attribute => |*a| a.deinit(allocator),
            .operation => |*o| o.deinit(allocator),
            .const_member => |*c| c.deinit(allocator),
            .constructor => |*c| c.deinit(allocator),
            .stringifier => |*s| s.deinit(allocator),
            .iterable => |*i| i.deinit(allocator),
            .maplike => |*m| m.deinit(allocator),
            .setlike => |*s| s.deinit(allocator),
            .async_iterable => |*ai| ai.deinit(allocator),
        }
    }
};

pub const Attribute = struct {
    name: []const u8,
    type: Type,
    readonly: bool,
    static: bool,
    stringifier: bool,
    inherit: bool,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *Attribute, allocator: Allocator) void {
        self.type.deinit(allocator);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const Operation = struct {
    name: ?[]const u8,
    return_type: Type,
    arguments: []Argument,
    static: bool,
    special: ?SpecialOperation,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *Operation, allocator: Allocator) void {
        self.return_type.deinit(allocator);
        for (self.arguments) |*arg| {
            arg.deinit(allocator);
        }
        allocator.free(self.arguments);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const SpecialOperation = enum {
    getter,
    setter,
    deleter,
    stringifier,
};

pub const Argument = struct {
    name: []const u8,
    type: Type,
    optional: bool,
    variadic: bool,
    default_value: ?Value,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *Argument, allocator: Allocator) void {
        self.type.deinit(allocator);
        if (self.default_value) |*val| {
            val.deinit(allocator);
        }
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const Type = union(enum) {
    any: void,
    undefined: void,
    boolean: void,
    byte: void,
    octet: void,
    short: void,
    unsigned_short: void,
    long: void,
    unsigned_long: void,
    long_long: void,
    unsigned_long_long: void,
    float: void,
    unrestricted_float: void,
    double: void,
    unrestricted_double: void,
    bigint: void,
    dom_string: void,
    byte_string: void,
    usv_string: void,
    object: void,
    symbol: void,
    identifier: []const u8,
    sequence: *Type,
    frozen_array: *Type,
    observable_array: *Type,
    record: RecordType,
    promise: *Type,
    nullable: *Type,
    union_type: []Type,

    pub fn deinit(self: *Type, allocator: Allocator) void {
        switch (self.*) {
            .identifier => |id| {
                allocator.free(id);
            },
            .sequence, .frozen_array, .observable_array, .promise, .nullable => |inner| {
                inner.deinit(allocator);
                allocator.destroy(inner);
            },
            .record => |*rec| {
                rec.key.deinit(allocator);
                allocator.destroy(rec.key);
                rec.value.deinit(allocator);
                allocator.destroy(rec.value);
            },
            .union_type => |types| {
                for (types) |*t| {
                    t.deinit(allocator);
                }
                allocator.free(types);
            },
            else => {},
        }
    }
};

pub const RecordType = struct {
    key: *Type,
    value: *Type,
};

pub const Constructor = struct {
    arguments: []Argument,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *Constructor, allocator: Allocator) void {
        for (self.arguments) |*arg| {
            arg.deinit(allocator);
        }
        allocator.free(self.arguments);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const Stringifier = union(enum) {
    attribute: Attribute,
    operation: Operation,
    keyword: void,

    pub fn deinit(self: *Stringifier, allocator: Allocator) void {
        switch (self.*) {
            .attribute => |*a| a.deinit(allocator),
            .operation => |*o| o.deinit(allocator),
            .keyword => {},
        }
    }
};

pub const Iterable = struct {
    key_type: ?Type,
    value_type: Type,

    pub fn deinit(self: *Iterable, allocator: Allocator) void {
        if (self.key_type) |*kt| {
            kt.deinit(allocator);
        }
        self.value_type.deinit(allocator);
    }
};

pub const AsyncIterable = struct {
    key_type: ?Type,
    value_type: Type,
    arguments: []Argument,

    pub fn deinit(self: *AsyncIterable, allocator: Allocator) void {
        if (self.key_type) |*kt| {
            kt.deinit(allocator);
        }
        self.value_type.deinit(allocator);
        for (self.arguments) |*arg| {
            arg.deinit(allocator);
        }
        allocator.free(self.arguments);
    }
};

pub const Maplike = struct {
    key_type: Type,
    value_type: Type,
    readonly: bool,

    pub fn deinit(self: *Maplike, allocator: Allocator) void {
        self.key_type.deinit(allocator);
        self.value_type.deinit(allocator);
    }
};

pub const Setlike = struct {
    value_type: Type,
    readonly: bool,

    pub fn deinit(self: *Setlike, allocator: Allocator) void {
        self.value_type.deinit(allocator);
    }
};

pub const Dictionary = struct {
    name: []const u8,
    inherits: ?[]const u8,
    members: []DictionaryMember,
    extended_attributes: []ExtendedAttribute,
    partial: bool,

    pub fn deinit(self: *Dictionary, allocator: Allocator) void {
        if (self.inherits) |inherits_str| {
            allocator.free(inherits_str);
        }
        for (self.members) |*member| {
            member.deinit(allocator);
        }
        allocator.free(self.members);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const DictionaryMember = struct {
    name: []const u8,
    type: Type,
    required: bool,
    default_value: ?Value,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *DictionaryMember, allocator: Allocator) void {
        self.type.deinit(allocator);
        if (self.default_value) |*val| {
            val.deinit(allocator);
        }
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const Enum = struct {
    name: []const u8,
    values: [][]const u8,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *Enum, allocator: Allocator) void {
        allocator.free(self.values);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const Typedef = struct {
    name: []const u8,
    type: Type,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *Typedef, allocator: Allocator) void {
        self.type.deinit(allocator);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const Callback = struct {
    name: []const u8,
    return_type: Type,
    arguments: []Argument,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *Callback, allocator: Allocator) void {
        self.return_type.deinit(allocator);
        for (self.arguments) |*arg| {
            arg.deinit(allocator);
        }
        allocator.free(self.arguments);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const CallbackInterface = struct {
    name: []const u8,
    members: []InterfaceMember,
    extended_attributes: []ExtendedAttribute,

    pub fn deinit(self: *CallbackInterface, allocator: Allocator) void {
        for (self.members) |*member| {
            member.deinit(allocator);
        }
        allocator.free(self.members);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const ExtendedAttribute = struct {
    name: []const u8,
    value: ?ExtendedAttrValue,

    pub fn deinit(self: *ExtendedAttribute, allocator: Allocator) void {
        if (self.value) |*val| {
            val.deinit(allocator);
        }
    }
};

pub const ExtendedAttrValue = union(enum) {
    identifier: []const u8,
    identifier_list: [][]const u8,
    argument_list: []Argument,
    named_arg_list: NamedArgList,

    pub fn deinit(self: *ExtendedAttrValue, allocator: Allocator) void {
        switch (self.*) {
            .identifier_list => |list| {
                allocator.free(list);
            },
            .argument_list => |args| {
                for (args) |*arg| {
                    arg.deinit(allocator);
                }
                allocator.free(args);
            },
            .named_arg_list => |*nal| {
                for (nal.args) |*arg| {
                    arg.deinit(allocator);
                }
                allocator.free(nal.args);
            },
            else => {},
        }
    }
};

pub const NamedArgList = struct {
    name: []const u8,
    args: []Argument,
};

pub const IncludesStatement = struct {
    interface: []const u8,
    mixin: []const u8,
};

pub const Namespace = struct {
    name: []const u8,
    members: []NamespaceMember,
    extended_attributes: []ExtendedAttribute,
    partial: bool,

    pub fn deinit(self: *Namespace, allocator: Allocator) void {
        for (self.members) |*member| {
            member.deinit(allocator);
        }
        allocator.free(self.members);
        for (self.extended_attributes) |*attr| {
            attr.deinit(allocator);
        }
        allocator.free(self.extended_attributes);
    }
};

pub const NamespaceMember = union(enum) {
    attribute: Attribute,
    operation: Operation,
    const_member: Const,

    pub fn deinit(self: *NamespaceMember, allocator: Allocator) void {
        switch (self.*) {
            .attribute => |*a| a.deinit(allocator),
            .operation => |*o| o.deinit(allocator),
            .const_member => |*c| c.deinit(allocator),
        }
    }
};

pub const Const = struct {
    name: []const u8,
    type: Type,
    value: Value,

    pub fn deinit(self: *Const, allocator: Allocator) void {
        self.type.deinit(allocator);
        self.value.deinit(allocator);
    }
};

pub const IntegerValue = struct {
    value: i64,
    lexeme: []const u8,
    lexeme_allocated: bool = false,
};

pub const FloatValue = struct {
    value: f64,
    lexeme: []const u8,
    lexeme_allocated: bool = false,
};

pub const Value = union(enum) {
    null_value: void,
    boolean: bool,
    integer: IntegerValue,
    float: FloatValue,
    string: []const u8,
    empty_sequence: void,
    empty_dictionary: void,
    infinity: bool,
    negative_infinity: bool,
    nan: void,

    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.*) {
            .integer => |iv| {
                if (iv.lexeme_allocated) {
                    allocator.free(iv.lexeme);
                }
            },
            .float => |fv| {
                if (fv.lexeme_allocated) {
                    allocator.free(fv.lexeme);
                }
            },
            else => {},
        }
    }
};
