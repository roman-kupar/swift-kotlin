
public enum JVMTargetLanguage: String, Sendable, Codable {
    
  case java
  case kotlin

  public static var `default`: JVMTargetLanguage { .java }
}
