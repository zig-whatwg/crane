// V8 Helper Functions for WebIDL Type Conversions
// Provides fromV8Value_* and toV8Value_* for all WebIDL types

#pragma once

#include <v8.h>
#include <string>
#include <cstdint>

namespace webidl {
namespace v8helpers {

using namespace v8;

// ============================================================================
// V8 → Native Type Conversions (fromV8Value_*)
// ============================================================================

// Boolean
inline bool fromV8Value_boolean(Isolate* isolate, Local<Value> value) {
    if (value.IsEmpty() || !value->IsBoolean()) {
        return false;
    }
    return value->BooleanValue(isolate);
}

// Numbers
inline int32_t fromV8Value_long(Isolate* isolate, Local<Value> value) {
    if (value.IsEmpty() || !value->IsNumber()) {
        return 0;
    }
    return value->Int32Value(isolate->GetCurrentContext()).FromMaybe(0);
}

inline uint32_t fromV8Value_unsigned_long(Isolate* isolate, Local<Value> value) {
    if (value.IsEmpty() || !value->IsNumber()) {
        return 0;
    }
    return value->Uint32Value(isolate->GetCurrentContext()).FromMaybe(0);
}

inline int64_t fromV8Value_long_long(Isolate* isolate, Local<Value> value) {
    if (value.IsEmpty() || !value->IsNumber()) {
        return 0;
    }
    return value->IntegerValue(isolate->GetCurrentContext()).FromMaybe(0);
}

inline uint64_t fromV8Value_unsigned_long_long(Isolate* isolate, Local<Value> value) {
    if (value.IsEmpty() || !value->IsNumber()) {
        return 0;
    }
    return value->IntegerValue(isolate->GetCurrentContext()).FromMaybe(0);
}

inline double fromV8Value_double(Isolate* isolate, Local<Value> value) {
    if (value.IsEmpty() || !value->IsNumber()) {
        return 0.0;
    }
    return value->NumberValue(isolate->GetCurrentContext()).FromMaybe(0.0);
}

inline float fromV8Value_float(Isolate* isolate, Local<Value> value) {
    return static_cast<float>(fromV8Value_double(isolate, value));
}

// Strings
inline std::string fromV8Value_DOMString(Isolate* isolate, Local<Value> value) {
    if (value.IsEmpty() || !value->IsString()) {
        return "";
    }
    String::Utf8Value utf8(isolate, value);
    return std::string(*utf8, utf8.length());
}

inline std::string fromV8Value_USVString(Isolate* isolate, Local<Value> value) {
    return fromV8Value_DOMString(isolate, value);
}

inline std::string fromV8Value_ByteString(Isolate* isolate, Local<Value> value) {
    return fromV8Value_DOMString(isolate, value);
}

// Any type (opaque pointer for now)
inline void* fromV8Value_any(Isolate* isolate, Local<Value> value) {
    // For 'any' type, we just return a placeholder
    // Proper implementation would wrap the V8 value
    return nullptr;
}

// Object type
inline void* fromV8Value_object(Isolate* isolate, Local<Value> value) {
    if (value.IsEmpty() || !value->IsObject()) {
        return nullptr;
    }
    return nullptr; // Placeholder
}

// Void (undefined)
inline void fromV8Value_void(Isolate* isolate, Local<Value> value) {
    // No-op for void type
}

// ============================================================================
// Native Type → V8 Conversions (toV8Value_*)
// ============================================================================

// Boolean
inline Local<Value> toV8Value_boolean(Isolate* isolate, bool value) {
    return Boolean::New(isolate, value);
}

// Numbers
inline Local<Value> toV8Value_long(Isolate* isolate, int32_t value) {
    return Integer::New(isolate, value);
}

inline Local<Value> toV8Value_unsigned_long(Isolate* isolate, uint32_t value) {
    return Integer::NewFromUnsigned(isolate, value);
}

inline Local<Value> toV8Value_long_long(Isolate* isolate, int64_t value) {
    return Number::New(isolate, static_cast<double>(value));
}

inline Local<Value> toV8Value_unsigned_long_long(Isolate* isolate, uint64_t value) {
    return Number::New(isolate, static_cast<double>(value));
}

inline Local<Value> toV8Value_double(Isolate* isolate, double value) {
    return Number::New(isolate, value);
}

inline Local<Value> toV8Value_float(Isolate* isolate, float value) {
    return Number::New(isolate, static_cast<double>(value));
}

// Strings
inline Local<Value> toV8Value_DOMString(Isolate* isolate, const std::string& value) {
    return String::NewFromUtf8(isolate, value.c_str(), 
                                NewStringType::kNormal, 
                                value.length()).ToLocalChecked();
}

inline Local<Value> toV8Value_USVString(Isolate* isolate, const std::string& value) {
    return toV8Value_DOMString(isolate, value);
}

inline Local<Value> toV8Value_ByteString(Isolate* isolate, const std::string& value) {
    return toV8Value_DOMString(isolate, value);
}

// Any type
inline Local<Value> toV8Value_any(Isolate* isolate, void* value) {
    // Placeholder - would need proper wrapping
    return Undefined(isolate);
}

// Object type
inline Local<Value> toV8Value_object(Isolate* isolate, void* value) {
    if (!value) {
        return Null(isolate);
    }
    // Placeholder - would need proper wrapping
    return Object::New(isolate);
}

// Void (undefined)
inline Local<Value> toV8Value_void(Isolate* isolate) {
    return Undefined(isolate);
}

} // namespace v8helpers
} // namespace webidl
