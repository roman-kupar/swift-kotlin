

import JExtractSwiftLib
import Testing

@Suite
final class FFMSwift2KotlinTests {
  
  // Test generation of Kotlin stubs for global functions and variables
  @Test
  func testGeneratesKotlinGlobals() throws {
    let source = """
    public var globalState: Bool = true

    public func addNumbers(a: Int, b: Int32) -> Int {
        return a + Int(b)
    }

    public func doNothing() -> Void {}
    """

    try assertOutput(
      input: source,
      .ffm,
      .kotlin,
      expectedChunks: [
        """
        object SwiftModule {
          fun addNumbers(a: Long, b: Int): Long = TODO("Not implemented")
          fun doNothing(): Unit = TODO("Not implemented")
          fun globalState(): Boolean = TODO("Not implemented")
          fun globalState(newValue: Boolean): Unit = TODO("Not implemented")
        }
        """
      ]
    )
  }

  // Test generation of Kotlin stubs for struct
  @Test
  func testGeneratesKotlinStruct() throws {
    let source = """
    public struct MyStruct {
      public var value: Double = 0
      public func multiply(factor: Double) -> Double {
        return value * factor
      }
    }
    """

    try assertOutput(
      input: source,
      .ffm,
      .kotlin,
      expectedChunks: [
        """
        data class MyStruct {
          fun value(): Double = TODO("Not implemented")
          fun value(newValue: Double): Unit = TODO("Not implemented")
          fun multiply(factor: Double): Double = TODO("Not implemented")
        }
        """
      ]
    )
  }

  // Test generation of Kotlin stubs for class
  @Test
  func testGeneratesKotlinClass() throws {
    let source = """
    public class MyClass {
      public init() {}
    }
    """

    try assertOutput(
      input: source,
      .ffm,
      .kotlin,
      expectedChunks: [
        """
        class MyClass {
          fun init(): MyClass = TODO("Not implemented")
        }
        """
      ]
    )
  }
}
