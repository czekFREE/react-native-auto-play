import CarPlay
import CoreMedia

struct PlaybackConfigurationTimes {
    let duration: Double
    let elapsedTime: Double

    init?(duration: Double?, elapsedTime: Double?) {
        guard let duration, let elapsedTime,
            duration.isFinite,
            elapsedTime.isFinite,
            duration >= 0
        else { return nil }

        self.duration = duration
        self.elapsedTime = min(max(elapsedTime, 0), duration)
    }
}

@available(iOS 26.4, *)
func configurePlaybackConfiguration(
    item: any CPPlayableItem,
    duration: Double?,
    elapsedTime: Double?
) {
    guard let times = PlaybackConfigurationTimes(duration: duration, elapsedTime: elapsedTime)
    else {
        item.playbackConfiguration = nil
        return
    }

    item.playbackConfiguration = CPPlaybackConfiguration(
        preferredPresentation: .audio,
        playbackAction: .play,
        elapsedTime: CMTime(
            seconds: times.elapsedTime,
            preferredTimescale: 1_000
        ),
        duration: CMTime(seconds: times.duration, preferredTimescale: 1_000)
    )
}
