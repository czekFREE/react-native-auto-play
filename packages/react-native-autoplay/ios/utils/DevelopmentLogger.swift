import Foundation

func logAutoPlayDevelopment(_ message: @autoclosure () -> String) {
    #if DEBUG
        NSLog("%@", message())
    #endif
}
