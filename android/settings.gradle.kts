pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

gradle.beforeProject {
    val project = this
    project.afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android != null) {
            var success = false
            val errors = mutableListOf<String>()
            for (methodName in listOf("setCompileSdk", "compileSdk", "setCompileSdkVersion", "compileSdkVersion")) {
                for (paramType in listOf(Int::class.javaPrimitiveType, java.lang.Integer::class.java)) {
                    if (paramType != null) {
                        try {
                            val method = android.javaClass.getMethod(methodName, paramType)
                            method.invoke(android, 36)
                            success = true
                            break
                        } catch (e: Exception) {
                            errors.add("$methodName(${paramType.name}): ${e.message}")
                        }
                    }
                }
                if (success) break
            }
            if (!success) {
                println("Failed to set compileSdkVersion for ${project.name}: ${errors.joinToString(", ")}")
            } else {
                println("Successfully set compileSdkVersion to 36 for project ${project.name}")
            }
        }
    }
}
