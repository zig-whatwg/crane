//! WHATWG WebIDL Runtime Support Library
//!
//! Spec: https://webidl.spec.whatwg.org/
//!
//! This library provides the runtime support infrastructure for WebIDL bindings,
//! including type conversions, error handling, and wrapper types used by all
//! WHATWG specifications (DOM, Fetch, URL, etc.).
//!
//! # Architecture
//!
//! This library provides the **JavaScript binding layer** on top of the WHATWG
//! Infra primitives:
//!
//! - Type conversions (JavaScript ↔ WebIDL types)
//! - Error handling (DOMException, TypeError, RangeError, etc.)
//! - Wrapper types (Nullable<T>, Optional<T>, Sequence<T>, Record<K,V>)
//! - Extended attribute support ([Clamp], [EnforceRange], etc.)
//! - Dictionary and union infrastructure
//! - Buffer source types (ArrayBuffer, typed arrays)
//! - Callback types (function/interface references)
//!
//! # Dependencies
//!
//! This library depends on the WHATWG Infra library for:
//! - UTF-16 strings (infra.String)
//! - Dynamic arrays (infra.List)
//! - Ordered maps (infra.OrderedMap)
//! - String operations (utf8ToUtf16, asciiLowercase, etc.)
//!
//! See INFRA_BOUNDARY.md for details on what Infra provides vs. what WebIDL adds.
//!
//! # Usage
//!
//! ```zig
//! const std = @import("std");
//! const webidl = @import("webidl");
//!
//! // Example: Creating a DOMException
//! var err = webidl.errors.ErrorResult{};
//! err.throwDOMException("NotFoundError", "Element not found");
//!
//! if (err.hasFailed()) {
//!     // Handle error
//! }
//! ```

const std = @import("std");

// Re-export submodules
pub const errors = @import("errors.zig");
pub const primitives = @import("types/primitives.zig");
pub const objects = @import("types/object.zig");
pub const strings = @import("types/strings.zig");
pub const byte_strings = @import("types/byte_strings.zig");
pub const code_points = @import("types/code_points.zig");
pub const bigint = @import("types/bigint.zig");
pub const enumerations = @import("types/enumerations.zig");
pub const dictionaries = @import("types/dictionaries.zig");
pub const record_conversion = @import("types/record_conversion.zig");
pub const unions = @import("types/unions.zig");
pub const buffer_sources = @import("types/buffer_sources.zig");
pub const callbacks = @import("types/callbacks.zig");
pub const frozen_arrays = @import("types/frozen_arrays.zig");
pub const observable_arrays = @import("types/observable_arrays.zig");
pub const maplike = @import("types/maplike.zig");
pub const setlike = @import("types/setlike.zig");
pub const iterables = @import("types/iterables.zig");
pub const async_sequences = @import("types/async_sequences.zig");
pub const namespaces = @import("types/namespaces.zig");
pub const constants = @import("types/constants.zig");
pub const interfaces = @import("types/interfaces.zig");
pub const extended_attrs = @import("extended_attrs.zig");
pub const helpers = @import("helpers.zig");
pub const wrappers = @import("wrappers.zig");
pub const overload_resolution = @import("overload_resolution.zig");
pub const legacy_platform_objects = @import("legacy_platform_objects.zig");

// Re-export common types
pub const DOMException = errors.DOMException;
pub const Exception = errors.Exception;
pub const ErrorResult = errors.ErrorResult;
pub const JSValue = primitives.JSValue;
pub const JSObject = objects.JSObject;
pub const DOMString = strings.DOMString;
pub const ByteString = strings.ByteString;
pub const USVString = strings.USVString;
pub const CodePoint = code_points.CodePoint;

// Re-export dictionary utilities
pub const extractDictionaryMember = dictionaries.extractDictionaryMember;
pub const extractNestedMember = dictionaries.extractNestedMember;
pub const extractCallback = dictionaries.extractCallback;
pub const extractDictionaryMemberWithAttrs = dictionaries.extractDictionaryMemberWithAttrs;
pub const ExtendedAttributeOptions = dictionaries.ExtendedAttributeOptions;

// Re-export record conversion
pub const toRecord = record_conversion.toRecord;

// Re-export callback types
pub const GenericCallback = callbacks.GenericCallback;
pub const CallbackVTable = callbacks.CallbackVTable;

// Re-export wrapper types
pub const Nullable = wrappers.Nullable;
pub const Optional = wrappers.Optional;
pub const Sequence = wrappers.Sequence;
pub const Record = wrappers.Record;
pub const Promise = wrappers.Promise;
pub const Enumeration = enumerations.Enumeration;
pub const Union = unions.Union;

// Re-export buffer source types
pub const ArrayBuffer = buffer_sources.ArrayBuffer;
pub const TypedArray = buffer_sources.TypedArray;
pub const DataView = buffer_sources.DataView;
pub const BigInt64Array = buffer_sources.BigInt64Array;
pub const BigUint64Array = buffer_sources.BigUint64Array;
pub const BufferSourceType = buffer_sources.BufferSourceType;
pub const ArrayBufferView = buffer_sources.ArrayBufferView;
pub const BufferSource = buffer_sources.BufferSource;
pub const SharedArrayBuffer = buffer_sources.SharedArrayBuffer;
pub const AllowSharedBufferSource = buffer_sources.AllowSharedBufferSource;

// Re-export bigint types
pub const BigInt = bigint.BigInt;
pub const toBigInt = bigint.toBigInt;
pub const toBigIntEnforceRange = bigint.toBigIntEnforceRange;
pub const toBigIntClamped = bigint.toBigIntClamped;

// Re-export callback types
pub const CallbackFunction = callbacks.CallbackFunction;
pub const CallbackInterface = callbacks.CallbackInterface;
pub const SingleOperationCallbackInterface = callbacks.SingleOperationCallbackInterface;
pub const CallbackContext = callbacks.CallbackContext;

// Re-export array types
pub const FrozenArray = frozen_arrays.FrozenArray;
pub const ObservableArray = observable_arrays.ObservableArray;

// Re-export collection types
pub const Maplike = maplike.Maplike;
pub const Setlike = setlike.Setlike;

// Re-export iterable types
pub const ValueIterable = iterables.ValueIterable;
pub const PairIterable = iterables.PairIterable;
pub const AsyncIterable = iterables.AsyncIterable;

// Re-export async sequence types
pub const AsyncSequence = async_sequences.AsyncSequence;
pub const BufferedAsyncSequence = async_sequences.BufferedAsyncSequence;

// Re-export namespace helper
pub const Namespace = namespaces.Namespace;

// Re-export constant helper
pub const Constant = constants.Constant;
pub const NodeType = constants.NodeType;
pub const DocumentPosition = constants.DocumentPosition;
pub const XHRReadyState = constants.XHRReadyState;

// Re-export interface wrapping/unwrapping
pub const InterfaceWrapper = interfaces.InterfaceWrapper;
pub const wrapInterface = interfaces.wrapInterface;
pub const wrapInterfaceConst = interfaces.wrapInterfaceConst;
pub const unwrapInterface = interfaces.unwrapInterface;
pub const unwrapInterfaceConst = interfaces.unwrapInterfaceConst;
pub const isInterface = interfaces.isInterface;
pub const isInterfaceType = interfaces.isInterfaceType;

// Re-export type metadata system
pub const type_metadata = @import("type_metadata.zig");
pub const typeMetadata = type_metadata.typeMetadata;
pub const TypeMetadata = type_metadata.TypeMetadata;
pub const TypeKind = type_metadata.TypeKind;
pub const ConversionInfo = type_metadata.ConversionInfo;
pub const FunctionSignature = type_metadata.FunctionSignature;

// Re-export runtime helpers for WebIDL metadata
pub const GlobalScope = helpers.GlobalScope;
pub const isExposedIn = helpers.isExposedIn;
pub const isTransferable = helpers.isTransferable;
pub const isSerializable = helpers.isSerializable;
pub const getGlobalNames = helpers.getGlobalNames;
pub const getParent = helpers.getParent;
pub const isNamespace = helpers.isNamespace;
pub const isMixin = helpers.isMixin;

// Re-export WebIDL primitive type aliases (with exact spec casing)
pub const any = primitives.any_type;
pub const boolean = primitives.boolean_type;
pub const byte = primitives.byte_type;
pub const octet = primitives.octet_type;
pub const short = primitives.short_type;
pub const @"unsigned short" = primitives.unsigned_short_type;
pub const long = primitives.long_type;
pub const @"unsigned long" = primitives.unsigned_long_type;
pub const @"long long" = primitives.long_long_type;
pub const @"unsigned long long" = primitives.unsigned_long_long_type;
pub const float = primitives.float_type;
pub const @"unrestricted float" = primitives.unrestricted_float_type;
pub const double = primitives.double_type;
pub const @"unrestricted double" = primitives.unrestricted_double_type;
pub const bigint_type = bigint.bigint_type;
pub const object = primitives.object_type;
pub const symbol = primitives.symbol_type;

test {
    std.testing.refAllDecls(@This());
}

// ============================================================================
// Code Generation API
// ============================================================================
//
// WebIDL interface/namespace/mixin markers for build-time code generation.
// These functions are used in source files to declare WebIDL types that will
// be enhanced by the codegen tool at build time.
//
// Usage:
//   const EventTarget = webidl.interface(struct { ... });
//   const Console = webidl.namespace(struct { ... });
//   const Timestamped = webidl.mixin(struct { ... });

/// WebIDL codegen API
pub const codegen = @import("codegen/root.zig");

/// Mark a struct as a WebIDL interface (supports inheritance, methods, properties)
pub const interface = codegen.interface;

/// Mark a struct as a WebIDL namespace (static-only API, no instances)
pub const namespace = codegen.namespace;

/// Mark a struct as a WebIDL mixin (reusable fields/methods for composition)
pub const mixin = codegen.mixin;

/// Configuration for generated method prefixes
pub const CodegenConfig = codegen.ClassConfig;
