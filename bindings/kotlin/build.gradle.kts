// Top-level build file for WHATWG Android bindings
plugins {
    id("com.android.library") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false
}

allprojects {
    group = "com.whatwg"
    version = "0.1.0"
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}
