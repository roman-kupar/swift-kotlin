package com.example.test

fun main() {
    println("addNumbers(3, 4) = ${TestModule.addNumbers(3, 4)}")
    println("isEnabled() = ${TestModule.isEnabled()}")
    TestModule.doNothing()
    println("done")
}