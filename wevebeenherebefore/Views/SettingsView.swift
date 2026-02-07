import SwiftUI

struct SettingsView: View {
    @State private var isShowingExport = false
    @State private var isShowingImport = false
    @State private var isShowingDebug = false

    @AppStorage("notificationHour") private var notificationHour = 9
    @AppStorage("notificationMinute") private var notificationMinute = 0

    private var notificationTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: notificationHour, minute: notificationMinute)) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationHour = components.hour ?? 9
                notificationMinute = components.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker(
                        "Reminder Time",
                        selection: notificationTime,
                        displayedComponents: .hourAndMinute
                    )
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Check-in reminders will be sent at this time.")
                }

                Section {
                    Button(action: {
                        isShowingExport = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                                .frame(width: 30)
                            Text("Export Data")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }

                    Button(action: {
                        isShowingImport = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.primary)
                                .frame(width: 30)
                            Text("Import Data")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                } header: {
                    Text("My Data")
                }

                #if DEBUG
                Section {
                    Button(action: {
                        isShowingDebug = true
                    }) {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.primary)
                                .frame(width: 30)
                            Text("Debug Tools")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                } header: {
                    Text("Development")
                }
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isShowingExport) {
                ExportView()
            }
            .sheet(isPresented: $isShowingImport) {
                ImportView()
            }
            #if DEBUG
            .sheet(isPresented: $isShowingDebug) {
                DebugView()
            }
            #endif
        }
    }
}

#Preview {
    SettingsView()
}
