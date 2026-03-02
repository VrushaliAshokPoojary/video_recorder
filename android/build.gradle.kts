allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    // Compatibility patch for legacy plugins (e.g. flutter_ffmpeg 0.4.2)
    // that do not declare `android.namespace`, which AGP 8+ requires.
    if (name == "flutter_ffmpeg") {
        plugins.withId("com.android.library") {
            val androidExtension = extensions.findByName("android")
            if (androidExtension is com.android.build.gradle.LibraryExtension && androidExtension.namespace.isNullOrBlank()) {
                androidExtension.namespace = "com.arthenica.flutter.ffmpeg"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
