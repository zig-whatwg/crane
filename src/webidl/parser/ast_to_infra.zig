const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const ast = @import("ast.zig");

const AST = ast.AST;
const Definition = ast.Definition;
const Interface = ast.Interface;
const InterfaceMixin = ast.InterfaceMixin;
const InterfaceMember = ast.InterfaceMember;
const Attribute = ast.Attribute;
const Operation = ast.Operation;
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
const Namespace = ast.Namespace;
const NamespaceMember = ast.NamespaceMember;
const Const = ast.Const;
const Value = ast.Value;
const IncludesStatement = ast.IncludesStatement;

pub const ConversionError = Allocator.Error || error{
    InvalidUtf8,
    InvalidUtf16,
    InvalidCodePoint,
};

pub fn astToInfraValue(allocator: Allocator, ast_val: AST) !*infra.InfraValue {
    const root = try allocator.create(infra.InfraValue);
    errdefer allocator.destroy(root);

    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    errdefer allocator.destroy(map);
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    const key_definitions = try infra.string.utf8ToUtf16(allocator, "definitions");
    errdefer allocator.free(key_definitions);

    const definitions_list = try definitionsToInfra(allocator, ast_val.definitions);
    errdefer {
        definitions_list.deinit(allocator);
        allocator.destroy(definitions_list);
    }

    try map.set(key_definitions, definitions_list);

    root.* = .{ .map = map };
    return root;
}

fn definitionsToInfra(allocator: Allocator, defs: []Definition) !*infra.InfraValue {
    const list = try allocator.create(infra.List(*infra.InfraValue));
    errdefer allocator.destroy(list);
    list.* = infra.List(*infra.InfraValue).init(allocator);

    for (defs) |def| {
        const def_value = try definitionToInfra(allocator, def);
        try list.append(def_value);
    }

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .list = list };
    return result;
}

fn definitionToInfra(allocator: Allocator, def: Definition) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    switch (def) {
        .interface => |iface| {
            const key = try infra.string.utf8ToUtf16(allocator, "interface");
            const value = try interfaceToInfra(allocator, iface);
            try map.set(key, value);
        },
        .interface_mixin => |mixin| {
            const key = try infra.string.utf8ToUtf16(allocator, "interface_mixin");
            const value = try interfaceMixinToInfra(allocator, mixin);
            try map.set(key, value);
        },
        .dictionary => |dict| {
            const key = try infra.string.utf8ToUtf16(allocator, "dictionary");
            const value = try dictionaryToInfra(allocator, dict);
            try map.set(key, value);
        },
        .enum_def => |enm| {
            const key = try infra.string.utf8ToUtf16(allocator, "enum");
            const value = try enumToInfra(allocator, enm);
            try map.set(key, value);
        },
        .typedef => |td| {
            const key = try infra.string.utf8ToUtf16(allocator, "typedef");
            const value = try typedefToInfra(allocator, td);
            try map.set(key, value);
        },
        .callback => |cb| {
            const key = try infra.string.utf8ToUtf16(allocator, "callback");
            const value = try callbackToInfra(allocator, cb);
            try map.set(key, value);
        },
        .callback_interface => |cbi| {
            const key = try infra.string.utf8ToUtf16(allocator, "callback_interface");
            const value = try callbackInterfaceToInfra(allocator, cbi);
            try map.set(key, value);
        },
        .includes => |inc| {
            const key = try infra.string.utf8ToUtf16(allocator, "includes");
            const value = try includesToInfra(allocator, inc);
            try map.set(key, value);
        },
        .namespace => |ns| {
            const key = try infra.string.utf8ToUtf16(allocator, "namespace");
            const value = try namespaceToInfra(allocator, ns);
            try map.set(key, value);
        },
    }

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn interfaceToInfra(allocator: Allocator, iface: Interface) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, iface.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "inherits"), try nullableStringToInfra(allocator, iface.inherits));
    try map.set(try infra.string.utf8ToUtf16(allocator, "partial"), try boolToInfra(allocator, iface.partial));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, iface.extended_attributes));
    try map.set(try infra.string.utf8ToUtf16(allocator, "members"), try interfaceMembersToInfra(allocator, iface.members));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn interfaceMixinToInfra(allocator: Allocator, mixin: InterfaceMixin) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, mixin.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "partial"), try boolToInfra(allocator, mixin.partial));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, mixin.extended_attributes));
    try map.set(try infra.string.utf8ToUtf16(allocator, "members"), try interfaceMembersToInfra(allocator, mixin.members));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn interfaceMembersToInfra(allocator: Allocator, members: []InterfaceMember) !*infra.InfraValue {
    const list = try allocator.create(infra.List(*infra.InfraValue));
    list.* = infra.List(*infra.InfraValue).init(allocator);

    for (members) |member| {
        const member_map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
        member_map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

        switch (member) {
            .attribute => |attr| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "attribute"), try attributeToInfra(allocator, attr));
            },
            .operation => |op| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "operation"), try operationToInfra(allocator, op));
            },
            .const_member => |c| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "const"), try constToInfra(allocator, c));
            },
            .constructor => |ctor| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "constructor"), try constructorToInfra(allocator, ctor));
            },
            .stringifier => |s| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "stringifier"), try stringifierToInfra(allocator, s));
            },
            .iterable => |it| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "iterable"), try iterableToInfra(allocator, it));
            },
            .maplike => |m| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "maplike"), try maplikeToInfra(allocator, m));
            },
            .setlike => |s| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "setlike"), try setlikeToInfra(allocator, s));
            },
            .async_iterable => |ai| {
                try member_map.set(try infra.string.utf8ToUtf16(allocator, "async_iterable"), try asyncIterableToInfra(allocator, ai));
            },
        }

        const member_value = try allocator.create(infra.InfraValue);
        member_value.* = .{ .map = member_map };
        try list.append(member_value);
    }

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .list = list };
    return result;
}

fn attributeToInfra(allocator: Allocator, attr: Attribute) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, attr.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "type"), try typeToInfra(allocator, attr.type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "readonly"), try boolToInfra(allocator, attr.readonly));
    try map.set(try infra.string.utf8ToUtf16(allocator, "static"), try boolToInfra(allocator, attr.static));
    try map.set(try infra.string.utf8ToUtf16(allocator, "stringifier"), try boolToInfra(allocator, attr.stringifier));
    try map.set(try infra.string.utf8ToUtf16(allocator, "inherit"), try boolToInfra(allocator, attr.inherit));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, attr.extended_attributes));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn operationToInfra(allocator: Allocator, op: Operation) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try nullableStringToInfra(allocator, op.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "return_type"), try typeToInfra(allocator, op.return_type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "arguments"), try argumentsToInfra(allocator, op.arguments));
    try map.set(try infra.string.utf8ToUtf16(allocator, "static"), try boolToInfra(allocator, op.static));

    const special_val = if (op.special) |spec|
        try stringToInfra(allocator, @tagName(spec))
    else
        try nullToInfra(allocator);
    try map.set(try infra.string.utf8ToUtf16(allocator, "special"), special_val);

    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, op.extended_attributes));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn constructorToInfra(allocator: Allocator, ctor: Constructor) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "arguments"), try argumentsToInfra(allocator, ctor.arguments));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, ctor.extended_attributes));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn stringifierToInfra(allocator: Allocator, s: Stringifier) !*infra.InfraValue {
    switch (s) {
        .keyword => {
            return try stringToInfra(allocator, "keyword");
        },
        .attribute => |attr| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "attribute"), try attributeToInfra(allocator, attr));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .operation => |op| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "operation"), try operationToInfra(allocator, op));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
    }
}

fn constToInfra(allocator: Allocator, c: Const) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, c.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "type"), try typeToInfra(allocator, c.type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "value"), try valueToInfra(allocator, c.value));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn iterableToInfra(allocator: Allocator, it: Iterable) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    const key_type_val = if (it.key_type) |kt|
        try typeToInfra(allocator, kt)
    else
        try nullToInfra(allocator);
    try map.set(try infra.string.utf8ToUtf16(allocator, "key_type"), key_type_val);
    try map.set(try infra.string.utf8ToUtf16(allocator, "value_type"), try typeToInfra(allocator, it.value_type));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn asyncIterableToInfra(allocator: Allocator, ai: AsyncIterable) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    const key_type_val = if (ai.key_type) |kt|
        try typeToInfra(allocator, kt)
    else
        try nullToInfra(allocator);
    try map.set(try infra.string.utf8ToUtf16(allocator, "key_type"), key_type_val);
    try map.set(try infra.string.utf8ToUtf16(allocator, "value_type"), try typeToInfra(allocator, ai.value_type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "arguments"), try argumentsToInfra(allocator, ai.arguments));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn maplikeToInfra(allocator: Allocator, m: Maplike) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "key_type"), try typeToInfra(allocator, m.key_type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "value_type"), try typeToInfra(allocator, m.value_type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "readonly"), try boolToInfra(allocator, m.readonly));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn setlikeToInfra(allocator: Allocator, s: Setlike) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "value_type"), try typeToInfra(allocator, s.value_type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "readonly"), try boolToInfra(allocator, s.readonly));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn dictionaryToInfra(allocator: Allocator, dict: Dictionary) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, dict.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "inherits"), try nullableStringToInfra(allocator, dict.inherits));
    try map.set(try infra.string.utf8ToUtf16(allocator, "partial"), try boolToInfra(allocator, dict.partial));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, dict.extended_attributes));
    try map.set(try infra.string.utf8ToUtf16(allocator, "members"), try dictionaryMembersToInfra(allocator, dict.members));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn dictionaryMembersToInfra(allocator: Allocator, members: []DictionaryMember) !*infra.InfraValue {
    const list = try allocator.create(infra.List(*infra.InfraValue));
    list.* = infra.List(*infra.InfraValue).init(allocator);

    for (members) |member| {
        const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
        map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

        try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, member.name));
        try map.set(try infra.string.utf8ToUtf16(allocator, "type"), try typeToInfra(allocator, member.type));
        try map.set(try infra.string.utf8ToUtf16(allocator, "required"), try boolToInfra(allocator, member.required));

        const default_val = if (member.default_value) |val|
            try valueToInfra(allocator, val)
        else
            try nullToInfra(allocator);
        try map.set(try infra.string.utf8ToUtf16(allocator, "default_value"), default_val);

        try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, member.extended_attributes));

        const member_value = try allocator.create(infra.InfraValue);
        member_value.* = .{ .map = map };
        try list.append(member_value);
    }

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .list = list };
    return result;
}

fn enumToInfra(allocator: Allocator, enm: Enum) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, enm.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "values"), try stringArrayToInfra(allocator, enm.values));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, enm.extended_attributes));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn typedefToInfra(allocator: Allocator, td: Typedef) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, td.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "type"), try typeToInfra(allocator, td.type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, td.extended_attributes));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn callbackToInfra(allocator: Allocator, cb: Callback) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, cb.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "return_type"), try typeToInfra(allocator, cb.return_type));
    try map.set(try infra.string.utf8ToUtf16(allocator, "arguments"), try argumentsToInfra(allocator, cb.arguments));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, cb.extended_attributes));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn callbackInterfaceToInfra(allocator: Allocator, cbi: CallbackInterface) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, cbi.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "members"), try interfaceMembersToInfra(allocator, cbi.members));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, cbi.extended_attributes));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn includesToInfra(allocator: Allocator, inc: IncludesStatement) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "interface"), try stringToInfra(allocator, inc.interface));
    try map.set(try infra.string.utf8ToUtf16(allocator, "mixin"), try stringToInfra(allocator, inc.mixin));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn namespaceToInfra(allocator: Allocator, ns: Namespace) !*infra.InfraValue {
    const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
    map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

    try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, ns.name));
    try map.set(try infra.string.utf8ToUtf16(allocator, "partial"), try boolToInfra(allocator, ns.partial));
    try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, ns.extended_attributes));
    try map.set(try infra.string.utf8ToUtf16(allocator, "members"), try namespaceMembersToInfra(allocator, ns.members));

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .map = map };
    return result;
}

fn namespaceMembersToInfra(allocator: Allocator, members: []NamespaceMember) !*infra.InfraValue {
    const list = try allocator.create(infra.List(*infra.InfraValue));
    list.* = infra.List(*infra.InfraValue).init(allocator);

    for (members) |member| {
        const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
        map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

        switch (member) {
            .attribute => |attr| {
                try map.set(try infra.string.utf8ToUtf16(allocator, "attribute"), try attributeToInfra(allocator, attr));
            },
            .operation => |op| {
                try map.set(try infra.string.utf8ToUtf16(allocator, "operation"), try operationToInfra(allocator, op));
            },
            .const_member => |c| {
                try map.set(try infra.string.utf8ToUtf16(allocator, "const"), try constToInfra(allocator, c));
            },
        }

        const member_value = try allocator.create(infra.InfraValue);
        member_value.* = .{ .map = map };
        try list.append(member_value);
    }

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .list = list };
    return result;
}

fn typeToInfra(allocator: Allocator, t: Type) !*infra.InfraValue {
    switch (t) {
        .any => return try stringToInfra(allocator, "any"),
        .undefined => return try stringToInfra(allocator, "undefined"),
        .boolean => return try stringToInfra(allocator, "boolean"),
        .byte => return try stringToInfra(allocator, "byte"),
        .octet => return try stringToInfra(allocator, "octet"),
        .short => return try stringToInfra(allocator, "short"),
        .unsigned_short => return try stringToInfra(allocator, "unsigned short"),
        .long => return try stringToInfra(allocator, "long"),
        .unsigned_long => return try stringToInfra(allocator, "unsigned long"),
        .long_long => return try stringToInfra(allocator, "long long"),
        .unsigned_long_long => return try stringToInfra(allocator, "unsigned long long"),
        .float => return try stringToInfra(allocator, "float"),
        .unrestricted_float => return try stringToInfra(allocator, "unrestricted float"),
        .double => return try stringToInfra(allocator, "double"),
        .unrestricted_double => return try stringToInfra(allocator, "unrestricted double"),
        .bigint => return try stringToInfra(allocator, "bigint"),
        .dom_string => return try stringToInfra(allocator, "DOMString"),
        .byte_string => return try stringToInfra(allocator, "ByteString"),
        .usv_string => return try stringToInfra(allocator, "USVString"),
        .object => return try stringToInfra(allocator, "object"),
        .symbol => return try stringToInfra(allocator, "symbol"),
        .identifier => |name| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "identifier"), try stringToInfra(allocator, name));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .sequence => |inner| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "sequence"), try typeToInfra(allocator, inner.*));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .frozen_array => |inner| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "frozen_array"), try typeToInfra(allocator, inner.*));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .observable_array => |inner| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "observable_array"), try typeToInfra(allocator, inner.*));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .record => |rec| {
            const outer_map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            outer_map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

            const inner_map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            inner_map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try inner_map.set(try infra.string.utf8ToUtf16(allocator, "key"), try typeToInfra(allocator, rec.key.*));
            try inner_map.set(try infra.string.utf8ToUtf16(allocator, "value"), try typeToInfra(allocator, rec.value.*));

            const inner_value = try allocator.create(infra.InfraValue);
            inner_value.* = .{ .map = inner_map };

            try outer_map.set(try infra.string.utf8ToUtf16(allocator, "record"), inner_value);
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = outer_map };
            return result;
        },
        .promise => |inner| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "promise"), try typeToInfra(allocator, inner.*));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .nullable => |inner| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "nullable"), try typeToInfra(allocator, inner.*));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .union_type => |types| {
            const outer_map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            outer_map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

            const list = try allocator.create(infra.List(*infra.InfraValue));
            list.* = infra.List(*infra.InfraValue).init(allocator);
            for (types) |ut| {
                try list.append(try typeToInfra(allocator, ut));
            }

            const list_value = try allocator.create(infra.InfraValue);
            list_value.* = .{ .list = list };

            try outer_map.set(try infra.string.utf8ToUtf16(allocator, "union"), list_value);
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = outer_map };
            return result;
        },
    }
}

fn argumentsToInfra(allocator: Allocator, args: []Argument) anyerror!*infra.InfraValue {
    const list = try allocator.create(infra.List(*infra.InfraValue));
    list.* = infra.List(*infra.InfraValue).init(allocator);

    for (args) |arg| {
        const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
        map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

        try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, arg.name));
        try map.set(try infra.string.utf8ToUtf16(allocator, "type"), try typeToInfra(allocator, arg.type));
        try map.set(try infra.string.utf8ToUtf16(allocator, "optional"), try boolToInfra(allocator, arg.optional));
        try map.set(try infra.string.utf8ToUtf16(allocator, "variadic"), try boolToInfra(allocator, arg.variadic));

        const default_val = if (arg.default_value) |val|
            try valueToInfra(allocator, val)
        else
            try nullToInfra(allocator);
        try map.set(try infra.string.utf8ToUtf16(allocator, "default_value"), default_val);

        try map.set(try infra.string.utf8ToUtf16(allocator, "extended_attributes"), try extendedAttributesToInfra(allocator, arg.extended_attributes));

        const arg_value = try allocator.create(infra.InfraValue);
        arg_value.* = .{ .map = map };
        try list.append(arg_value);
    }

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .list = list };
    return result;
}

fn valueToInfra(allocator: Allocator, val: Value) !*infra.InfraValue {
    switch (val) {
        .null_value => return try nullToInfra(allocator),
        .boolean => |b| return try boolToInfra(allocator, b),
        .integer => |iv| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "value"), try numberToInfra(allocator, @floatFromInt(iv.value)));
            try map.set(try infra.string.utf8ToUtf16(allocator, "lexeme"), try stringToInfra(allocator, iv.lexeme));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .float => |fv| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "value"), try numberToInfra(allocator, fv.value));
            try map.set(try infra.string.utf8ToUtf16(allocator, "lexeme"), try stringToInfra(allocator, fv.lexeme));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .string => |s| return try stringToInfra(allocator, s),
        .empty_sequence => {
            const list = try allocator.create(infra.List(*infra.InfraValue));
            list.* = infra.List(*infra.InfraValue).init(allocator);
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .list = list };
            return result;
        },
        .empty_dictionary => {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .infinity => return try stringToInfra(allocator, "Infinity"),
        .negative_infinity => return try stringToInfra(allocator, "-Infinity"),
        .nan => return try stringToInfra(allocator, "NaN"),
    }
}

fn extendedAttributesToInfra(allocator: Allocator, attrs: []ExtendedAttribute) anyerror!*infra.InfraValue {
    const list = try allocator.create(infra.List(*infra.InfraValue));
    list.* = infra.List(*infra.InfraValue).init(allocator);

    for (attrs) |attr| {
        const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
        map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

        try map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, attr.name));

        const value_val = if (attr.value) |val|
            try extendedAttrValueToInfra(allocator, val)
        else
            try nullToInfra(allocator);
        try map.set(try infra.string.utf8ToUtf16(allocator, "value"), value_val);

        const attr_value = try allocator.create(infra.InfraValue);
        attr_value.* = .{ .map = map };
        try list.append(attr_value);
    }

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .list = list };
    return result;
}

fn extendedAttrValueToInfra(allocator: Allocator, val: ExtendedAttrValue) anyerror!*infra.InfraValue {
    switch (val) {
        .identifier => |id| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "identifier"), try stringToInfra(allocator, id));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .identifier_list => |list_items| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "identifier_list"), try stringArrayToInfra(allocator, list_items));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .argument_list => |args| {
            const map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try map.set(try infra.string.utf8ToUtf16(allocator, "argument_list"), try argumentsToInfra(allocator, args));
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = map };
            return result;
        },
        .named_arg_list => |nal| {
            const outer_map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            outer_map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);

            const inner_map = try allocator.create(infra.OrderedMap(infra.String, *infra.InfraValue));
            inner_map.* = infra.OrderedMap(infra.String, *infra.InfraValue).init(allocator);
            try inner_map.set(try infra.string.utf8ToUtf16(allocator, "name"), try stringToInfra(allocator, nal.name));
            try inner_map.set(try infra.string.utf8ToUtf16(allocator, "arguments"), try argumentsToInfra(allocator, nal.args));

            const inner_value = try allocator.create(infra.InfraValue);
            inner_value.* = .{ .map = inner_map };

            try outer_map.set(try infra.string.utf8ToUtf16(allocator, "named_argument_list"), inner_value);
            const result = try allocator.create(infra.InfraValue);
            result.* = .{ .map = outer_map };
            return result;
        },
    }
}

fn stringToInfra(allocator: Allocator, s: []const u8) !*infra.InfraValue {
    const utf16_str = try infra.string.utf8ToUtf16(allocator, s);
    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .string = utf16_str };
    return result;
}

fn nullableStringToInfra(allocator: Allocator, s: ?[]const u8) !*infra.InfraValue {
    if (s) |str| {
        return try stringToInfra(allocator, str);
    } else {
        return try nullToInfra(allocator);
    }
}

fn stringArrayToInfra(allocator: Allocator, strings: [][]const u8) !*infra.InfraValue {
    const list = try allocator.create(infra.List(*infra.InfraValue));
    list.* = infra.List(*infra.InfraValue).init(allocator);

    for (strings) |s| {
        try list.append(try stringToInfra(allocator, s));
    }

    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .list = list };
    return result;
}

fn boolToInfra(allocator: Allocator, b: bool) !*infra.InfraValue {
    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .boolean = b };
    return result;
}

fn numberToInfra(allocator: Allocator, n: f64) !*infra.InfraValue {
    const result = try allocator.create(infra.InfraValue);
    result.* = .{ .number = n };
    return result;
}

fn nullToInfra(allocator: Allocator) !*infra.InfraValue {
    const result = try allocator.create(infra.InfraValue);
    result.* = .null_value;
    return result;
}
