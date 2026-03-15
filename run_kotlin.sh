#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Create a clean output directory
mkdir -p out

# 2. Find the exact paths to the compiled SwiftKit JARs
CORE_JAR=$(find SwiftKitCore/build/libs -name "swiftkit-core*.jar" | head -n 1)
FFM_JAR=$(find SwiftKitFFM/build/libs -name "swiftkit-ffm*.jar" | head -n 1)

if [ -z "$CORE_JAR" ] || [ -z "$FFM_JAR" ]; then
    echo "Error: SwiftKit JARs not found. Please run './gradlew :SwiftKitCore:jar :SwiftKitFFM:jar' first."
    exit 1
fi

# Create the classpath string (no wildcards, to make kotlinc happy)
CP="out:${CORE_JAR}:${FFM_JAR}"
echo "Using Classpath: $CP"

# 3. Compile the Java FFM boilerplate
echo "Compiling Java FFM..."
javac -cp "$CP" -d out .build/swift-java/kotlin/com/example/test/ffm/*.java

echo "Creating Main.kt..."
cat <<EOF > out/Main.kt
package com.example.test

fun main() {
    println("Calling Swift from Kotlin! Result of addNumbers: " + TestModule.addNumbers(10L, 20))
}
EOF

# 4. Compile the Kotlin facade AND the new Main file
echo "Compiling Kotlin facade and Main.kt..."
kotlinc -cp "$CP" -d out .build/swift-java/kotlin/com/example/test/TestModule.kt out/Main.kt

# Get the Swift runtime library paths dynamically using swiftc and python
SWIFT_RUNTIME_PATHS=$(swiftc -print-target-info | python3 -c "import sys, json; print(':'.join(json.load(sys.stdin)['paths']['runtimeLibraryPaths']))")

# Get the Swift Package Manager build directory (where libSwiftJava.so is located)
SPM_BIN_PATH=$(swift build --show-bin-path)

# Ensure the core Swift libraries are actually built
echo "Building Swift libraries..."
swift build --product SwiftJava
swift build --product SwiftRuntimeFunctions

echo "Creating a standalone Swift package for TestModule..."
mkdir -p out/TestModulePkg/Sources/TestModule
cp Samples/TestModule/*.swift out/TestModulePkg/Sources/TestModule/
cp .build/swift-java/swift/*.swift out/TestModulePkg/Sources/TestModule/

cat <<EOF > out/TestModulePkg/Package.swift
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "TestModulePkg",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TestModule", type: .dynamic, targets: ["TestModule"])
    ],
    dependencies: [
        .package(path: "$(pwd)")
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
EOF

echo "Building TestModule via SPM..."
cd out/TestModulePkg
swift build
TEST_MODULE_BIN_PATH=$(swift build --show-bin-path)
cd ../..

# The OS dynamic linker needs to know where these are to resolve transitive dependencies
export LD_LIBRARY_PATH="${TEST_MODULE_BIN_PATH}:${SPM_BIN_PATH}:${SWIFT_RUNTIME_PATHS}:${LD_LIBRARY_PATH}"

# 5. Run the application
echo "Running Kotlin application..."
kotlin -J--enable-native-access=ALL-UNNAMED \
       -J-Djava.library.path="${TEST_MODULE_BIN_PATH}:${SPM_BIN_PATH}:${SWIFT_RUNTIME_PATHS}" \
       -cp "$CP" \
       com.example.test.MainKt