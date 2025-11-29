//
//  NotificationCoordinator.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 10.06.25.
//


import SwiftUI
import UserNotifications
import SwiftData

enum AppTab: Hashable {
    case episodes
    case resilience
    case settings
}

// Notification handling coordinator
class NotificationCoordinator: ObservableObject {
    static let shared = NotificationCoordinator()

    @Published var pendingNavigation: PendingNavigation?
    @Published var selectedTab: AppTab = .resilience

    struct PendingNavigation: Equatable {
        let episodeID: String
        let checkInType: CheckInType
    }

    private init() {}

    func handleNotificationTap(episodeID: String, checkInType: CheckInType) {
        pendingNavigation = PendingNavigation(episodeID: episodeID, checkInType: checkInType)

        // Switch to episodes tab for check-in navigation
        selectedTab = .episodes

        // Clear the badge count when user taps notification
        UNUserNotificationCenter.current().setBadgeCount(0)

        print("🔔 Handling notification tap for episode: \(episodeID), check-in: \(checkInType.displayName)")
    }

    func clearPendingNavigation() {
        pendingNavigation = nil
    }
}
