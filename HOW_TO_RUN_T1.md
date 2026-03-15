# How to Generate Kotlin Stubs (T1)

To generate Kotlin source code with `TODO()` stubs from a Swift file (like `TestInput.swift`), you can use the `jextract` subcommand with the `--lang kotlin` flag. 

Run the following command from the root of the `swift-java` project:

```bash
swift run swift-java jextract --swift-module TestModule  --input-swift Samples/TestModule --output-swift .build/swift-java/swift --output-java .build/swift-java/kotlin --java-package com.example.test --lang kotlin
```

The generated kotlin source code you will see at `.build/swift-java/kotlin` - `TestModule.kt`
The `.build/swift-java/swift` will include the intermidiate Swift "thunks" (C-callable wrappers using @_cdecl)

You can run tests for stubs with: 
```bash
swift test --disable-experimental-prebuilts --filter FFMSwift2KotlinTests
```
This will exclusively run the tests at Tests/JExtractSwiftTests/SwiftKotlin
These unit-tests provide verification for basic mappings of types/signatures like Void -> Unit, etc.