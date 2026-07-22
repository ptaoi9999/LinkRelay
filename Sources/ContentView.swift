import SwiftUI

struct ContentView: View {
    @StateObject private var messageStore: MessageStore
    @StateObject private var btManager: BluetoothManager
    
    @AppStorage("senderName") private var senderName = "User_\(Int.random(in: 1000...9999))"
    @State private var selectedTab = 0
    @State private var messageText = ""
    @State private var familyMessageText = ""
    @State private var isLogsExpanded = false
    
    // DM state variables
    @State private var isShowingScanner = false
    @State private var isShowingMyQR = false
    @State private var showManualInput = false
    @State private var manualPartnerName = ""
    @State private var selectedPartner: String? = nil
    
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
            
            // Tab 1: DM Channel (Direct Messages)
            dmChannelView
                .tabItem {
                    Image(systemName: "envelope.fill")
                    Text("DM")
                }
                .tag(1)
            
            // Tab 2: Family Group (Placeholder for upcoming family chat feature)
            familyView
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("家族")
                }
                .tag(2)
            
            // Tab 3: Blog (Offline Store and Forward Mini Blog)
            blogView
                .tabItem {
                    Image(systemName: "doc.text.image")
                    Text("ブログ")
                }
                .tag(3)
            
            // Tab 4: Settings (Relay toggle, Hop count, System Logs)
            settingsView
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onAppear {
            btManager.setup()
        }
    }
    
    // MARK: - Open Channel View
    @ViewBuilder
    private var openChannelView: some View {
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
                            if messageStore.openMessages.isEmpty {
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
                                ForEach(messageStore.openMessages) { msg in
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
    
    // MARK: - Family View (Active Family Group Chat)
    @ViewBuilder
    private var familyView: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.14)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("家族グループ")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Image(systemName: "lock.shield.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            Text("プライベート・家族専用メッシュチャット")
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
                            if messageStore.familyMessages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "house.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.blue.opacity(0.5))
                                    Text("家族メッセージはまだありません")
                                        .font(.callout)
                                        .foregroundColor(.gray)
                                    Text("このチャンネルで送信されたメッセージは家族専用ネットワークでリレー同期されます")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(messageStore.familyMessages) { msg in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(msg.sender)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.green)
                                                Spacer()
                                                Text("Hops: \(msg.hopCount)")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.2))
                                                    .cornerRadius(4)
                                                    .foregroundColor(.green)
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
                        TextField("家族メッセージを入力...", text: $familyMessageText)
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
                            guard !familyMessageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            btManager.sendMessage(familyMessageText, sender: senderName, channel: "family")
                            familyMessageText = ""
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.green)
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
    
    // MARK: - Blog View (Upcoming Store and Forward Mini Blog)
    @ViewBuilder
    private var blogView: some View {
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
    @ViewBuilder
    private var settingsView: some View {
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
    
    // MARK: - DM Channel View
    @ViewBuilder
    private var dmChannelView: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.14)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ダイレクトメッセージ (DM)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("QRコードでつながる安全なDM")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        // Actions
                        HStack(spacing: 8) {
                            Button(action: { isShowingMyQR = true }) {
                                Image(systemName: "qrcode")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: { isShowingScanner = true }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Partners List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            let partners = dmPartners
                            if partners.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "envelope.badge.shield.half.filled")
                                        .font(.system(size: 56))
                                        .foregroundColor(.gray.opacity(0.4))
                                    Text("DMを開始しましょう")
                                        .font(.callout)
                                        .foregroundColor(.gray)
                                    Text("右上のスキャンボタンから相手のQRコードをスキャンするか、自分のQRコードを提示してDMを開始します。")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                    
                                    Button("手動でユーザーIDを入力") {
                                        showManualInput = true
                                    }
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                                    .padding(.top, 8)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(partners, id: \.self) { partner in
                                    Button(action: { selectedPartner = partner }) {
                                        HStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .foregroundColor(.blue)
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(partner)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                
                                                if let lastMsg = lastMessage(with: partner) {
                                                    Text(lastMsg.text)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .lineLimit(1)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingScanner) {
                QRCodeScannerView { scannedName in
                    isShowingScanner = false
                    if !scannedName.isEmpty {
                        selectedPartner = scannedName
                    }
                }
            }
            .sheet(isPresented: $isShowingMyQR) {
                MyQRView(myId: senderName)
            }
            .sheet(isPresented: $showManualInput) {
                manualInputView
            }
            .background(
                NavigationLink(
                    destination: Group {
                        if let partner = selectedPartner {
                            DMChatView(partnerName: partner, myName: senderName, messageStore: messageStore, btManager: btManager)
                        }
                    },
                    isActive: Binding(
                        get: { selectedPartner != nil },
                        set: { if !$0 { selectedPartner = nil } }
                    )
                ) { EmptyView() }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var dmPartners: [String] {
        let allPartners = messageStore.dmMessages.compactMap { msg -> String? in
            if msg.sender == senderName {
                return msg.recipient
            } else if msg.recipient == senderName {
                return msg.sender
            }
            return nil
        }
        return Array(Set(allPartners)).sorted()
    }
    
    private func lastMessage(with partner: String) -> RelayMessage? {
        let messages = messageStore.dmMessages.filter {
            ($0.sender == senderName && $0.recipient == partner) ||
            ($0.sender == partner && $0.recipient == senderName)
        }
        return messages.sorted(by: { $0.timestamp < $1.timestamp }).last
    }
    
    private var manualInputView: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.14).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("手動で宛先を入力")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("相手のユーザー名 (例: User_1234)", text: $manualPartnerName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button("キャンセル") {
                        showManualInput = false
                        manualPartnerName = ""
                    }
                    .foregroundColor(.gray)
                    
                    Button("チャット開始") {
                        let trimmed = manualPartnerName.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            showManualInput = false
                            selectedPartner = trimmed
                            manualPartnerName = ""
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
    }
}

// MARK: - MyQRView
struct MyQRView: View {
    let myId: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.14)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Text("マイ QRコード")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("このQRコードを相手にスキャンしてもらうことで、DMを開始できます。")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                if let qrImage = generateQRCode(from: myId) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(20)
                } else {
                    Text("QRコードの生成に失敗しました")
                        .foregroundColor(.red)
                }
                
                Text("あなたのID: \(myId)")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                
                Spacer()
            }
        }
    }
}

// MARK: - DMChatView
struct DMChatView: View {
    let partnerName: String
    let myName: String
    @ObservedObject var messageStore: MessageStore
    let btManager: BluetoothManager
    
    @State private var messageText = ""
    @Environment(\.presentationMode) var presentationMode
    
    var messages: [RelayMessage] {
        messageStore.dmMessages.filter {
            ($0.sender == myName && $0.recipient == partnerName) ||
            ($0.sender == partnerName && $0.recipient == myName)
        }.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.14)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(partnerName)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("ダイレクトメッセージ (暗号化)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Message List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "envelope.open.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.4))
                                Text("メッセージ履歴がありません")
                                    .font(.callout)
                                    .foregroundColor(.gray)
                                Text("安全なメッシュネットワーク経由でダイレクトメッセージを送信します。")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(messages) { msg in
                                let isMe = msg.sender == myName
                                HStack {
                                    if isMe { Spacer() }
                                    
                                    VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                                        Text(msg.text)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(isMe ? Color.blue : Color.white.opacity(0.08))
                                            .cornerRadius(16)
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 4) {
                                            Text("Hops: \(msg.hopCount)")
                                            Text("•")
                                            Text(msg.timestamp, style: .time)
                                        }
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 4)
                                    }
                                    
                                    if !isMe { Spacer() }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Message Input
                HStack(spacing: 12) {
                    TextField("メッセージを入力...", text: $messageText)
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
                        btManager.sendMessage(messageText, sender: myName, channel: "dm", recipient: partnerName)
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
}
