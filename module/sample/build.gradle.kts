import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    kotlin("jvm") version "2.1.20"
    application
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(project(":SwiftKitCore"))
    implementation(project(":SwiftKitFFM"))
}

kotlin {
    jvmToolchain(25)
}

sourceSets {
    main {
        kotlin.srcDirs("src/main/kotlin", "build/generated/kotlin")
        java.srcDirs("src/main/java", "build/generated/java")
    }
}

val generateBindings = tasks.register<Exec>("generateBindings") {
    val outJavaDir = file("build/generated/java")
    val outSwiftDir = file("build/generated/swift")
    doFirst {
        outJavaDir.mkdirs()
        outSwiftDir.mkdirs()
    }
    workingDir = file("../../")
    commandLine(
        "swift", "run", "swift-java", "jextract",
        "--swift-module", "TestModule",
        "--input-swift", "${projectDir}/src/main/swift/Sources/TestModule",
        "--output-swift", outSwiftDir.absolutePath,
        "--output-java", outJavaDir.absolutePath,
        "--java-package", "com.example.test",
        "--lang", "kotlin",
        "--enable-kotlin-impl"
    )
}

val prepareSwiftPackage = tasks.register<Copy>("prepareSwiftPackage") {
    dependsOn(generateBindings)

    val pkgDir = file("build/TestModulePkg/Sources/TestModule")
    doFirst { pkgDir.mkdirs() }

    // Copy Swift source files
    from("src/main/swift/Sources/TestModule")
    // Copy generated thunks
    from("build/generated/swift")
    into(pkgDir)

    doLast {
        // Write Package.swift
        val root = file("../../").absolutePath
        file("build/TestModulePkg/Package.swift").writeText("""
            // swift-tools-version: 6.0
            import PackageDescription
            let package = Package(
                name: "TestModulePkg",
                products: [
                    .library(name: "TestModule", type: .dynamic, targets: ["TestModule"])
                ],
                dependencies: [
                    .package(path: "$root")
                ],
                targets: [
                    .target(
                        name: "TestModule",
                        dependencies: [
                            .product(name: "SwiftJava", package: "swift-java"),
                            .product(name: "SwiftRuntimeFunctions", package: "swift-java")
                        ]
                    )
                ]
            )
        """.trimIndent())
    }
}

val buildSwiftPackage = tasks.register<Exec>("buildSwiftPackage") {
    dependsOn(prepareSwiftPackage)
    workingDir = file("build/TestModulePkg")
    commandLine("swift", "build")
}

val buildSwiftJavaLibs = tasks.register<Exec>("buildSwiftJavaLibs") {
    workingDir = file("../../")
    commandLine("swift", "build", "--product", "SwiftJava")
}

val buildSwiftRuntimeFunctions = tasks.register<Exec>("buildSwiftRuntimeFunctions") {
    workingDir = file("../../")
    commandLine("swift", "build", "--product", "SwiftRuntimeFunctions")
}

tasks.withType<JavaCompile>().configureEach {
    dependsOn(generateBindings)
}

tasks.withType<KotlinCompile>().configureEach {
    dependsOn(generateBindings)
}

application {
    mainClass.set("com.example.test.MainKt")
    applicationDefaultJvmArgs = listOf("--enable-native-access=ALL-UNNAMED")
}

tasks.named<JavaExec>("run") {
    dependsOn(buildSwiftPackage, buildSwiftJavaLibs, buildSwiftRuntimeFunctions)

    doFirst {
        val testModuleBinPath = ProcessBuilder("swift", "build", "--show-bin-path")
            .directory(file("build/TestModulePkg"))
            .start().inputStream.bufferedReader().readText().trim()

        val spmBinPath = ProcessBuilder("swift", "build", "--show-bin-path")
            .directory(file("../../"))
            .start().inputStream.bufferedReader().readText().trim()

        val swiftRuntimePath = ProcessBuilder(
            "python3", "-c",
            "import sys,json,subprocess; info=json.loads(subprocess.check_output(['swiftc','-print-target-info'])); print(':'.join(info['paths']['runtimeLibraryPaths']))"
        ).start().inputStream.bufferedReader().readText().trim()

        val dynamicLibraryPath = listOf(
            testModuleBinPath,
            spmBinPath,
            swiftRuntimePath,
            System.getenv("LD_LIBRARY_PATH") ?: ""
        ).filter { it.isNotEmpty() }.joinToString(":")

        println("Library path: $dynamicLibraryPath")

        environment("LD_LIBRARY_PATH", dynamicLibraryPath)
        environment("DYLD_LIBRARY_PATH", dynamicLibraryPath)
        systemProperty("java.library.path", dynamicLibraryPath)
    }
}