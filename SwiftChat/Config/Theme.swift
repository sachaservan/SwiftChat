//
//  Theme.swift
//  SwiftChat
//
//  Created on 03/25/26.
//  Copyright © 2026 Sacha Servan-Schreiber. All rights reserved.
//

import SwiftUI

/// Centralized theme and design system for the app
enum Theme {
    
    // MARK: - Colors
    enum Colors {
        static let backgroundPrimary = Color.backgroundPrimary
        static let chatSurfaceDark = Color.chatSurfaceDark
        static let chatSurfaceLight = Color.chatSurfaceLight
        static let sidebarButtonDark = Color.sidebarButtonBackgroundDark
        static let sidebarButtonLight = Color.sidebarButtonBackgroundLight
        static let cardSurfaceDark = Color.cardSurfaceDark
        static let cardSurfaceLight = Color.cardSurfaceLight
        static let chatBackgroundDark = Color.chatBackgroundDark
        static let chatBackgroundLight = Color.chatBackgroundLight
        static let sidebarBackgroundDark = Color.sidebarBackgroundDark
        static let sidebarBackgroundLight = Color.sidebarBackgroundLight
        static let settingsBackgroundDark = Color.settingsBackgroundDark
        static let settingsBackgroundLight = Color.settingsBackgroundLight
    }
    
    // MARK: - Dimensions
    enum Dimensions {
        // Layout
        static let sidebarWidth: CGFloat = 300
        
        // Common padding values used throughout the app
        static let paddingExtraSmall: CGFloat = 4
        static let paddingSmall: CGFloat = 8
        static let paddingMedium: CGFloat = 12
        static let paddingLarge: CGFloat = 16
        static let paddingExtraLarge: CGFloat = 24
        
        // Common corner radius values
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16
    }
    
    // MARK: - Animations
    enum Animations {
        // Common animation durations
        static let defaultDuration: Double = 0.25
        static let mediumDuration: Double = 0.3
        static let longDuration: Double = 0.6
        static let copyFeedbackDuration: Double = 1.5
        
        // Spring animations used in various places
        static let springResponse: Double = 0.3
        static let springDamping: Double = 0.75
        static let springResponseFast: Double = 0.2
        static let springDampingHigh: Double = 0.9
    }
} 
