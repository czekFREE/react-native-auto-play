import Foundation

enum ListItemPressCompletionStore {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var completions: [String: () -> Void] =
        [:]

    static func add(_ completion: @escaping () -> Void) -> String {
        let completionId = UUID().uuidString

        lock.lock()
        completions[completionId] = completion
        lock.unlock()

        return completionId
    }

    static func complete(_ completionId: String) {
        lock.lock()
        let completion = completions.removeValue(forKey: completionId)
        lock.unlock()

        guard let completion else { return }

        DispatchQueue.main.async {
            completion()
        }
    }
}
