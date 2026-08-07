import Foundation

enum AutoPlayDevelopmentLogger {
    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
            NSLog("%@", message())
        #endif
    }
}
