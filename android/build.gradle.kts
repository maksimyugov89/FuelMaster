buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.4.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")
        classpath("com.google.gms:google-services:4.4.3")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
    }
}

allprojects {
    configurations.all {
        resolutionStrategy {
            force("net.bytebuddy:byte-buddy:1.14.5")
            force("net.bytebuddy:byte-buddy-agent:1.14.5")
        }
    }
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://android-sdk.is.com/") }
        maven { url = uri("https://artifact.bytedance.com/repository/pangle") }
        maven { url = uri("https://sdk.tapjoy.com/") }
        maven { url = uri("https://dl-maven-android.mintegral.com/repository/mbridge_android_sdk_oversea") }
        maven { url = uri("https://cboost.jfrog.io/artifactory/chartboost-ads/") }
        
        // v--- ИСПРАВЛЕННЫЙ АДРЕС РЕПОЗИТОРИЯ ЯНДЕКСА ---v
        maven { url = uri("https://maven.yandex.ru/repository/yandex_sdk/") }
        // ^-------------------------------------------------^
        
        maven { url = uri("https://artifactory.appodeal.com/appodeal") }
        maven { url = uri("https://dl.appnext.com/") }
        maven { url = uri("https://developer.huawei.com/repo/") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

tasks.register<Delete>("cleanBuildCache") {
    delete(fileTree(gradle.gradleUserHomeDir) { include("caches/**") })
    delete(fileTree(projectDir) { include("build/**") })
}