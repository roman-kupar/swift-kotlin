

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

  // Test generation of Kotlin stubs for primitive types
  @Test
  func testKotlinPrimitiveMappings() throws {
    let source = """
    public func testPrimitives(
        i: Int, i8: Int8, i16: Int16, i32: Int32, i64: Int64,
        u: UInt, u8: UInt8, u16: UInt16, u32: UInt32, u64: UInt64,
        f: Float, d: Double, b: Bool, s: String
    ) -> Void {}
    """

    try assertOutput(
      input: source,
      .ffm,
      .kotlin,
      expectedChunks: [
        """
        object SwiftModule {
          fun testPrimitives(i: Long, i8: Byte, i16: Short, i32: Int, i64: Long, u: ULong, u8: UByte, u16: UShort, u32: UInt, u64: ULong, f: Float, d: Double, b: Boolean, s: String): Unit = TODO("Not implemented")
        }
        """
      ]
    )
  }

  // Test generation of Kotlin stubs for Arrays and Optionals
  @Test
  func testKotlinCollectionAndOptionalMappings() throws {
    let source = """
    public func processArray(items: [Int]) -> [String] { return [] }
    public func processOptional(value: Double?) -> Int32? { return nil }
    """

    try assertOutput(
      input: source,
      .ffm,
      .kotlin,
      expectedChunks: [
        """
        object SwiftModule {
          fun processArray(items: List<Long>): List<String> = TODO("Not implemented")
          fun processOptional(value: Double?): Int? = TODO("Not implemented")
        }
        """
      ]
    )
  }

  // Test generation of Kotlin stubs for Tuples
  @Test
  func testKotlinTupleMappings() throws {
    let source = """
    public func singleTuple(value: (Int)) -> (String) { return "" }
    public func emptyTuple(value: ()) -> () { return () }
    """

    try assertOutput(
      input: source,
      .ffm,
      .kotlin,
      expectedChunks: [
        """
        object SwiftModule {
          fun singleTuple(value: Long): String = TODO("Not implemented")
          fun emptyTuple(value: Unit): Unit = TODO("Not implemented")
        }
        """
      ]
    )
  }

  // Test fallback types (Any, multi-element tuples, etc.)
  @Test
  func testKotlinFallbackMappings() throws {
    let source = """
    public func genericFunc<T>(value: T) -> T { return value }
    """

    try assertOutput(
      input: source,
      .ffm,
      .kotlin,
      expectedChunks: [
        """
        object SwiftModule {
          fun genericFunc(value: Any): Any = TODO("Not implemented")
        }
        """
      ]
    )
  }
}
