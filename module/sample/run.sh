#!/bin/bash
set -e

# Run from swift-java root
cd "$(dirname "$0")/../.."

ROOT=$(pwd)

echo "=== Step 1: Build SwiftKit JARs ==="
./gradlew :SwiftKitCore:jar :SwiftKitFFM:jar

CORE_JAR=$(find SwiftKitCore/build/libs -name "swiftkit-core*.jar" | head -n 1)
FFM_JAR=$(find SwiftKitFFM/build/libs -name "swiftkit-ffm*.jar" | head -n 1)

if [ -z "$CORE_JAR" ] || [ -z "$FFM_JAR" ]; then
    echo "Error: SwiftKit JARs not found."
    exit 1
fi

echo "Core JAR: $CORE_JAR"
echo "FFM JAR: $FFM_JAR"

echo "=== Step 2: Generate Kotlin + Java FFM bindings ==="
mkdir -p .build/swift-java/kotlin .build/swift-java/swift

swift run swift-java jextract \
    --swift-module TestModule \
    --input-swift module/sample/src/main/swift/Sources/TestModule \
    --output-swift .build/swift-java/swift \
    --output-java .build/swift-java/kotlin \
    --java-package com.example.test \
    --lang kotlin \
    --enable-kotlin-impl

echo "=== Step 3: Build Swift thunk package ==="
rm -rf out/TestModulePkg || true
mkdir -p out/TestModulePkg/Sources/TestModule
cp module/sample/src/main/swift/Sources/TestModule/*.swift out/TestModulePkg/Sources/TestModule/
cp .build/swift-java/swift/*.swift out/TestModulePkg/Sources/TestModule/

# Get the actual package name from root Package.swift
SWIFT_JAVA_PACKAGE_NAME=$(swift package dump-package | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
echo "Root package name: $SWIFT_JAVA_PACKAGE_NAME"

# Get available product names
echo "Available products:"
swift package dump-package | python3 -c "import sys,json; [print(p['name']) for p in json.load(sys.stdin)['products']]"

cat > out/TestModulePkg/Package.swift << PKGEOF
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "TestModulePkg",
    products: [
        .library(name: "TestModule", type: .dynamic, targets: ["TestModule"])
    ],
    dependencies: [
        .package(path: "$ROOT")
    ],
    targets: [
        .target(
            name: "TestModule",
            dependencies: [
                .product(name: "SwiftJava", package: "$SWIFT_JAVA_PACKAGE_NAME"),
                .product(name: "SwiftRuntimeFunctions", package: "$SWIFT_JAVA_PACKAGE_NAME")
            ]
        )
    ]
)
PKGEOF

echo "Package.swift contents:"
cat out/TestModulePkg/Package.swift

cd out/TestModulePkg
swift build
TEST_MODULE_BIN_PATH=$(swift build --show-bin-path)
cd "$ROOT"

echo "=== Step 4: Build SwiftJava native libs ==="
swift build --product SwiftJava
swift build --product SwiftRuntimeFunctions
SPM_BIN_PATH=$(swift build --show-bin-path)

echo "=== Step 5: Compile Java FFM ==="
mkdir -p out/classes
CP="out/classes:${CORE_JAR}:${FFM_JAR}"
javac -cp "$CP" -d out/classes .build/swift-java/kotlin/com/example/test/ffm/*.java

echo "=== Step 6: Compile Kotlin ==="
SWIFT_RUNTIME_PATHS=$(swiftc -print-target-info | python3 -c "import sys, json; print(':'.join(json.load(sys.stdin)['paths']['runtimeLibraryPaths']))")

kotlinc -cp "$CP" -d out/classes \
    .build/swift-java/kotlin/com/example/test/TestModule.kt \
    module/sample/src/main/kotlin/com/example/test/Main.kt

echo "=== Step 7: Run ==="
export LD_LIBRARY_PATH="${TEST_MODULE_BIN_PATH}:${SPM_BIN_PATH}:${SWIFT_RUNTIME_PATHS}:${LD_LIBRARY_PATH}"

echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

kotlin \
    -J--enable-native-access=ALL-UNNAMED \
    -J-Djava.library.path="${TEST_MODULE_BIN_PATH}:${SPM_BIN_PATH}:${SWIFT_RUNTIME_PATHS}" \
    -cp "out/classes:${CORE_JAR}:${FFM_JAR}" \
    com.example.test.MainKt