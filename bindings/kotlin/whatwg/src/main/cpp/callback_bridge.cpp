/**
 * @file callback_bridge.cpp
 * @brief Callback bridge implementation for WHATWG Kotlin bindings
 * 
 * This file implements the callback context management functions that
 * allow native code to call back into Kotlin.
 */

#include "jni_bridge.h"
#include <stdlib.h>
#include <string.h>
#include <android/log.h>

#define LOG_TAG "WhatWG-Callback"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ============================================================================
// Callback Context Implementation
// ============================================================================

jni_callback_context_t* jni_callback_context_create(
    JNIEnv* env,
    jobject callback,
    const char* method_name,
    const char* method_sig
) {
    if (env == nullptr || callback == nullptr) {
        LOGE("Invalid arguments to jni_callback_context_create");
        return nullptr;
    }
    
    jni_callback_context_t* ctx = static_cast<jni_callback_context_t*>(
        malloc(sizeof(jni_callback_context_t))
    );
    if (ctx == nullptr) {
        LOGE("Failed to allocate callback context");
        return nullptr;
    }
    
    // Get the JVM reference
    if (env->GetJavaVM(&ctx->jvm) != 0) {
        LOGE("Failed to get JavaVM");
        free(ctx);
        return nullptr;
    }
    
    // Create a global reference to the callback object
    ctx->callback_object = env->NewGlobalRef(callback);
    if (ctx->callback_object == nullptr) {
        LOGE("Failed to create global reference");
        free(ctx);
        return nullptr;
    }
    
    // Get the method ID
    jclass clazz = env->GetObjectClass(callback);
    if (clazz == nullptr) {
        LOGE("Failed to get callback class");
        env->DeleteGlobalRef(ctx->callback_object);
        free(ctx);
        return nullptr;
    }
    
    ctx->method_id = env->GetMethodID(clazz, method_name, method_sig);
    env->DeleteLocalRef(clazz);
    
    if (ctx->method_id == nullptr) {
        LOGE("Failed to get method ID for %s%s", method_name, method_sig);
        env->DeleteGlobalRef(ctx->callback_object);
        free(ctx);
        return nullptr;
    }
    
    LOGI("Created callback context for %s", method_name);
    return ctx;
}

void jni_callback_context_destroy(jni_callback_context_t* ctx) {
    if (ctx == nullptr) return;
    
    JNIEnv* env = jni_callback_get_env(ctx);
    if (env != nullptr && ctx->callback_object != nullptr) {
        env->DeleteGlobalRef(ctx->callback_object);
    }
    
    free(ctx);
    LOGI("Destroyed callback context");
}

JNIEnv* jni_callback_get_env(jni_callback_context_t* ctx) {
    if (ctx == nullptr || ctx->jvm == nullptr) {
        return nullptr;
    }
    
    JNIEnv* env = nullptr;
    jint result = ctx->jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    
    if (result == JNI_EDETACHED) {
        // Thread not attached, attach it
        if (ctx->jvm->AttachCurrentThread(&env, nullptr) != 0) {
            LOGE("Failed to attach thread to JVM");
            return nullptr;
        }
    } else if (result != JNI_OK) {
        LOGE("Failed to get JNIEnv: %d", result);
        return nullptr;
    }
    
    return env;
}

// ============================================================================
// Provider Context Implementation
// ============================================================================

jni_provider_context_t* jni_provider_context_create(JNIEnv* env) {
    jni_provider_context_t* ctx = static_cast<jni_provider_context_t*>(
        calloc(1, sizeof(jni_provider_context_t))
    );
    if (ctx == nullptr) {
        LOGE("Failed to allocate provider context");
        return nullptr;
    }
    
    if (env->GetJavaVM(&ctx->jvm) != 0) {
        LOGE("Failed to get JavaVM");
        free(ctx);
        return nullptr;
    }
    
    LOGI("Created provider context");
    return ctx;
}

void jni_provider_context_destroy(jni_provider_context_t* ctx) {
    if (ctx == nullptr) return;
    
    JNIEnv* env = nullptr;
    if (ctx->jvm != nullptr) {
        ctx->jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    }
    
    if (env != nullptr) {
        // Release all global references
        if (ctx->clipboard_provider) env->DeleteGlobalRef(ctx->clipboard_provider);
        if (ctx->timer_provider) env->DeleteGlobalRef(ctx->timer_provider);
        if (ctx->network_provider) env->DeleteGlobalRef(ctx->network_provider);
        if (ctx->storage_provider) env->DeleteGlobalRef(ctx->storage_provider);
        if (ctx->geolocation_provider) env->DeleteGlobalRef(ctx->geolocation_provider);
        if (ctx->notification_provider) env->DeleteGlobalRef(ctx->notification_provider);
        if (ctx->ui_provider) env->DeleteGlobalRef(ctx->ui_provider);
    }
    
    free(ctx);
    LOGI("Destroyed provider context");
}

int jni_provider_context_set_provider(
    jni_provider_context_t* ctx,
    JNIEnv* env,
    const char* provider_type,
    jobject provider
) {
    if (ctx == nullptr || env == nullptr || provider_type == nullptr) {
        return -1;
    }
    
    jclass clazz = env->GetObjectClass(provider);
    if (clazz == nullptr) {
        LOGE("Failed to get provider class");
        return -1;
    }
    
    jobject global_ref = env->NewGlobalRef(provider);
    if (global_ref == nullptr) {
        LOGE("Failed to create global reference for provider");
        env->DeleteLocalRef(clazz);
        return -1;
    }
    
    if (strcmp(provider_type, "clipboard") == 0) {
        if (ctx->clipboard_provider) env->DeleteGlobalRef(ctx->clipboard_provider);
        ctx->clipboard_provider = global_ref;
        ctx->clipboard_read_text = env->GetMethodID(clazz, "readText", "()Ljava/lang/String;");
        ctx->clipboard_write_text = env->GetMethodID(clazz, "writeText", "(Ljava/lang/String;)V");
    }
    else if (strcmp(provider_type, "timer") == 0) {
        if (ctx->timer_provider) env->DeleteGlobalRef(ctx->timer_provider);
        ctx->timer_provider = global_ref;
        ctx->timer_set_timeout = env->GetMethodID(clazz, "setTimeout", "(JLjava/lang/Runnable;)J");
        ctx->timer_set_interval = env->GetMethodID(clazz, "setInterval", "(JLjava/lang/Runnable;)J");
        ctx->timer_clear_timeout = env->GetMethodID(clazz, "clearTimeout", "(J)V");
        ctx->timer_clear_interval = env->GetMethodID(clazz, "clearInterval", "(J)V");
    }
    else if (strcmp(provider_type, "storage") == 0) {
        if (ctx->storage_provider) env->DeleteGlobalRef(ctx->storage_provider);
        ctx->storage_provider = global_ref;
        ctx->storage_get_item = env->GetMethodID(clazz, "getItem", "(Ljava/lang/String;)Ljava/lang/String;");
        ctx->storage_set_item = env->GetMethodID(clazz, "setItem", "(Ljava/lang/String;Ljava/lang/String;)V");
        ctx->storage_remove_item = env->GetMethodID(clazz, "removeItem", "(Ljava/lang/String;)V");
        ctx->storage_clear = env->GetMethodID(clazz, "clear", "()V");
        ctx->storage_length = env->GetMethodID(clazz, "length", "()I");
        ctx->storage_key = env->GetMethodID(clazz, "key", "(I)Ljava/lang/String;");
    }
    else if (strcmp(provider_type, "ui") == 0) {
        if (ctx->ui_provider) env->DeleteGlobalRef(ctx->ui_provider);
        ctx->ui_provider = global_ref;
        ctx->ui_alert = env->GetMethodID(clazz, "alert", "(Ljava/lang/String;)V");
        ctx->ui_confirm = env->GetMethodID(clazz, "confirm", "(Ljava/lang/String;)Z");
        ctx->ui_prompt = env->GetMethodID(clazz, "prompt", "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;");
    }
    else {
        LOGE("Unknown provider type: %s", provider_type);
        env->DeleteGlobalRef(global_ref);
        env->DeleteLocalRef(clazz);
        return -1;
    }
    
    env->DeleteLocalRef(clazz);
    LOGI("Set %s provider", provider_type);
    return 0;
}

// ============================================================================
// Utility Functions Implementation
// ============================================================================

char* jni_string_to_c(JNIEnv* env, jstring jstr) {
    if (env == nullptr || jstr == nullptr) {
        return nullptr;
    }
    
    const char* utf = env->GetStringUTFChars(jstr, nullptr);
    if (utf == nullptr) {
        return nullptr;
    }
    
    size_t len = strlen(utf);
    char* result = static_cast<char*>(malloc(len + 1));
    if (result != nullptr) {
        memcpy(result, utf, len + 1);
    }
    
    env->ReleaseStringUTFChars(jstr, utf);
    return result;
}

jstring jni_string_from_c(JNIEnv* env, const char* cstr) {
    if (env == nullptr || cstr == nullptr) {
        return nullptr;
    }
    return env->NewStringUTF(cstr);
}

void jni_throw_exception(JNIEnv* env, const char* exception_class, const char* message) {
    if (env == nullptr) return;
    
    jclass clazz = env->FindClass(exception_class);
    if (clazz != nullptr) {
        env->ThrowNew(clazz, message);
        env->DeleteLocalRef(clazz);
    } else {
        LOGE("Failed to find exception class: %s", exception_class);
    }
}
