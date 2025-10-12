import SwiftUI
import MapKit
import Combine

// MARK: - 緊急時位置情報送信ビュー

struct EmergencyLocationView: View {
    @StateObject private var viewModel = EmergencyLocationViewModel()
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var locationPrivacyService: LocationPrivacyService
    @EnvironmentObject var locationTrackingService: LocationTrackingService
    @EnvironmentObject var emergencyService: EmergencyService
    
    @State private var showingConfirmation = false
    @State private var emergencyMessage = ""
    @State private var selectedEmergencyType: EmergencyEventType = .other
    @State private var shareWithContacts = true
    @State private var shareWithAuthorities = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 緊急ボタン
                    EmergencyButton(action: {
                        showingConfirmation = true
                    })
                    .padding(.vertical)
                    
                    // 現在地情報
                    LocationInfoCard(
                        location: locationService.currentLocation,
                        accuracy: locationService.currentLocation?.horizontalAccuracy ?? 0
                    )
                    
                    // 緊急メッセージ入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("緊急メッセージ（任意）")
                            .font(.headline)
                        
                        TextEditor(text: $emergencyMessage)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // 緊急事態の種類
                    VStack(alignment: .leading, spacing: 8) {
                        Text("緊急事態の種類")
                            .font(.headline)
                        
                        Picker("種類", selection: $selectedEmergencyType) {
                            ForEach(EmergencyEventType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // 共有設定
                    VStack(alignment: .leading, spacing: 12) {
                        Text("位置情報の共有")
                            .font(.headline)
                        
                        Toggle("信頼できる連絡先に共有", isOn: $shareWithContacts)
                        Toggle("緊急サービスに共有", isOn: $shareWithAuthorities)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // 注意事項
                    InfoBox(
                        icon: "exclamationmark.triangle",
                        title: "緊急モードについて",
                        description: "緊急モードを有効にすると、30分間正確な位置情報が共有されます。プライバシー設定は一時的に無効になります。"
                    )
                }
                .padding()
            }
            .navigationTitle("緊急位置情報")
            .navigationBarItems(
                trailing: Button("設定") {
                    // 緊急連絡先設定画面へ
                }
            )
        }
        .confirmationDialog("緊急モードを有効にしますか？", isPresented: $showingConfirmation) {
            Button("緊急モードを有効にする", role: .destructive) {
                activateEmergencyMode()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作により、あなたの正確な位置情報が選択した連絡先と緊急サービスに共有されます。")
        }
        .alert("緊急モード有効", isPresented: $viewModel.showingAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }
    
    private func activateEmergencyMode() {
        Task {
            await viewModel.activateEmergencyMode(
                message: emergencyMessage,
                eventType: selectedEmergencyType,
                shareWithContacts: shareWithContacts,
                shareWithAuthorities: shareWithAuthorities
            )
        }
    }
}

// MARK: - Emergency Button

struct EmergencyButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 200, height: 200)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .shadow(color: .red.opacity(0.3), radius: 10)
                
                VStack(spacing: 8) {
                    Image(systemName: "sos")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("緊急")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Location Info Card

struct LocationInfoCard: View {
    let location: CLLocation?
    let accuracy: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("現在地情報", systemImage: "location.fill")
                .font(.headline)
            
            if let location = location {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("緯度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.6f", location.coordinate.latitude))
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("経度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.6f", location.coordinate.longitude))
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                HStack {
                    Label("精度", systemImage: "circle.dashed")
                    Spacer()
                    Text("±\(Int(accuracy))m")
                        .foregroundColor(accuracyColor)
                }
                
                HStack {
                    Label("取得時刻", systemImage: "clock")
                    Spacer()
                    Text(location.timestamp.formatted(date: .omitted, time: .standard))
                }
            } else {
                Text("位置情報を取得中...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var accuracyColor: Color {
        if accuracy <= 10 {
            return .green
        } else if accuracy <= 50 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Info Box

struct InfoBox: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemYellow).opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Emergency Location View Model

@MainActor
class EmergencyLocationViewModel: ObservableObject {
    @Published var isEmergencyActive = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    private let dependencies = DependencyContainer.shared
    
    func activateEmergencyMode(
        message: String,
        eventType: EmergencyEventType,
        shareWithContacts: Bool,
        shareWithAuthorities: Bool
    ) async {
        // 緊急モードを有効化
        dependencies.locationPrivacyService.activateEmergencyMode()
        dependencies.locationTrackingService.startEmergencyTracking()
        
        isEmergencyActive = true
        
        // 位置情報を送信
        if shareWithContacts {
            await shareLocationWithTrustedContacts(message: message)
        }
        
        if shareWithAuthorities {
            await shareLocationWithEmergencyServices(
                message: message,
                eventType: eventType
            )
        }
        
        // アラートを表示
        alertMessage = "緊急モードが有効になりました。あなたの位置情報が共有されています。"
        showingAlert = true
        
        // 30分後に自動的に無効化
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000_000) // 30分
            await deactivateEmergencyMode()
        }
    }
    
    func deactivateEmergencyMode() async {
        dependencies.locationPrivacyService.deactivateEmergencyMode()
        dependencies.locationTrackingService.stopTracking()
        
        isEmergencyActive = false
        
        alertMessage = "緊急モードが無効になりました。"
        showingAlert = true
    }
    
    private func shareLocationWithTrustedContacts(message: String) async {
        // TODO: 信頼できる連絡先に位置情報を送信
        print("Sharing location with trusted contacts: \(message)")
    }
    
    private func shareLocationWithEmergencyServices(
        message: String,
        eventType: EmergencyEventType
    ) async {
        // TODO: 緊急サービスに位置情報を送信
        print("Sharing location with emergency services: \(eventType.rawValue) - \(message)")
    }
}

// MARK: - Emergency Contact Settings View

struct EmergencyContactSettingsView: View {
    @State private var trustedContacts: [TrustedContact] = []
    @State private var showingAddContact = false
    
    var body: some View {
        List {
            Section("信頼できる連絡先") {
                ForEach(trustedContacts) { contact in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading) {
                            Text(contact.name)
                                .font(.headline)
                            Text(contact.phoneNumber)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if contact.autoShare {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .onDelete(perform: deleteContact)
                
                Button(action: { showingAddContact = true }) {
                    Label("連絡先を追加", systemImage: "plus.circle")
                }
            }
            
            Section("緊急サービス") {
                Toggle("警察（110番）", isOn: .constant(true))
                Toggle("消防・救急（119番）", isOn: .constant(true))
                Toggle("海上保安庁（118番）", isOn: .constant(false))
            }
        }
        .navigationTitle("緊急連絡先")
        .sheet(isPresented: $showingAddContact) {
            // 連絡先追加画面
        }
    }
    
    private func deleteContact(at offsets: IndexSet) {
        trustedContacts.remove(atOffsets: offsets)
    }
}

// MARK: - Supporting Types

struct TrustedContact: Identifiable {
    let id = UUID()
    let name: String
    let phoneNumber: String
    let email: String?
    let autoShare: Bool
}