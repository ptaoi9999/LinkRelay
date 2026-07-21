import SwiftUI

struct ContentView: View {
    @StateObject private var messageStore: MessageStore
    @StateObject private var btManager: BluetoothManager
    
    @State private var selectedTab = 0
    @State private var messageText = ""
    @State private var senderName = "User_\(Int.random(in: 1000...9999))"
    @State private var isLogsExpanded = false
    
    init(messageStore: MessageStore = MessageStore()) {
        _messageStore = StateObject(wrappedValue: messageStore)
        _btManager = StateObject(wrappedValue: BluetoothManager(messageStore: messageStore))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Open Channel (Meshtastic Style Public Broadcast)
            openChannelView
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Open")
                }
                .tag(0)
            
            // Tab 1: Family Group (Placeholder for upcoming family chat feature)
            familyView
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("家族")
                }
                .tag(1)
            
            // Tab 2: Blog (Offline Store and Forward Mini Blog)
            blogView
                .tabItem {
                    Image(systemName: "doc.text.image")
                    Text("ブログ")
                }
                .tag(2)
            
            // Tab 3: Settings (Relay toggle, Hop count, System Logs)
            settingsView
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .onAppear {
            btManager.setup()
        }
    }
    
    // MARK: - Open Channel View
    private var openChannelView: View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.14)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open Channel")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Meshtastic Public LongFast")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(btManager.isScanning || btManager.isAdvertising ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(btManager.isScanning || btManager.isAdvertising ? "Live Mesh" : "Offline")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Messages Board
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messageStore.messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("受信メッセージがまだありません")
                                        .font(.callout)
                                        .foregroundColor(.gray)
                                    Text("BLEメッシュネットワーク経由で他のノードからメッセージを自動受信・転送します")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(messageStore.messages) { msg in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(msg.sender)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.blue)
                                                Spacer()
                                                Text("Hops: \(msg.hopCount)")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.2))
                                                    .cornerRadius(4)
                                                    .foregroundColor(.blue)
                                            }
                                            Text(msg.text)
                                                .foregroundColor(.white)
                                                .font(.body)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Message Input Bar
                    HStack(spacing: 12) {
                        TextField("公開メッセージを入力...", text: $messageText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Button(action: {
                            guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            btManager.sendMessage(messageText, sender: senderName)
                            messageText = ""
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Family View (Upcoming Feature)
    private var familyView: View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.14)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "house.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text("家族グループチャット")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("今後実装予定のプライベート家族専用グループチャット機能です。エンドツーエンド暗号化により家族間のみで安全にメッシュ通信が行えます。")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                }
                .padding(.top, 80)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Blog View (Upcoming Store and Forward Mini Blog)
    private var blogView: View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.14)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 64))
                        .foregroundColor(.purple.opacity(0.8))
                    
                    Text("オフライン Store & Forward ブログ")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("今後実装予定の簡易ブログ機能です。インターネット環境がない災害時やオフライン環境でも、Store & Forward メッシュネットワークを介して記事を分散投稿・共有できます。")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                }
                .padding(.top, 80)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Settings View
    private var settingsView: View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.14)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        HStack {
                            Text("設定")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Node Settings Card
                        VStack(spacing: 16) {
                            HStack {
                                Text("ユーザー名")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("Name", text: $senderName)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.blue)
                                    .frame(width: 140)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            Toggle(isOn: $btManager.isRelayEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("メッセージをリレー転送する")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Text("他ノードのメッセージの中継を担当")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("最大ホップ数 (Max Hop Count)")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(btManager.maxHopCount)")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(btManager.maxHopCount) },
                                    set: { btManager.maxHopCount = Int($0) }
                                ), in: 1...20, step: 1)
                                .accentColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // System Logs Console
                        VStack(alignment: .leading, spacing: 8) {
                            Text("システムログ")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            DisclosureGroup(isExpanded: $isLogsExpanded) {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if btManager.logs.isEmpty {
                                            Text("ログはありません")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.gray)
                                        } else {
                                            ForEach(btManager.logs, id: \.self) { log in
                                                Text(log)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(height: 120)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(btManager.isScanning || btManager.isAdvertising ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("ログコンソールを表示")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
