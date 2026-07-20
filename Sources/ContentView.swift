import SwiftUI

struct ContentView: View {
    @StateObject private var messageStore = MessageStore()
    @StateObject private var btManager: BluetoothManager
    
    @State private var messageText = ""
    @State private var senderName = "User_\(Int.random(in: 1000...9999))"
    
    init() {
        let store = MessageStore()
        _messageStore = StateObject(wrappedValue: store)
        _btManager = StateObject(wrappedValue: BluetoothManager(messageStore: store))
    }
    
    var body: some View {
        NavigationView {
            ZCombineView {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LinkRelay")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        Text("Store & Forward BLE Mesh Network")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Relay Configuration Card
                    VStack(spacing: 16) {
                        Toggle(isOn: $btManager.isRelayEnabled) {
                            VStack(alignment: .leading) {
                                Text("Relay Messages")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("Allow forwarding others' messages")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Max Hop Count")
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
                    
                    // Messages Board
                    VStack(alignment: .leading) {
                        Text("MESSAGES")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if messageStore.messages.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray.opacity(0.4))
                                        Text("No Messages Yet")
                                            .font(.callout)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.top, 40)
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
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Input Bar
                    HStack(spacing: 12) {
                        TextField("Type message...", text: $messageText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                            .padding()
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
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Active Logs Console
                    DisclosureGroup(isExpanded: .constant(false)) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(btManager.logs, id: \.self) { log in
                                    Text(log)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    } label: {
                        HStack {
                            Circle()
                                .fill(btManager.isScanning || btManager.isAdvertising ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text("System Logs")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Helper to support simple overlay layout
struct ZCombineView<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        ZStack {
            content()
        }
    }
}
