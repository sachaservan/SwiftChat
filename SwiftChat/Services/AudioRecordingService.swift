//
//  AudioRecordingService.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import OpenAI

/// Service for managing audio recording and transcription
@MainActor
class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService()

    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false

    private var audioRecorder: AVAudioRecorder?
    private var timeoutTimer: Timer?
    private var recordingURL: URL?

    private override init() {
        super.init()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    var hasPermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    // MARK: - Recording

    func startRecording() throws {
        guard !isRecording else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = getRecordingURL()
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Constants.Audio.sampleRate,
            AVNumberOfChannelsKey: Constants.Audio.numberOfChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: Constants.Audio.recordingTimeoutSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopRecording()
            }
        }
    }

    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false

        return recordingURL
    }

    func cancelRecording() {
        stopRecording()
        cleanupRecordingFile()
    }

    // MARK: - Transcription

    func transcribe(fileURL: URL, client: OpenAI) async throws -> String {
        isTranscribing = true
        defer {
            isTranscribing = false
            cleanupRecordingFile()
        }

        let audioData = try await Task.detached {
            try Data(contentsOf: fileURL)
        }.value

        guard !audioData.isEmpty else {
            throw AudioRecordingError.emptyRecording
        }

        let query = AudioTranscriptionQuery(
            file: audioData,
            fileType: .m4a,
            model: Constants.Audio.transcriptionModel,
            responseFormat: .json
        )

        let result = try await client.audioTranscriptions(query: query)
        let transcription = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcription.isEmpty else {
            throw AudioRecordingError.emptyTranscription
        }

        return transcription
    }

    // MARK: - Private Helpers

    private func getRecordingURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "recording_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(filename)
    }

    private func cleanupRecordingFile() {
        guard let url = recordingURL else { return }
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
    }
}

// MARK: - Errors

enum AudioRecordingError: LocalizedError {
    case permissionDenied
    case emptyRecording
    case emptyTranscription
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied"
        case .emptyRecording:
            return "Recording is empty"
        case .emptyTranscription:
            return "Transcription returned empty"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}
