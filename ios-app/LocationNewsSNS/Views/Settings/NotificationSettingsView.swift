import SwiftUI
import UserNotifications

// MARK: - 通知設定画面

struct NotificationSettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var pushNotificationService: PushNotificationService
    @EnvironmentObject var emergencyNotificationService: EmergencyNotificationService
    
    @State private var showingPermissionAlert = false
    @State private var notificationSettings: NotificationSettings
    @State private var emergencySettings: EmergencyNotificationSettings
    
    init() {
        _notificationSettings = State(initialValue: .default)
        _emergencySettings = State(initialValue: .default)
    }
    
    var body: some View {
        NavigationView {
            List {
                // 通知許可状態
                permissionStatusSection
                
                // 基本通知設定
                basicNotificationSection
                
                // 緊急通知設定
                emergencyNotificationSection
                
                // 位置ベース通知設定
                locationNotificationSection
                
                // サイレント時間設定
                quietHoursSection
                
                // 通知統計
                analyticsSection
            }
            .navigationTitle("通知設定")
            .onAppear {
                loadSettings()
                checkPermissionStatus()
            }
            .alert("通知許可が必要です", isPresented: $showingPermissionAlert) {
                Button("設定を開く") {
                    openNotificationSettings()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("プッシュ通知を受信するには、設定アプリで通知を許可してください。")
            }
        }
    }
    
    // MARK: - Permission Status Section
    
    @ViewBuilder
    private var permissionStatusSection: some View {
        Section("通知許可状態") {
            HStack {
                Image(systemName: pushNotificationService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(pushNotificationService.isAuthorized ? .green : .red)
                
                VStack(alignment: .leading) {
                    Text("プッシュ通知")
                        .font(.headline)
                    Text(permissionStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !pushNotificationService.isAuthorized {
                    Button("許可") {
                        requestNotificationPermission()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var permissionStatusText: String {
        switch pushNotificationService.authorizationStatus {
        case .authorized: return "許可済み"
        case .denied: return "拒否されています"
        case .notDetermined: return "未設定"
        case .provisional: return "仮許可"
        case .ephemeral: return "一時許可"
        @unknown default: return "不明"
        }
    }
    
    // MARK: - Basic Notification Section
    
    @ViewBuilder
    private var basicNotificationSection: some View {
        Section("基本通知") {
            Toggle("投稿通知", isOn: $notificationSettings.enablePostNotifications)
                .onChange(of: notificationSettings.enablePostNotifications) { newValue in
                    notificationManager.toggleNotificationType(.post, enabled: newValue)
                }
            
            if notificationSettings.enablePostNotifications {
                VStack(alignment: .leading) {
                    Text("通知範囲: \(String(format: "%.0f", notificationSettings.postNotificationRadius/1000))km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: $notificationSettings.postNotificationRadius,
                        in: 1000...20000,
                        step: 1000
                    ) {
                        Text("通知範囲")
                    } minimumValueLabel: {
                        Text("1km")
                    } maximumValueLabel: {
                        Text("20km")
                    }
                }
            }
            
            Toggle("いいね通知", isOn: $notificationSettings.enableLikeNotifications)
                .onChange(of: notificationSettings.enableLikeNotifications) { newValue in
                    notificationManager.toggleNotificationType(.like, enabled: newValue)
                }
            
            Toggle("コメント通知", isOn: $notificationSettings.enableCommentNotifications)
                .onChange(of: notificationSettings.enableCommentNotifications) { newValue in
                    notificationManager.toggleNotificationType(.comment, enabled: newValue)
                }
            
            Toggle("位置情報通知", isOn: $notificationSettings.enableLocationNotifications)
                .onChange(of: notificationSettings.enableLocationNotifications) { newValue in
                    notificationManager.toggleNotificationType(.location, enabled: newValue)
                }
        }
    }
    
    // MARK: - Emergency Notification Section
    
    @ViewBuilder
    private var emergencyNotificationSection: some View {
        Section("緊急通知") {
            Toggle("緊急アラート", isOn: $emergencySettings.enableCriticalAlerts)
                .foregroundColor(.red)
            
            if emergencySettings.enableCriticalAlerts {
                VStack(alignment: .leading) {
                    Text("通知範囲: \(String(format: "%.0f", emergencySettings.criticalAlertRadius/1000))km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: $emergencySettings.criticalAlertRadius,
                        in: 1000...50000,
                        step: 1000
                    ) {
                        Text("緊急通知範囲")
                    } minimumValueLabel: {
                        Text("1km")
                    } maximumValueLabel: {
                        Text("50km")
                    }
                }
            }
            
            Toggle("警告通知", isOn: $emergencySettings.enableWarningAlerts)
                .foregroundColor(.orange)
            
            Toggle("情報通知", isOn: $emergencySettings.enableInfoAlerts)
                .foregroundColor(.blue)
            
            Toggle("SOS信号通知", isOn: $emergencySettings.enableSOSAlerts)
                .foregroundColor(.red)
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("緊急通知は重要な安全情報のため、サイレント時間中でも配信されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Location Notification Section
    
    @ViewBuilder
    private var locationNotificationSection: some View {
        Section("位置ベース通知") {
            Toggle("位置ベースアラート", isOn: $emergencySettings.enableLocationBasedAlerts)
            
            NavigationLink("位置ベース通知の管理") {
                LocationBasedNotificationView()
            }
            
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.blue)
                Text("特定の場所に近づいた時や離れた時に通知を受け取ることができます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Quiet Hours Section
    
    @ViewBuilder
    private var quietHoursSection: some View {
        Section("サイレント時間") {
            Toggle("サイレント時間を有効化", isOn: $notificationSettings.enableQuietHours)
            
            if notificationSettings.enableQuietHours {
                DatePicker(
                    "開始時刻",
                    selection: $notificationSettings.quietHoursStart,
                    displayedComponents: .hourAndMinute
                )
                
                DatePicker(
                    "終了時刻",
                    selection: $notificationSettings.quietHoursEnd,
                    displayedComponents: .hourAndMinute
                )
                
                HStack {
                    Image(systemName: "moon")
                        .foregroundColor(.indigo)
                    Text("サイレント時間中は緊急通知以外は配信されません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Analytics Section
    
    @ViewBuilder
    private var analyticsSection: some View {
        Section("通知統計") {
            let analytics = notificationManager.getNotificationAnalytics()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("送信済み")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analytics.totalSent)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("開封率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", analytics.openRate * 100))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(analytics.openRate > 0.5 ? .green : .orange)
                }
            }
            
            Button("通知履歴を表示") {
                // 通知履歴画面に遷移
            }
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - Methods
    
    private func loadSettings() {
        notificationSettings = notificationManager.notificationSettings
        emergencySettings = emergencyNotificationService.emergencyNotificationSettings
    }
    
    private func saveSettings() {
        notificationManager.updateNotificationSettings(notificationSettings)
        emergencyNotificationService.emergencyNotificationSettings = emergencySettings
        emergencyNotificationService.saveSettings()
    }
    
    private func checkPermissionStatus() {
        pushNotificationService.checkAuthorizationStatus()
    }
    
    private func requestNotificationPermission() {
        Task {
            await pushNotificationService.requestAuthorization()
            
            if !pushNotificationService.isAuthorized {
                showingPermissionAlert = true
            }
        }
    }
    
    private func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Location Based Notification View

struct LocationBasedNotificationView: View {
    @State private var locationNotifications: [LocationNotification] = []
    @State private var showingAddNotification = false
    
    var body: some View {
        List {
            Section("現在の位置ベース通知") {
                if locationNotifications.isEmpty {
                    Text("位置ベース通知はありません")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(locationNotifications) { notification in
                        LocationNotificationRow(notification: notification)
                    }
                    .onDelete(perform: deleteNotification)
                }
            }
            
            Section {
                Button(action: { showingAddNotification = true }) {
                    Label("新しい位置ベース通知を追加", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("位置ベース通知")
        .navigationBarItems(trailing: EditButton())
        .sheet(isPresented: $showingAddNotification) {
            AddLocationNotificationView { notification in
                locationNotifications.append(notification)
            }
        }
    }
    
    private func deleteNotification(at offsets: IndexSet) {
        locationNotifications.remove(atOffsets: offsets)
    }
}

// MARK: - Location Notification Row

struct LocationNotificationRow: View {
    let notification: LocationNotification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title)
                .font(.headline)
            
            Text(notification.address)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(Int(notification.radius))m", systemImage: "location.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if notification.isEnabled {
                    Text("有効")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else {
                    Text("無効")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                }
            }
        }
    }
}

// MARK: - Add Location Notification View

struct AddLocationNotificationView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (LocationNotification) -> Void
    
    @State private var title = ""
    @State private var message = ""
    @State private var address = ""
    @State private var radius: Double = 100
    @State private var notifyOnEntry = true
    @State private var notifyOnExit = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("通知内容") {
                    TextField("タイトル", text: $title)
                    TextField("メッセージ", text: $message)
                }
                
                Section("場所") {
                    TextField("住所または場所名", text: $address)
                    
                    VStack(alignment: .leading) {
                        Text("範囲: \(Int(radius))m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $radius, in: 50...1000, step: 50) {
                            Text("範囲")
                        } minimumValueLabel: {
                            Text("50m")
                        } maximumValueLabel: {
                            Text("1km")
                        }
                    }
                }
                
                Section("通知タイミング") {
                    Toggle("エリアに入った時", isOn: $notifyOnEntry)
                    Toggle("エリアから出た時", isOn: $notifyOnExit)
                }
            }
            .navigationTitle("位置ベース通知を追加")
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() },
                trailing: Button("追加") { addNotification() }
                    .disabled(title.isEmpty || address.isEmpty)
            )
        }
    }
    
    private func addNotification() {
        let notification = LocationNotification(
            title: title,
            message: message,
            address: address,
            radius: radius,
            notifyOnEntry: notifyOnEntry,
            notifyOnExit: notifyOnExit
        )
        
        onAdd(notification)
        dismiss()
    }
}

// MARK: - Supporting Types

struct LocationNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let address: String
    let radius: Double
    let notifyOnEntry: Bool
    let notifyOnExit: Bool
    var isEnabled = true
}

#Preview {
    NotificationSettingsView()
        .environmentObject(NotificationManager(
            pushNotificationService: PushNotificationService(),
            locationService: LocationService()
        ))
        .environmentObject(PushNotificationService())
        .environmentObject(EmergencyNotificationService(
            pushNotificationService: PushNotificationService(),
            locationService: LocationService(),
            realtimeService: RealtimeService()
        ))
}