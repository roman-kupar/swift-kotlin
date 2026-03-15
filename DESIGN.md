# Swift-to-Kotlin Interop  
## Overview

This fork extends [swift-java](https://github.com/swiftlang/swift-java) repo with a new
`--lang kotlin` mode that generates Kotlin source files from Swift modules, and `--enable-kotlin-impl`
bridging Swift native code to the Kotlin/JVM ecosystem via the existing
Foreign Function & Memory (FFM) layer.

---

## What Was Built

### Kotlin Source Generation

A new `FFMSwift2KotlinGenerator` class (subclass of `FFMSwift2JavaGenerator`)
that generates `.kt` files instead of `.java` files.

**New CLI flags:**
- `--lang kotlin` — activates Kotlin generation mode, stubs the implementation with `TODO()`s.
- `--enable-kotlin-impl` — generates real FFM delegation instead of `TODO()` stubs.

**Two generation modes:**

*Stub mode* (`--lang kotlin`):

```swift
// TestInput.swift
public func addNumbers(a: Int, b: Int32) -> Int {
    return a + Int(b)
}
public func isEnabled() -> Bool {
    return true
}
public func doNothing() -> Void {}
```
↓   
```kotlin
// TestModule.kt
object TestModule {
    fun addNumbers(a: Long, b: Int): Long = TODO("Not implemented")
    fun isEnabled(): Boolean = TODO("Not implemented")
    fun doNothing(): Unit = TODO("Not implemented")
}
```
---
*Impl mode* (`--lang kotlin --enable-kotlin-impl`):
```kotlin
object TestModule {
    fun addNumbers(a: Long, b: Int): Long {
        return TestModuleFFM.addNumbers(a, b)
    }
    fun isEnabled(): Boolean {
        return TestModuleFFM.isEnabled()
    }
    fun doNothing(): Unit {
        TestModuleFFM.doNothing()
    }
}
```
**New tests for Kotlin Code generation**
- New tests were included in Tests/JExtractSwiftTests/SwiftKotlin
- They could be run exclusively with:
```bash
 swift test --disable-experimental-prebuilts --filter FFMSwift2KotlinTests
```

**Type mapping (Swift -> Kotlin):**

| Swift     | Kotlin    |
|-----------|-----------|
| `Int`     | `Long`    |
| `Int32`   | `Int`     |
| `Int64`   | `Long`    |
| `Int8`    | `Byte`    |
| `Int16`   | `Short`   |
| `UInt`    | `ULong`   |
| `Bool`    | `Boolean` |
| `Double`  | `Double`  |
| `Float`   | `Float`   |
| `String`  | `String`  |
| `Void`/`()` | `Unit`  |
| `T?`      | `T?`      |
| `[T]`     | `List<T>` |

**Key implementation decisions:**

- `FFMSwift2KotlinGenerator` subclasses `FFMSwift2JavaGenerator` rather than
  being a standalone generator. This was the pragmatic choice - the existing
  class handles Swift analysis, thunk generation, and file I/O. 
- **Kotlin facade - Java core**: when `--enable-kotlin-impl` is set, the FFM Java glue is generated into
  a `.ffm` sub-package (`com.example.test.ffm`) and the Kotlin facade
  delegates to it. This keeps the Kotlin API clean while reusing the
  existing Java FFM infrastructure.
- Extension with `JExtractLanguageMode` enum (`java`/`kotlin`)

## Why FFM?
The project already had a solid FFM implementation handling all the hard parts -
Swift calling convention thunks, symbol lookup, memory layout, arena lifetimes.
Building the Kotlin layer on top of that meant I could focus entirely on
"what does idiomatic Kotlin look like for this Swift API" rather than
"how do I call a Swift function from the JVM."

JNI was the alternative. It's more portable and works on Android, but it needs
more boilerplate on both sides and forces data copies at the boundary.
FFM gives direct native memory access and a much cleaner API surface.
Since swift-java already requires JDK 22+, there was no reason to go back to JNI.


## What Could Be Done With More Time and Resources

- **A standalone `KotlinGenerator`.** Right now `FFMSwift2KotlinGenerator`
extends `FFMSwift2JavaGenerator`. It works, but it's coupled to Java generator
internals in ways that could make it fragile for future maintance. A generator that takes `AnalysisResult`
directly and knows nothing about Java would be much cleaner.

- **String and Array bridging.** A small `SwiftKitKotlin` runtime library with
helpers for Swift/Kotlin string conversion would unlock most real-world use cases.

- **JNI Integration.** `--lang kotlin --mode jni` would generate Kotlin that delegates
to JNI glue instead of FFM, enabling Android support. That's probably the most
impactful missing feature given how important Android is for Kotlin developers.

- **Kotlin Multiplatform.** The generator could emit `expect`/`actual` declarations -
JVM backed by FFM, native backed by direct Swift interop. That would be the ideal
end state for a library author who wants to ship both Android and server-side JVM
from the same Swift codebase.

- **A proper Gradle plugin.** The sample's `build.gradle.kts` manually wires up
five separate steps. Packaging that as a plugin would make it a one-liner
to add to any project.

- Optimistically **Coroutines.** Swift `async` -> Kotlin `suspend` is a research problem but
a very appealing one. Swift's structured concurrency and Kotlin coroutines
have enough in common that a clean mapping feels possible.

---

## Trade-offs and Corners Cut

### Intentionally cut
- **No `String` for Kotlin Implementaion** - `String` bridging across
  the FFM boundary requires `MemorySegment` marshalling which is significantly
  more complex. It still works for stubbing and raw kotlin generation, but it doesn't delegate when `--enable-kotlin-impl` is set.
- **No nominal type (struct/class) support** - only top-level functions are
  demonstrated. Nominal types require heap layout, witness tables, and arena
  management.
- **No `--output-kotlin` separate flag** - Kotlin and Java FFM files share
  the `--output-java` directory, differentiated by sub-package (`ffm/`) and
  file extension (`.kt` vs `.java`). But of course a dedicated flag would be cleaner.
- **Stub mode generates Java-style output** - the stub `.kt` file still
  uses Java imports and boilerplate inherited from the base generator.
  A clean Kotlin stub should have no Java imports at all.
- **`--lang kotlin` doesn't change `effectiveMode` in debug log** - the log
  still prints `mode: ffm` which is technically correct (the transport is FFM)
  but confusing.

### Trade-offs
- **Subclassing vs. standalone generator** - subclassing `FFMSwift2JavaGenerator`
  was faster but creates tight coupling. A standalone `KotlinGenerator` that
  takes `AnalysisResult` directly would be cleaner and more maintainable.
- **Mixed-language generation** - generating Java FFM bindings alongside the Kotlin facade requires consuming projects to compile both languages. A "pure Kotlin" approach would avoid it, but it requires completely rewriting complex FFM generation logic.
- **Strict primitive mapping** - mapping Swift's `Int` (64-bit) to Kotlin's `Long` prevents data truncation at the FFM boundary, though it forces Kotlin developers to use `Long` instead of the more idiomatic `Int`.

---

## What I Would Do Next

1. Add snapshot tests for the Kotlin generator
2. Add `--output-kotlin` CLI flag to separate Kotlin from Java output
3. Refactor `FFMSwift2KotlinGenerator` into a standalone class
4. Add more unit-tests for testing the Generator.
5. Document the `--lang kotlin` flag in the main `README.md`
6. Add the sample to CI