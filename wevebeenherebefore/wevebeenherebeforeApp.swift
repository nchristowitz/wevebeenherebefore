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
        
        if let episodeID = userInfo["episodeID"] as? String,
           let checkInTypeString = userInfo["checkInType"] as? String,
           let checkInType = CheckInType(rawValue: checkInTypeString) {
            
            // TODO: Navigate to the specific episode check-in
            print("User tapped notification for episode \(episodeID), check-in: \(checkInType.displayName)")
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
            ResilienceView()
        }
        .modelContainer(sharedModelContainer)
    }
}
