
public enum JExtractLanguageMode: String, Sendable, Codable {

  case java
  case kotlin

  public static var `default`: JExtractLanguageMode { .kotlin }
}
