pluginManagement {
    includeBuild("../../BuildLogic")
}

dependencyResolutionManagement {
    versionCatalogs {
        create("libs") {
            from(files("../../gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "swift-java-sample"

include(":SwiftKitCore")
project(":SwiftKitCore").projectDir = file("../../SwiftKitCore")

include(":SwiftKitFFM")
project(":SwiftKitFFM").projectDir = file("../../SwiftKitFFM")
