import AVFoundation
import CryptoKit
import Foundation
import OSLog

/// Plays the bundled guide once; a changed or missing recording falls back to the device voice.
/// Audio-session work is serialized off the main actor. The request token cancels late starts.
@MainActor
final class PracticeNarrationPlayer: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    var onError: ((String) -> Void)?
    var onInterruption: (() -> Void)?

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.tend.app", category: "Narration")
    private let script: String
    private let audioURL: URL?
    private var recording: AVAudioPlayer?
    private var speech: AVSpeechSynthesizer?
    private static let sessionQueue = DispatchQueue(label: "Tend.NarrationSession", qos: .userInitiated)
    private var request = 0
    private var wantsPlayback = false
    private var hasSpoken = false
    private var completed = false
    private var triedRecording = false
    private var observers: [NSObjectProtocol] = []

    init(practiceID: String, script: String, bundle: Bundle = .main) {
        self.script = script
        audioURL = Self.recordingURL(practiceID: practiceID, script: script, bundle: bundle)
        super.init()
        observeAudioChanges()
    }

    isolated deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    func resume() {
        guard !completed, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        wantsPlayback = true
        request += 1
        let expectedRequest = request
        Self.sessionQueue.async { [weak self] in
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
                try session.setActive(true)
                Task { @MainActor [weak self] in
                    guard let self, self.request == expectedRequest, self.wantsPlayback else { return }
                    self.playPreparedGuide()
                }
            } catch {
                Task { @MainActor [weak self] in
                    guard let self, self.request == expectedRequest, self.wantsPlayback else { return }
                    self.onError?("Audio is unavailable. You can follow the written steps.")
                }
            }
        }
    }

    func pause() {
        wantsPlayback = false
        recording?.pause()
        if speech?.isSpeaking == true { speech?.pauseSpeaking(at: .immediate) }
        deactivateSession()
    }

    /// Turning the guide off or ending a practice resets narration for the next explicit start.
    func stop() {
        pause()
        recording?.stop()
        recording?.currentTime = 0
        speech?.stopSpeaking(at: .immediate)
        hasSpoken = false
        completed = false
    }

    private func playPreparedGuide() {
        if !triedRecording {
            triedRecording = true
            if let audioURL {
                do {
                    let player = try AVAudioPlayer(contentsOf: audioURL)
                    player.delegate = self
                    guard player.prepareToPlay() else { throw NarrationError.cannotPrepare }
                    recording = player
                } catch {
                    onError?("Using the device voice for this guide.")
                }
            }
        }
        if let recording {
            if recording.play() {
                Self.logger.info("Bundled guide playing: \(self.audioURL?.lastPathComponent ?? "guide", privacy: .public)")
                return
            }
            self.recording = nil
            onError?("Using the device voice for this guide.")
        }
        let synthesizer: AVSpeechSynthesizer
        if let speech {
            synthesizer = speech
        } else {
            synthesizer = AVSpeechSynthesizer()
            synthesizer.delegate = self
            speech = synthesizer
        }
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else if !hasSpoken {
            let utterance = AVSpeechUtterance(string: script)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.83
            synthesizer.speak(utterance)
            hasSpoken = true
        }
    }

    private func finishNarration() {
        completed = true
        wantsPlayback = false
        deactivateSession()
    }

    private func deactivateSession() {
        request += 1
        Self.sessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func observeAudioChanges() {
        let interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in self?.onInterruption?() }
        }
        let route = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in self?.onInterruption?() }
        }
        observers = [interruption, route]
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if !flag { self.onError?("Audio ended early. You can follow the written steps.") }
            self.finishNarration()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.recording = nil
            self.onError?("Using the device voice for this guide.")
            if self.wantsPlayback { self.playPreparedGuide() }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                      didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishNarration() }
    }

    private static func recordingURL(practiceID: String, script: String, bundle: Bundle) -> URL? {
        guard let manifestURL = bundle.url(forResource: "narration-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              let asset = manifest.assets.first(where: { $0.practiceID == practiceID }) else { return nil }
        let digest = SHA256.hash(data: Data(script.utf8)).map { String(format: "%02x", $0) }.joined()
        guard digest == asset.scriptSHA256 else { return nil }
        let name = (asset.filename as NSString).deletingPathExtension
        let ext = (asset.filename as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext)
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Audio")
    }

    private struct Manifest: Decodable { let assets: [Asset] }
    private struct Asset: Decodable {
        let practiceID: String
        let filename: String
        let scriptSHA256: String
    }
    private enum NarrationError: Error { case cannotPrepare }
}
