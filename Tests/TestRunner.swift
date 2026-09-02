// Test entry point. No XCTest; exits with 1 on any failure.
// Run: ./test.sh

import Foundation

var failures = 0

func check(_ condition: Bool, _ name: String, line: Int = #line) {
    if condition {
        print("ok   \(name)")
    } else {
        failures += 1
        print("FAIL \(name) (line \(line))")
    }
}

@main
struct TestRunner {
    static func main() {
        GeometryTests.run()
        DoubleTapTests.run()

        if failures == 0 {
            print("all passed")
            exit(0)
        } else {
            print("\(failures) failed")
            exit(1)
        }
    }
}
