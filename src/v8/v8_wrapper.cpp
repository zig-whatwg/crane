//! Minimal V8 C wrapper for Zig REPL
//! Provides essential V8 functions for JavaScript execution
//!
//! NOTE: Uses Global<> handles for cross-function storage (not Local<>)
//! Local<> handles are stack-only and tied to HandleScope.
//! Global<> handles can be stored on heap and survive beyond HandleScope.

#include <v8.h>
#include <libplatform/libplatform.h>
#include <cstring>

using namespace v8;

// Platform singleton
static std::unique_ptr<Platform> g_platform = nullptr;
static bool v8_initialized = false;

extern "C" {

// V8 Platform initialization
void v8_platform_initialize() {
    if (!v8_initialized) {
        V8::InitializeICUDefaultLocation("");
        V8::InitializeExternalStartupData("");
        g_platform = platform::NewDefaultPlatform();
        V8::InitializePlatform(g_platform.get());
        V8::Initialize();
        v8_initialized = true;
    }
}

void v8_platform_dispose() {
    if (v8_initialized) {
        V8::Dispose();
        V8::DisposePlatform();
        v8_initialized = false;
    }
}

// Isolate management
Isolate* v8_isolate_new() {
    if (!v8_initialized) {
        v8_platform_initialize();
    }
    
    Isolate::CreateParams create_params;
    create_params.array_buffer_allocator = ArrayBuffer::Allocator::NewDefaultAllocator();
    return Isolate::New(create_params);
}

void v8_isolate_dispose(Isolate* isolate) {
    if (isolate) {
        isolate->Dispose();
    }
}

void v8_isolate_enter(Isolate* isolate) {
    isolate->Enter();
}

void v8_isolate_exit(Isolate* isolate) {
    isolate->Exit();
}

// Context management - using Global<Context> for persistent storage
Global<Context>* v8_context_new(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Context> context = Context::New(isolate);
    
    // Return Global handle (caller must free with v8_context_dispose)
    return new Global<Context>(isolate, context);
}

void v8_context_dispose(Global<Context>* context) {
    if (context) {
        context->Reset();  // Release V8 handle
        delete context;
    }
}

void v8_context_enter(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->Enter();
}

void v8_context_exit(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->Exit();
}

Global<Object>* v8_context_global(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Local<Object> global = local_context->Global();
    return new Global<Object>(isolate, global);
}

// String management - using Global<String> for persistent storage
Global<String>* v8_string_new_from_utf8(Isolate* isolate, const char* data, int length) {
    HandleScope handle_scope(isolate);
    MaybeLocal<String> maybe_string = String::NewFromUtf8(
        isolate, 
        data, 
        NewStringType::kNormal, 
        length
    );
    
    if (maybe_string.IsEmpty()) {
        return nullptr;
    }
    
    Local<String> str = maybe_string.ToLocalChecked();
    return new Global<String>(isolate, str);
}

int v8_string_utf8_length(Global<String>* str) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> local_str = str->Get(isolate);
    return local_str->Utf8Length(isolate);
}

int v8_string_write_utf8(Global<String>* str, char* buffer, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> local_str = str->Get(isolate);
    return local_str->WriteUtf8(isolate, buffer, length);
}

void v8_string_dispose(Global<String>* str) {
    if (str) {
        str->Reset();
        delete str;
    }
}

// Script compilation and execution - using Global<Script> for persistent storage
Global<Script>* v8_script_compile(Global<Context>* context, Global<String>* source) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<String> local_source = source->Get(isolate);
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source);
    
    if (maybe_script.IsEmpty()) {
        return nullptr;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    return new Global<Script>(isolate, script);
}

Global<Value>* v8_script_run(Global<Context>* context, Global<Script>* script) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Script> local_script = script->Get(isolate);
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Value> maybe_result = local_script->Run(local_context);
    
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> result = maybe_result.ToLocalChecked();
    return new Global<Value>(isolate, result);
}

void v8_script_dispose(Global<Script>* script) {
    if (script) {
        script->Reset();
        delete script;
    }
}

// Value to String conversion
Global<String>* v8_value_to_string(Global<Context>* context, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Value> local_value = value->Get(isolate);
    
    MaybeLocal<String> maybe_string = local_value->ToString(local_context);
    
    if (maybe_string.IsEmpty()) {
        return nullptr;
    }
    
    Local<String> str = maybe_string.ToLocalChecked();
    return new Global<String>(isolate, str);
}

void v8_value_dispose(Global<Value>* value) {
    if (value) {
        value->Reset();
        delete value;
    }
}

// Object property operations
Global<Array>* v8_object_get_own_property_names(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    MaybeLocal<Array> maybe_names = local_obj->GetOwnPropertyNames(local_context);
    
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return new Global<Array>(isolate, names);
}

void v8_object_dispose(Global<Object>* obj) {
    if (obj) {
        obj->Reset();
        delete obj;
    }
}

// Array operations
uint32_t v8_array_length(Global<Array>* arr) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Array> local_arr = arr->Get(isolate);
    return local_arr->Length();
}

Global<Value>* v8_array_get(Global<Context>* context, Global<Array>* arr, uint32_t index) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Array> local_arr = arr->Get(isolate);
    
    MaybeLocal<Value> maybe_value = local_arr->Get(local_context, index);
    
    if (maybe_value.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> value = maybe_value.ToLocalChecked();
    return new Global<Value>(isolate, value);
}

void v8_array_dispose(Global<Array>* arr) {
    if (arr) {
        arr->Reset();
        delete arr;
    }
}

// Exception handling
Global<Value>* v8_try_catch_exception(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    TryCatch try_catch(isolate);
    
    if (try_catch.HasCaught()) {
        Local<Value> exception = try_catch.Exception();
        return new Global<Value>(isolate, exception);
    }
    
    return nullptr;
}

// Object template for namespace bindings
Global<ObjectTemplate>* v8_object_template_new(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> templ = ObjectTemplate::New(isolate);
    return new Global<ObjectTemplate>(isolate, templ);
}

void v8_object_template_set(
    Global<ObjectTemplate>* templ,
    Isolate* isolate,
    const char* name,
    void (*callback)(const FunctionCallbackInfo<Value>&)
) {
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_templ = templ->Get(isolate);
    Local<String> name_str = String::NewFromUtf8(isolate, name).ToLocalChecked();
    Local<FunctionTemplate> func_template = FunctionTemplate::New(isolate, callback);
    local_templ->Set(name_str, func_template);
}

Global<Object>* v8_object_template_new_instance(
    Global<Context>* context,
    Global<ObjectTemplate>* templ
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<ObjectTemplate> local_templ = templ->Get(isolate);
    
    MaybeLocal<Object> maybe_obj = local_templ->NewInstance(local_context);
    
    if (maybe_obj.IsEmpty()) {
        return nullptr;
    }
    
    Local<Object> obj = maybe_obj.ToLocalChecked();
    return new Global<Object>(isolate, obj);
}

void v8_object_template_dispose(Global<ObjectTemplate>* templ) {
    if (templ) {
        templ->Reset();
        delete templ;
    }
}

// Set property on object
bool v8_object_set(
    Global<Context>* context,
    Global<Object>* obj,
    const char* key,
    Global<Value>* value
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    Local<Value> local_value = value->Get(isolate);
    
    Local<String> key_str = String::NewFromUtf8(isolate, key).ToLocalChecked();
    Maybe<bool> result = local_obj->Set(local_context, key_str, local_value);
    
    return result.FromMaybe(false);
}

// Value type checking functions
// Note: These operate on raw V8 Value pointers, not Global handles
bool v8_Value_IsUndefined(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsUndefined();
}

bool v8_Value_IsNull(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsNull();
}

bool v8_Value_IsNullOrUndefined(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsNullOrUndefined();
}

bool v8_Value_IsBoolean(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsBoolean();
}

bool v8_Value_IsNumber(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsNumber();
}

bool v8_Value_IsString(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsString();
}

bool v8_Value_IsSymbol(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsSymbol();
}

bool v8_Value_IsBigInt(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsBigInt();
}

bool v8_Value_IsObject(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsObject();
}

bool v8_Value_IsArray(Local<Value>* value) {
    return reinterpret_cast<Value*>(value)->IsArray();
}

// Value conversion functions
bool v8_Value_BooleanValue(Local<Value>* value, Isolate* isolate) {
    return reinterpret_cast<Value*>(value)->BooleanValue(isolate);
}

double v8_Value_NumberValue(Local<Value>* value, Local<Context>* context) {
    Maybe<double> result = reinterpret_cast<Value*>(value)->NumberValue(*reinterpret_cast<Local<Context>*>(context));
    return result.FromMaybe(0.0);
}

int32_t v8_Value_Int32Value(Local<Value>* value, Local<Context>* context) {
    Maybe<int32_t> result = reinterpret_cast<Value*>(value)->Int32Value(*reinterpret_cast<Local<Context>*>(context));
    return result.FromMaybe(0);
}

uint32_t v8_Value_Uint32Value(Local<Value>* value, Local<Context>* context) {
    Maybe<uint32_t> result = reinterpret_cast<Value*>(value)->Uint32Value(*reinterpret_cast<Local<Context>*>(context));
    return result.FromMaybe(0);
}

int64_t v8_Value_IntegerValue(Local<Value>* value, Local<Context>* context) {
    Maybe<int64_t> result = reinterpret_cast<Value*>(value)->IntegerValue(*reinterpret_cast<Local<Context>*>(context));
    return result.FromMaybe(0);
}

Local<String>* v8_Value_ToString(Local<Value>* value, Local<Context>* context) {
    MaybeLocal<String> maybe_string = reinterpret_cast<Value*>(value)->ToString(*reinterpret_cast<Local<Context>*>(context));
    
    if (maybe_string.IsEmpty()) {
        return nullptr;
    }
    
    // Return local handle (must be used within same scope)
    Local<String> str = maybe_string.ToLocalChecked();
    return reinterpret_cast<Local<String>*>(&str);
}

void v8_Value_Dispose(Local<Value>* value) {
    // Local handles are stack-allocated and automatically cleaned up
    // This is a no-op for Local handles
}

// ============================================================================
// Function aliases for capitalized FFI naming convention
// ============================================================================

// Context functions
inline Global<Context>* v8_Context_New(Isolate* isolate) { return v8_context_new(isolate); }
inline void v8_Context_Dispose(Global<Context>* context) { v8_context_dispose(context); }
inline void v8_Context_Enter(Global<Context>* context) { v8_context_enter(context); }
inline void v8_Context_Exit(Global<Context>* context) { v8_context_exit(context); }
inline Global<Object>* v8_Context_Global(Global<Context>* context) { return v8_context_global(context); }

// Isolate functions  
inline Isolate* v8_Isolate_New() { return v8_isolate_new(); }
inline void v8_Isolate_Dispose(Isolate* isolate) { v8_isolate_dispose(isolate); }
inline void v8_Isolate_Enter(Isolate* isolate) { v8_isolate_enter(isolate); }
inline void v8_Isolate_Exit(Isolate* isolate) { v8_isolate_exit(isolate); }

// Array functions
inline Global<Value>* v8_Array_Get(Global<Context>* context, Global<Array>* arr, uint32_t index) { 
    return v8_array_get(context, arr, index); 
}
inline uint32_t v8_Array_Length(Global<Array>* arr) { return v8_array_length(arr); }
inline void v8_Array_Dispose(Global<Array>* arr) { v8_array_dispose(arr); }

// String functions
inline Global<String>* v8_String_NewFromUtf8(Isolate* isolate, const char* data) { 
    return v8_string_new_from_utf8(isolate, data); 
}
inline void v8_String_Dispose(Global<String>* str) { v8_string_dispose(str); }

// Object functions
inline void v8_Object_Dispose(Global<Object>* obj) { v8_object_dispose(obj); }

// Script functions
inline Global<Script>* v8_Script_Compile(Global<Context>* context, Global<String>* source) { 
    return v8_script_compile(context, source); 
}
inline Global<Value>* v8_Script_Run(Global<Context>* context, Global<Script>* script) { 
    return v8_script_run(context, script); 
}
inline void v8_Script_Dispose(Global<Script>* script) { v8_script_dispose(script); }

// ObjectTemplate functions
inline Global<ObjectTemplate>* v8_ObjectTemplate_New(Isolate* isolate) { 
    return v8_object_template_new(isolate); 
}
inline Global<Object>* v8_ObjectTemplate_NewInstance(Global<Context>* context, Global<ObjectTemplate>* templ) { 
    return v8_object_template_new_instance(context, templ); 
}
inline void v8_ObjectTemplate_Set(
    Global<ObjectTemplate>* templ,
    const char* name,
    void (*getter)(const char*, void*),
    void (*setter)(const char*, void*, void*),
    void* data
) {
    v8_object_template_set(templ, name, getter, setter, data);
}
inline void v8_ObjectTemplate_Dispose(Global<ObjectTemplate>* templ) { 
    v8_object_template_dispose(templ); 
}

} // extern "C"

// ============================================================================
// Function aliases for capitalized FFI naming convention  
// These map the lowercase function names to the capitalized names expected by FFI
// ============================================================================

