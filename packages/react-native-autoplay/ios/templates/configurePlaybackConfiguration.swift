import CarPlay
import CoreMedia

@available(iOS 26.4, *)
func configurePlaybackConfiguration(
    item: any CPPlayableItem,
    duration: Double?,
    elapsedTime: Double?
) {
    guard let duration, let elapsedTime,
        duration.isFinite,
        elapsedTime.isFinite,
        duration >= 0
    else {
        item.playbackConfiguration = nil
        return
    }

    item.playbackConfiguration = CPPlaybackConfiguration(
        preferredPresentation: .audio,
        playbackAction: .play,
        elapsedTime: CMTime(
            seconds: min(max(elapsedTime, 0), duration),
            preferredTimescale: 1_000
        ),
        duration: CMTime(seconds: duration, preferredTimescale: 1_000)
    )
}
