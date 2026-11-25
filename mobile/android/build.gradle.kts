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
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            val android = extensions.getByName("android") as com.android.build.gradle.LibraryExtension
            android.compileSdk = 37
            if (android.namespace == null) {
                // Tự động tạo namespace hợp lệ nếu thư viện bị thiếu
                val fallbackGroup = if (group.toString().isNotEmpty()) group.toString() else "com.example"
                android.namespace = "$fallbackGroup.${project.name.replace("-", "_")}"
            }
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val content = manifestFile.readText()
                if (content.contains("package=")) {
                    val updatedContent = content.replace(Regex("""package="[^"]*""""), "")
                    manifestFile.writeText(updatedContent)
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
