//
//  Color.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI
import UIKit

extension Color {
    // Accent colors
    static let accentPrimary = Color(red: 16/255, green: 185/255, blue: 129/255) // #10B981
    
    // Brand colors
    static let brandDark = Color(hex: "061820")
    static let brandLight = Color(hex: "EEF3F3")
    static let brandAccentDark = Color(hex: "004444")
    static let brandAccentLight = Color(hex: "68C7AC")
    
    // App surface colors
    static let backgroundPrimary = Color.brandDark
    static let chatSurfaceDark = Color(hex: "2C2C2E")
    static let chatSurfaceLight = Color(hex: "F2F2F7")
    static let sidebarButtonBackgroundDark = Color(hex: "2C2C2E")
    static let sidebarButtonBackgroundLight = Color.white
    static let cardSurfaceDark = Color(hex: "1C1C1E")
    static let cardSurfaceLight = Color.white
    static let chatBackgroundDark = Color(hex: "121212")
    static let chatBackgroundLight = Color.white
    static let actionButtonBackgroundDark = Color.white.opacity(0.08)
    static let actionButtonBackgroundLight = Color.black.opacity(0.05)
    static let sidebarBackgroundDark = Color(hex: "121212")
    static let sidebarBackgroundLight = Color.white
    static let settingsBackgroundDark = Color(hex: "121212")
    static let settingsBackgroundLight = Color(UIColor.systemGroupedBackground)
    static let sendButtonBackgroundDark = Color.brandDark
    static let sendButtonBackgroundLight = Color.white
    static let sendButtonForegroundDark = Color.white
    static let sendButtonForegroundLight = Color.black

    // Reasoning and messaging surfaces
    static let thinkingBackgroundDark = chatSurfaceDark
    static let thinkingBackgroundLight = chatSurfaceLight
    static let userMessageBackgroundDark = chatSurfaceDark
    static let userMessageBackgroundLight = chatSurfaceLight
    static let userMessageForegroundDark = Color.white
    static let userMessageForegroundLight = Color.black


    // Adaptive accent color for buttons/links that works in both light and dark mode
    static let adaptiveAccent = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            // White in dark mode for better visibility
            return .white
        } else {
            // Use the green accent in light mode
            return UIColor(Color.accentPrimary)
        }
    })

    // Convenience helpers for common surfaces
    static func chatSurface(isDarkMode: Bool) -> Color {
        isDarkMode ? chatSurfaceDark : chatSurfaceLight
    }
    
    static func sidebarButtonBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? sidebarButtonBackgroundDark : sidebarButtonBackgroundLight
    }
    
    static func cardSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardSurfaceDark : cardSurfaceLight
    }
    
    static func chatBackground(isDarkMode: Bool) -> Color {
        isDarkMode ? chatBackgroundDark : chatBackgroundLight
    }

    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? sidebarBackgroundDark : sidebarBackgroundLight
    }

    static func settingsBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? settingsBackgroundDark : settingsBackgroundLight
    }

    static func thinkingBackground(isDarkMode: Bool) -> Color {
        isDarkMode ? thinkingBackgroundDark : thinkingBackgroundLight
    }

    static func userMessageBackground(isDarkMode: Bool) -> Color {
        isDarkMode ? userMessageBackgroundDark : userMessageBackgroundLight
    }

    static func userMessageForeground(isDarkMode: Bool) -> Color {
        isDarkMode ? userMessageForegroundDark : userMessageForegroundLight
    }

    static func actionButtonBackground(isDarkMode: Bool) -> Color {
        isDarkMode ? actionButtonBackgroundDark : actionButtonBackgroundLight
    }
}
