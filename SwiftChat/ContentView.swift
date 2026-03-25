//
//  ContentView.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showAPIKeyPrompt = false
    @State private var apiKeyInput = ""

    private var needsAPIKey: Bool {
        let key = AppConfig.shared.apiKey
        return key.isEmpty || key == "YOUR_API_KEY"
    }

    var body: some View {
        ChatContainer()
            .environmentObject(viewModel)
            .onAppear {
                if let saved = UserDefaults.standard.string(forKey: "apiKey"), !saved.isEmpty {
                    AppConfig.shared.apiKey = saved
                } else if needsAPIKey {
                    showAPIKeyPrompt = true
                }
            }
            .alert("API Key Required", isPresented: $showAPIKeyPrompt) {
                TextField("Paste your API key", text: $apiKeyInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save") {
                    let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    AppConfig.shared.apiKey = trimmed
                    UserDefaults.standard.set(trimmed, forKey: "apiKey")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your API key to start chatting.")
            }
    }
}
