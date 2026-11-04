import CarPlay
import CoreMedia
import XCTest

@available(iOS 26.4, *)
@MainActor
final class PlaybackConfigurationTests: XCTestCase {
  func testTrackElementPresentsAudioWithItsPlaybackTimes() throws {
    let element = CPListImageRowItemCondensedElement(
      image: UIImage(),
      imageShape: .roundedRectangle,
      title: "Episode",
      subtitle: "Podcast",
      accessorySymbolName: nil
    )

    configurePlaybackConfiguration(item: element, duration: 180, elapsedTime: 24)

    let configuration = try XCTUnwrap(element.playbackConfiguration)
    XCTAssertEqual(configuration.preferredPresentation, .audio)
    XCTAssertEqual(configuration.playbackAction, .play)
    XCTAssertEqual(configuration.duration.seconds, 180)
    XCTAssertEqual(configuration.elapsedTime.seconds, 24)
  }

  func testNormalTrackRowsUseTheSameAudioConfiguration() throws {
    let item = CPListItem(text: "Episode", detailText: "Podcast")

    configurePlaybackConfiguration(item: item, duration: 120, elapsedTime: 40)

    let configuration = try XCTUnwrap(item.playbackConfiguration)
    XCTAssertEqual(configuration.preferredPresentation, .audio)
    XCTAssertEqual(configuration.playbackAction, .play)
    XCTAssertEqual(configuration.duration.seconds, 120)
    XCTAssertEqual(configuration.elapsedTime.seconds, 40)
  }

  func testElapsedTimeIsClampedToThePlayableRange() throws {
    let item = CPListImageRowItemRowElement(image: UIImage(), title: "Episode", subtitle: nil)

    for (elapsedTime, expected) in [(-10.0, 0.0), (200.0, 120.0)] {
      configurePlaybackConfiguration(item: item, duration: 120, elapsedTime: elapsedTime)

      XCTAssertEqual(try XCTUnwrap(item.playbackConfiguration).elapsedTime.seconds, expected)
    }
  }

  func testZeroDurationStillRequestsAudioPresentation() throws {
    let item = CPListImageRowItemGridElement(image: UIImage())

    configurePlaybackConfiguration(item: item, duration: 0, elapsedTime: 10)

    let configuration = try XCTUnwrap(item.playbackConfiguration)
    XCTAssertEqual(configuration.preferredPresentation, .audio)
    XCTAssertEqual(configuration.duration.seconds, 0)
    XCTAssertEqual(configuration.elapsedTime.seconds, 0)
  }

  func testShowAndStatusElementsHaveNoPlaybackConfiguration() {
    let item = CPListImageRowItemRowElement(image: UIImage(), title: "Show", subtitle: nil)
    configurePlaybackConfiguration(item: item, duration: 120, elapsedTime: 40)
    XCTAssertEqual(item.playbackConfiguration?.preferredPresentation, .audio)

    configurePlaybackConfiguration(item: item, duration: nil, elapsedTime: nil)

    XCTAssertNil(item.playbackConfiguration)
  }

  func testIncompleteAndInvalidTimesClearPreviousConfiguration() {
    let item = CPListItem(text: "Episode", detailText: nil)
    let invalidTimes: [(Double?, Double?)] = [
      (nil, 0), (120, nil), (-1, 0), (.infinity, 0), (.nan, 0),
      (120, .infinity), (120, .nan),
    ]

    for (duration, elapsedTime) in invalidTimes {
      configurePlaybackConfiguration(item: item, duration: 120, elapsedTime: 20)
      XCTAssertEqual(item.playbackConfiguration?.preferredPresentation, .audio)

      configurePlaybackConfiguration(item: item, duration: duration, elapsedTime: elapsedTime)

      XCTAssertNil(item.playbackConfiguration)
    }
  }
}
