import AVFoundation
import Foundation

/// Speaks form-coaching feedback aloud during a camera session.
///
/// Throttling rules keep the audio useful instead of chatty:
///   • the same phrase is not repeated back-to-back,
///   • error cues interrupt whatever is being said and take priority,
///   • non-error cues are skipped while another phrase is still being spoken,
///   • rep-count announcements only play when no cue is mid-utterance.
///
/// Used only from the main thread (CameraFormCoach.apply), matching
/// AVSpeechSynthesizer's expectations.
final class VoiceCoach {

    private let synth = AVSpeechSynthesizer()
    private var lastSpoken = ""
    private var lastSpokenAt = Date.distantPast
    private var sessionConfigured = false

    private static let repeatSuppression: TimeInterval = 6   // don't re-speak identical cue within this
    private static let minGap: TimeInterval = 1.8            // min spacing between non-error cues

    // MARK: - Public API

    func speak(_ text: String, severity: FormSeverity) {
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }

        let now = Date()
        let isError = severity == .error

        // Skip an identical phrase repeated within the suppression window.
        if phrase == lastSpoken, now.timeIntervalSince(lastSpokenAt) < Self.repeatSuppression { return }

        if isError {
            // Errors are urgent — cut off any in-progress speech.
            if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        } else {
            // Don't queue behind current speech or fire too rapidly.
            if synth.isSpeaking { return }
            if now.timeIntervalSince(lastSpokenAt) < Self.minGap { return }
        }

        configureSessionIfNeeded()
        lastSpoken = phrase
        lastSpokenAt = now

        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = isError ? 1.08 : 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utterance)
    }

    /// Announce the latest rep number, but only if it won't talk over a form cue.
    func announceRep(_ count: Int) {
        guard !synth.isSpeaking else { return }
        configureSessionIfNeeded()
        let utterance = AVSpeechUtterance(string: "\(count)")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        lastSpoken = ""
        lastSpokenAt = .distantPast
    }

    // MARK: - Audio session

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        let session = AVAudioSession.sharedInstance()
        // .voicePrompt ducks (not silences) background audio; .mixWithOthers
        // lets the user's music keep playing underneath the coaching.
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
    }
}
