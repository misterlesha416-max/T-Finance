import SwiftUI

// MARK: - Model

private struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let time: String
}

// MARK: - ChatView

struct ChatView: View {
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    @State private var messages: [ChatMessage] = [
        ChatMessage(
            text: "Здравствуйте! Я Валера — виртуальный помощник. Чем помочь?",
            isUser: false,
            time: "10:02"
        )
    ]
    
    private let quickReplies = [
        "Заблокировать карту",
        "Не пришёл перевод",
        "Изменить лимит"
    ]
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            header
            
            ScrollViewReader { proxy in
                
                ScrollView(showsIndicators: false) {
                    
                    VStack(spacing: 10) {
                        
                        ForEach(messages) { message in
                            
                            messageBubble(message)
                                .id(message.id)
                        }
                        
                        if messages.count == 1 {
                            
                            quickRepliesRow
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
                .onChange(of: messages) { _, _ in
                    
                    if let last = messages.last {
                        
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            inputBar
                .padding(.bottom, 94)
        }
    }
    
    // MARK: Header
    
    private var header: some View {
        
        HStack(spacing: 10) {
            
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay {
                    
                    Image(systemName: "headphones")
                        .font(.system(size: 15))
                        .foregroundStyle(.blue)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                
                Text("Поддержка")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 4) {
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Text("Онлайн")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }
    
    // MARK: Bubble
    
    private func messageBubble(_ message: ChatMessage) -> some View {
        
        HStack {
            
            if message.isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                
                Text(message.text)
                    .font(.system(size: 14.5))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        message.isUser
                        ? Color.blue
                        : Color.white.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Text(message.time)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: Quick replies
    
    private var quickRepliesRow: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            
            HStack(spacing: 8) {
                
                ForEach(quickReplies, id: \.self) { reply in
                    
                    Button {
                        send(text: reply)
                    } label: {
                        
                        Text(reply)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Color.blue.opacity(0.14))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: Input bar
    
    private var inputBar: some View {
        
        HStack(spacing: 10) {
            
            HStack {
                
                TextField(
                    "",
                    text: $messageText,
                    prompt: Text("Сообщение")
                        .foregroundStyle(.white.opacity(0.4))
                )
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused($isInputFocused)
                .onSubmit {
                    send(text: messageText)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color(red: 0.105, green: 0.105, blue: 0.115))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            Button {
                send(text: messageText)
            } label: {
                
                Circle()
                    .fill(
                        messageText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.white.opacity(0.1)
                        : Color.blue
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
    
    // MARK: Sending
    
    private func send(text: String) {
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return
        }
        
        messages.append(
            ChatMessage(text: trimmed, isUser: true, time: currentTime())
        )
        
        messageText = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            
            messages.append(
                ChatMessage(
                    text: "Спасибо за обращение! Уже передал вопрос специалисту — он подключится к чату в течение нескольких минут.",
                    isUser: false,
                    time: currentTime()
                )
            )
        }
    }
    
    private func currentTime() -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return formatter.string(from: Date())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ChatView()
    }
    .preferredColorScheme(.dark)
}
