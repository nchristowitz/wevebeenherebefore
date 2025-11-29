//
//  wevebeenherebeforeApp.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 03.02.25.
//

import SwiftUI
import SwiftData
import UserNotifications

// Add AppDelegate to handle notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories
        registerNotificationCategories()
        
        return true
    }
    
    private func registerNotificationCategories() {
        let category = UNNotificationCategory(
            identifier: "EPISODE_CHECKIN",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Clear badge immediately when notification is tapped
        UNUserNotificationCenter.current().setBadgeCount(0)
        
        if let episodeID = userInfo["episodeID"] as? String,
           let checkInTypeString = userInfo["checkInType"] as? String,
           let checkInType = CheckInType(rawValue: checkInTypeString) {
            
            // Use the notification coordinator to handle navigation
            NotificationCoordinator.shared.handleNotificationTap(
                episodeID: episodeID,
                checkInType: checkInType
            )
        }
        
        completionHandler()
    }
}

@main
struct wevebeenherebeforeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Card.self,
            Episode.self,
            EpisodeNote.self,
            CheckIn.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var episodes: [Episode]
    @ObservedObject private var notificationCoordinator = NotificationCoordinator.shared

    // Calculate pending check-ins count for badge
    private var pendingCheckInsCount: Int {
        var count = 0
        for episode in episodes {
            for checkInType in CheckInType.allCases {
                if episode.isCheckInWindowActive(for: checkInType) &&
                   !episode.hasCheckIn(for: checkInType) &&
                   !episode.isCheckInDismissed(for: checkInType) {
                    count += 1
                }
            }
        }
        return count
    }

    var body: some View {
        TabView(selection: $notificationCoordinator.selectedTab) {
            EpisodesListView()
                .tabItem {
                    Label("Episodes", systemImage: "tornado")
                }
                .badge(pendingCheckInsCount > 0 ? pendingCheckInsCount : 0)
                .tag(AppTab.episodes)

            ResilienceView()
                .tabItem {
                    Label("Resilience", systemImage: "heart.fill")
                }
                .tag(AppTab.resilience)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.primary)
    }
}
