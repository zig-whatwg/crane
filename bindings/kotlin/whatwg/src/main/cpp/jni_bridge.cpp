/**
 * @file jni_bridge.cpp
 * @brief JNI bridge between Kotlin and the WHATWG C library
 */

#include <jni.h>
#include <string>
#include <android/log.h>

// Include the WHATWG C headers
extern "C" {
#include "whatwg.h"
}

#define LOG_TAG "WhatWG-JNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

// ============================================================================
// Version Functions
// ============================================================================

JNIEXPORT jstring JNICALL
Java_com_whatwg_internal_JNIBridge_versionString(JNIEnv *env, jclass clazz) {
    const char* version = whatwg_version_string();
    if (version == nullptr) {
        return env->NewStringUTF("unknown");
    }
    return env->NewStringUTF(version);
}

JNIEXPORT jint JNICALL
Java_com_whatwg_internal_JNIBridge_expectedVersion(JNIEnv *env, jclass clazz) {
    return static_cast<jint>(whatwg_platform_expected_version());
}

// ============================================================================
// Platform Lifecycle
// ============================================================================

JNIEXPORT jlong JNICALL
Java_com_whatwg_internal_JNIBridge_platformCreate(JNIEnv *env, jclass clazz) {
    whatwg_platform_t* platform = whatwg_platform_create();
    if (platform == nullptr) {
        LOGE("Failed to create platform");
        return 0;
    }
    LOGI("Platform created: %p", platform);
    return reinterpret_cast<jlong>(platform);
}

JNIEXPORT void JNICALL
Java_com_whatwg_internal_JNIBridge_platformDestroy(JNIEnv *env, jclass clazz, jlong handle) {
    if (handle == 0) return;
    
    auto* platform = reinterpret_cast<whatwg_platform_t*>(handle);
    LOGI("Destroying platform: %p", platform);
    whatwg_platform_destroy(platform);
}

JNIEXPORT jboolean JNICALL
Java_com_whatwg_internal_JNIBridge_platformHasCapability(
    JNIEnv *env, jclass clazz, jlong handle, jint capability
) {
    if (handle == 0) return JNI_FALSE;
    
    auto* platform = reinterpret_cast<whatwg_platform_t*>(handle);
    return whatwg_platform_has_capability(platform, static_cast<uint8_t>(capability)) 
        ? JNI_TRUE : JNI_FALSE;
}

// ============================================================================
// Context Lifecycle
// ============================================================================

JNIEXPORT jlong JNICALL
Java_com_whatwg_internal_JNIBridge_contextCreate(JNIEnv *env, jclass clazz, jlong platformHandle) {
    if (platformHandle == 0) return 0;
    
    auto* platform = reinterpret_cast<whatwg_platform_t*>(platformHandle);
    whatwg_context_t* context = whatwg_context_create(platform);
    if (context == nullptr) {
        LOGE("Failed to create context");
        return 0;
    }
    LOGI("Context created: %p", context);
    return reinterpret_cast<jlong>(context);
}

JNIEXPORT void JNICALL
Java_com_whatwg_internal_JNIBridge_contextDestroy(JNIEnv *env, jclass clazz, jlong handle) {
    if (handle == 0) return;
    
    auto* context = reinterpret_cast<whatwg_context_t*>(handle);
    LOGI("Destroying context: %p", context);
    whatwg_context_destroy(context);
}

JNIEXPORT jstring JNICALL
Java_com_whatwg_internal_JNIBridge_contextEvaluate(
    JNIEnv *env, jclass clazz, jlong handle, jstring script
) {
    if (handle == 0 || script == nullptr) return nullptr;
    
    auto* context = reinterpret_cast<whatwg_context_t*>(handle);
    const char* scriptCStr = env->GetStringUTFChars(script, nullptr);
    size_t scriptLen = env->GetStringUTFLength(script);
    
    char* resultPtr = nullptr;
    size_t resultLen = 0;
    
    int status = whatwg_context_evaluate(
        context,
        scriptCStr,
        scriptLen,
        &resultPtr,
        &resultLen
    );
    
    env->ReleaseStringUTFChars(script, scriptCStr);
    
    if (status != 0 || resultPtr == nullptr) {
        LOGE("Script evaluation failed with status: %d", status);
        return nullptr;
    }
    
    jstring result = env->NewStringUTF(resultPtr);
    whatwg_free(resultPtr);
    
    return result;
}

JNIEXPORT void JNICALL
Java_com_whatwg_internal_JNIBridge_contextRunEventLoop(JNIEnv *env, jclass clazz, jlong handle) {
    if (handle == 0) return;
    
    auto* context = reinterpret_cast<whatwg_context_t*>(handle);
    whatwg_context_run_event_loop(context);
}

JNIEXPORT jboolean JNICALL
Java_com_whatwg_internal_JNIBridge_contextStepEventLoop(JNIEnv *env, jclass clazz, jlong handle) {
    if (handle == 0) return JNI_FALSE;
    
    auto* context = reinterpret_cast<whatwg_context_t*>(handle);
    return whatwg_context_step_event_loop(context) ? JNI_TRUE : JNI_FALSE;
}

// ============================================================================
// VTable Setup (Clipboard)
// ============================================================================

JNIEXPORT void JNICALL
Java_com_whatwg_internal_JNIBridge_setClipboardVTable(
    JNIEnv *env, jclass clazz, jlong handle,
    jobject readTextCallback, jobject writeTextCallback
) {
    if (handle == 0) return;
    
    // VTable setup would store the callbacks and create C function pointers
    // that call back into Java/Kotlin
    // This requires storing JNIEnv and jobject references properly
    
    LOGI("Clipboard VTable set (stub)");
}

// ============================================================================
// VTable Setup (Timer)
// ============================================================================

JNIEXPORT void JNICALL
Java_com_whatwg_internal_JNIBridge_setTimerVTable(
    JNIEnv *env, jclass clazz, jlong handle,
    jobject setTimeoutCallback, jobject setIntervalCallback,
    jobject clearTimeoutCallback, jobject clearIntervalCallback
) {
    if (handle == 0) return;
    
    LOGI("Timer VTable set (stub)");
}

} // extern "C"
