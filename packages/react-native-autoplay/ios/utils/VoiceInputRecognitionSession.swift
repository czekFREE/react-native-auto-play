import Foundation

enum VoiceInputRecognitionOutcome: Equatable {
    case transcription(String)
    case failed
    case cancelled
    case timedOut
}

final class VoiceInputRecognitionSession: @unchecked Sendable {
    // The private queue owns the state, deadlines, and completion callbacks.
    private enum PendingEvent {
        case finishRecording
        case result(VoiceInputRecognitionOutcome)
    }

    private enum State {
        case preparing(PendingEvent?)
        case recording
        case finalizing
        case settled
    }

    private let queue = DispatchQueue(label: "com.iternio.autoplay.voice-recognition")
    private var state = State.preparing(nil)
    private var recordingDeadline: DispatchWorkItem?
    private var finalizationDeadline: DispatchWorkItem?
    private let maxDuration: TimeInterval
    private let finalizationTimeout: TimeInterval
    private let stopRecording: () -> Void
    private let endAudio: () -> Void
    private let cancelRecognition: () -> Void
    private let complete: (VoiceInputRecognitionOutcome) -> Void

    init(
        maxDuration: TimeInterval,
        finalizationTimeout: TimeInterval = 2,
        stopRecording: @escaping () -> Void,
        endAudio: @escaping () -> Void,
        cancelRecognition: @escaping () -> Void,
        complete: @escaping (VoiceInputRecognitionOutcome) -> Void
    ) {
        self.maxDuration = maxDuration.isFinite ? max(0, maxDuration) : 10
        self.finalizationTimeout = finalizationTimeout.isFinite ? max(0, finalizationTimeout) : 2
        self.stopRecording = stopRecording
        self.endAudio = endAudio
        self.cancelRecognition = cancelRecognition
        self.complete = complete
    }

    func begin() {
        queue.async { [self] in
            guard case .preparing(let pending) = self.state else { return }
            self.state = .recording
            let deadline = DispatchWorkItem { [weak self] in self?.finishRecordingOnQueue() }
            self.recordingDeadline = deadline
            self.queue.asyncAfter(deadline: .now() + self.maxDuration, execute: deadline)
            switch pending {
            case .finishRecording: self.finishRecordingOnQueue()
            case .result(let outcome): self.settleOnQueue(outcome)
            case nil: break
            }
        }
    }

    func finishRecording() {
        queue.async { self.finishRecordingOnQueue() }
    }

    func receive(_ outcome: VoiceInputRecognitionOutcome) {
        queue.async { self.settleOnQueue(outcome) }
    }

    func abandon() {
        queue.async {
            self.state = .settled
            self.recordingDeadline?.cancel()
            self.finalizationDeadline?.cancel()
        }
    }

    private func finishRecordingOnQueue() {
        switch state {
        case .preparing(nil): state = .preparing(.finishRecording)
        case .recording:
            state = .finalizing
            recordingDeadline?.cancel()
            stopRecording()
            let deadline = DispatchWorkItem { [weak self] in self?.settleOnQueue(.timedOut) }
            finalizationDeadline = deadline
            queue.asyncAfter(deadline: .now() + finalizationTimeout, execute: deadline)
            endAudio()
        case .preparing, .finalizing, .settled: break
        }
    }

    private func settleOnQueue(_ outcome: VoiceInputRecognitionOutcome) {
        let mustStopRecording: Bool
        switch state {
        case .preparing(let pending):
            if outcome == .cancelled {
                state = .preparing(.result(outcome))
            }
            else if case .result = pending {
                return
            }
            else {
                state = .preparing(.result(outcome))
            }
            return
        case .recording: mustStopRecording = true
        case .finalizing: mustStopRecording = false
        case .settled: return
        }
        state = .settled
        recordingDeadline?.cancel()
        finalizationDeadline?.cancel()
        if mustStopRecording { stopRecording() }
        cancelRecognition()
        complete(outcome)
    }
}
