import org.jetbrains.kotlin.serialization.builtins.main
import org.lwjgl.Lwjgl.Module.*
import org.lwjgl.Release.`3_3_2`
import org.lwjgl.lwjgl

plugins {
    kotlin("jvm") version "2.0.20"

    id("org.lwjgl.plugin") version "0.0.34"
    id("com.gradleup.shadow") version "8.3.5"

    application
    idea
    eclipse
}

group = "fox.samu.gravity"
version = "1.0-SNAPSHOT"

application {
    mainClass = "fox.samu.gravity.MainKt"
}

if (org.gradle.internal.os.OperatingSystem.current().isMacOsX) {
    tasks.run.invoke {
        // This JVM arg is required for it to run on OSX
        jvmArgs("-XstartOnFirstThread")
    }
}

idea {
    module {
        isDownloadSources = true
    }
}

eclipse {
    classpath {
        isDownloadSources = true
    }
}

repositories {
    mavenCentral()
}

dependencies {
    lwjgl {
        version = `3_3_2`
        implementation(core, opengl, glfw, stb)
    }

    implementation("org.joml:joml:1.10.7")
}

kotlin {
    jvmToolchain(17)
}

tasks.test {
    useJUnitPlatform()
}
