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

} // extern "C"
