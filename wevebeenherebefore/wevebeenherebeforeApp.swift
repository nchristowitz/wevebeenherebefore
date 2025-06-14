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
    @ObservedObject private var notificationCoordinator = NotificationCoordinator.shared
    @State private var selectedEpisode: Episode?
    @State private var checkInToShow: CheckInType?
    @State private var showingCheckIn = false
    
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
            ResilienceView()
                .sheet(isPresented: $showingCheckIn) {
                    if let episode = selectedEpisode, let checkInType = checkInToShow {
                        CheckInView(episode: episode, checkInType: checkInType) {
                            // Called when check-in is completed
                            showingCheckIn = false
                            selectedEpisode = nil
                            checkInToShow = nil
                        }
                    }
                }
                .onChange(of: notificationCoordinator.pendingNavigation) { _, pendingNav in
                    if let navigation = pendingNav {
                        handleNotificationNavigation(navigation)
                        notificationCoordinator.clearPendingNavigation()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleNotificationNavigation(_ navigation: NotificationCoordinator.PendingNavigation) {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Episode>()
        
        do {
            let episodes = try context.fetch(descriptor)
            if let episode = episodes.first(where: { "\($0.persistentModelID)" == navigation.episodeID }) {
                
                // Check if this check-in already exists
                let existingCheckIn = episode.checkIns.first { $0.checkInType == navigation.checkInType }
                
                if existingCheckIn == nil {
                    // Navigate to check-in view
                    selectedEpisode = episode
                    checkInToShow = navigation.checkInType
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingCheckIn = true
                    }
                    
                    print("✅ App-level navigation to check-in: \(navigation.checkInType.displayName) for episode: \(episode.title)")
                } else {
                    print("ℹ️ Check-in already completed for \(navigation.checkInType.displayName)")
                }
            } else {
                print("❌ Episode not found for ID: \(navigation.episodeID)")
            }
        } catch {
            print("❌ Error fetching episodes: \(error)")
        }
    }
}
