import Foundation
import XCTest

final class VoiceInputRecognitionSessionTests: XCTestCase {
  private final class Probe: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedEvents: [String] = []
    private var recordedOutcomes: [VoiceInputRecognitionOutcome] = []
    let completed = XCTestExpectation(description: "Recognition completes")
    let ended = XCTestExpectation(description: "Recording ends")

    func event(_ event: String) {
      lock.lock()
      recordedEvents.append(event)
      lock.unlock()
      if event == "end" { ended.fulfill() }
    }

    func complete(_ outcome: VoiceInputRecognitionOutcome) {
      lock.lock()
      recordedOutcomes.append(outcome)
      recordedEvents.append("complete")
      lock.unlock()
      completed.fulfill()
    }

    var events: [String] {
      lock.lock()
      defer { lock.unlock() }
      return recordedEvents
    }

    var outcomes: [VoiceInputRecognitionOutcome] {
      lock.lock()
      defer { lock.unlock() }
      return recordedOutcomes
    }
  }

  private func session(
    probe: Probe, maxDuration: TimeInterval = 5, finalizationTimeout: TimeInterval = 0.02
  ) -> VoiceInputRecognitionSession {
    VoiceInputRecognitionSession(
      maxDuration: maxDuration, finalizationTimeout: finalizationTimeout,
      stopRecording: { probe.event("stop") },
      endAudio: { probe.event("end") },
      cancelRecognition: { probe.event("cancel") },
      complete: { probe.complete($0) })
  }

  func testStopReleasesMicrophoneBeforeWaitingForFinalTranscription() {
    let probe = Probe()
    let session = session(probe: probe, finalizationTimeout: 1)
    session.begin()
    session.finishRecording()
    wait(for: [probe.ended], timeout: 1)
    XCTAssertEqual(probe.events, ["stop", "end"])
    session.receive(.transcription("Vinohradská 12"))
    wait(for: [probe.completed], timeout: 1)
    XCTAssertEqual(probe.outcomes, [.transcription("Vinohradská 12")])
    XCTAssertEqual(probe.events, ["stop", "end", "cancel", "complete"])
  }

  func testHungRecognizerTimesOutAndReleasesTask() {
    let probe = Probe()
    let session = session(probe: probe)
    session.begin()
    session.finishRecording()
    wait(for: [probe.completed], timeout: 1)
    XCTAssertEqual(probe.outcomes, [.timedOut])
    XCTAssertEqual(probe.events, ["stop", "end", "cancel", "complete"])
  }

  func testRecordingDeadlineWorksWithoutAnyAudioBuffers() {
    let probe = Probe()
    let session = session(probe: probe, maxDuration: 0.01)
    session.begin()
    wait(for: [probe.completed], timeout: 1)
    XCTAssertEqual(probe.outcomes, [.timedOut])
    XCTAssertEqual(probe.events, ["stop", "end", "cancel", "complete"])
  }

  func testCancelDoesNotWaitForRecognitionCallbacks() {
    let probe = Probe()
    let session = session(probe: probe, finalizationTimeout: 10)
    session.begin()
    session.receive(.cancelled)
    wait(for: [probe.completed], timeout: 1)
    XCTAssertEqual(probe.outcomes, [.cancelled])
    XCTAssertEqual(probe.events, ["stop", "cancel", "complete"])
  }

  func testCancelDuringFinalizationDoesNotStopCaptureTwice() {
    let probe = Probe()
    let session = session(probe: probe, finalizationTimeout: 10)
    session.begin()
    session.finishRecording()
    wait(for: [probe.ended], timeout: 1)
    session.receive(.cancelled)
    wait(for: [probe.completed], timeout: 1)
    XCTAssertEqual(probe.outcomes, [.cancelled])
    XCTAssertEqual(probe.events, ["stop", "end", "cancel", "complete"])
  }

  func testFinalTranscriptionStopsCaptureWithoutAnExtraEndAudio() {
    let probe = Probe()
    let session = session(probe: probe)
    session.begin()
    session.receive(.transcription("Dějiny"))
    wait(for: [probe.completed], timeout: 1)
    XCTAssertEqual(probe.outcomes, [.transcription("Dějiny")])
    XCTAssertEqual(probe.events, ["stop", "cancel", "complete"])
  }

  func testCancellationDuringSetupWinsOverLateRecognitionResult() {
    let probe = Probe()
    let session = session(probe: probe)
    session.receive(.cancelled)
    session.receive(.transcription("Late title"))
    session.finishRecording()
    session.begin()
    wait(for: [probe.completed], timeout: 1)
    XCTAssertEqual(probe.outcomes, [.cancelled])
    XCTAssertEqual(probe.events, ["stop", "cancel", "complete"])
  }

  func testRecognitionErrorCompletesOnceBeforeLateFinalAndCancel() {
    let probe = Probe()
    let session = session(probe: probe)
    session.begin()
    session.receive(.failed)
    session.receive(.transcription("Late title"))
    session.receive(.cancelled)
    session.finishRecording()
    wait(for: [probe.completed], timeout: 1)
    let drained = XCTestExpectation(description: "Late callbacks drain")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { drained.fulfill() }
    wait(for: [drained], timeout: 1)
    XCTAssertEqual(probe.outcomes, [.failed])
    XCTAssertEqual(probe.events, ["stop", "cancel", "complete"])
  }
}
