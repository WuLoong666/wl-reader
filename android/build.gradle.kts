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
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension>("android") {
            compileSdk = 36
        }
    }
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
            compileSdk = 36
        }
    }
    afterEvaluate {
        extensions.findByName("android")?.let { androidExtension ->
            when (androidExtension) {
                is com.android.build.api.dsl.ApplicationExtension -> androidExtension.compileSdk = 36
                is com.android.build.api.dsl.LibraryExtension -> androidExtension.compileSdk = 36
            }
        }
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
