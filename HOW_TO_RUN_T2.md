# How to generate actual Kotlin implementation (aka. delegation to Swift libraries) (T2)

To generate Kotlin source code with actual implementation instead of `TODO()` stubs, I created a special `Proof of concept` at `module/sample` with integrated `Gradle` and showcase.

You can find `Main.kt` at `module/sample/src/main/kotlin/com/example/test/Main.kt`, which wants to use some external functions, defined at `TestModule.swift` (e.g addNumbers).

For that purpose, first we need to actually generate a Kotlin source, that would delegate itself to Swift implementation.

### Automated Execution via Gradle

The entire process of generating the bindings, building the native Swift library, compiling the Kotlin/Java code, and linking them together at runtime is fully automated via the Gradle script (`build.gradle.kts`).

To run the sample:
### From root
```bash
 ./gradlew :module:sample:run
```

*(Note: The first run might take a moment as it needs to build the Swift package dependencies).*

### What happens under the hood?

When you execute the `run` task, Gradle performs the following steps in sequence:

1. **Generates Bindings (`generateBindings` task):**
   It invokes the `swift-java jextract` CLI with the `--lang kotlin` and `--enable-kotlin-impl` flags. 
   * This generates the idiomatic Kotlin facade in `build/generated/kotlin`.
   * It generates the low-level Java FFM memory layouts and method handles in `build/generated/java`.
   * It generates the intermediate Swift `@_cdecl` thunks in `build/generated/swift` to bridge the calling conventions.
   
2. **Builds the Native Library (`buildSwiftPackage` task):**
   It bundles your original `TestModule.swift` together with the newly generated Swift thunks and compiles them into a single dynamic library (`.dylib` or `.so`) using Swift Package Manager.

3. **Compiles Kotlin & Java:**
   The Kotlin compiler compiles `Main.kt` alongside the dynamically generated Kotlin facade and Java FFM bindings.

4. **Executes the Application (`run` task):**
   It launches the JVM with the required Foreign Function & Memory (FFM) API flags (`--enable-native-access=ALL-UNNAMED`). Finally, it dynamically locates the newly built Swift native library and injects it into `java.library.path`, `LD_LIBRARY_PATH`, and `DYLD_LIBRARY_PATH` so the JVM can successfully call into your Swift code at runtime