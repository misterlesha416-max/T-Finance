import SwiftUI
import UniformTypeIdentifiers

// MARK: - Model

private struct MoreRow: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String?
}

// MARK: - MoreView

struct MoreView: View {
    
    // MARK: Export / import
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument = TransactionsFile(text: "")
    @State private var dataMessage: String?
    
    private let products: [MoreRow] = [
        MoreRow(icon: "banknote.fill", tint: .green, title: "Вклады и счета", subtitle: "Открыть вклад под выгодный процент"),
        MoreRow(icon: "percent", tint: .orange, title: "Кредиты", subtitle: nil),
        MoreRow(icon: "chart.line.uptrend.xyaxis", tint: .purple, title: "Инвестиции", subtitle: "Портфель: 0 Br")
    ]
    
    private let services: [MoreRow] = [
        MoreRow(icon: "gift.fill", tint: .pink, title: "Пригласить друзей", subtitle: "Бонус за каждого друга"),
        MoreRow(icon: "questionmark.circle.fill", tint: .blue, title: "Частые вопросы", subtitle: nil),
        MoreRow(icon: "doc.text.fill", tint: .gray, title: "Документы и справки", subtitle: nil)
    ]
    
    private let settings: [MoreRow] = [
        MoreRow(icon: "bell.fill", tint: .red, title: "Уведомления", subtitle: nil),
        MoreRow(icon: "lock.fill", tint: .yellow, title: "Безопасность", subtitle: nil),
        MoreRow(icon: "gearshape.fill", tint: .white, title: "Настройки приложения", subtitle: nil)
    ]
    
    var body: some View {
        
        ScrollView(showsIndicators: false) {
            
            VStack(spacing: 0) {
                
                header
                    .padding(.top, 22)
                
                profileCard
                    .padding(.top, 16)
                
                sectionLabel("Продукты")
                    .padding(.top, 26)
                
                group(products)
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                
                sectionLabel("Сервисы")
                    .padding(.top, 26)
                
                group(services)
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                
                sectionLabel("Данные")
                    .padding(.top, 26)
                
                dataGroup
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                
                sectionLabel("Настройки")
                    .padding(.top, 26)
                
                group(settings)
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                
                Button {
                    
                } label: {
                    
                    Text("Выйти из аккаунта")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.red)
                }
                .padding(.top, 28)
                
                Text("Версия 1.0")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 10)
                
                Spacer()
                    .frame(height: 104)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "operations"
        ) { result in
            if case .failure = result {
                dataMessage = "Не удалось сохранить файл."
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text]
        ) { result in
            handleImport(result)
        }
        .alert(
            "Операции",
            isPresented: Binding(
                get: { dataMessage != nil },
                set: { if !$0 { dataMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dataMessage ?? "")
        }
    }
    
    // MARK: Data (export / import)
    
    private var dataGroup: some View {
        
        VStack(spacing: 0) {
            
            dataRow(
                icon: "square.and.arrow.up.fill",
                tint: .blue,
                title: "Экспорт операций",
                subtitle: "Файл CSV: даты, суммы, категории"
            ) {
                exportDocument = TransactionsFile(
                    text: TransactionCSV.export(TransactionStore.load())
                )
                isExporting = true
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            dataRow(
                icon: "square.and.arrow.down.fill",
                tint: .green,
                title: "Импорт операций",
                subtitle: "Загрузить файл — операции сами лягут по датам"
            ) {
                isImporting = true
            }
        }
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func dataRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        
        Button(action: action) {
            
            HStack(spacing: 10) {
                
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 30, height: 30)
                    .overlay {
                        
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(tint)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func handleImport(_ result: Result<URL, Error>) {
        
        guard case .success(let url) = result else {
            dataMessage = "Не удалось открыть файл."
            return
        }
        
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        
        guard
            let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1251)
        else {
            dataMessage = "Не удалось прочитать файл."
            return
        }
        
        let (merged, report) = TransactionCSV.importTransactions(
            from: text,
            into: TransactionStore.load()
        )
        
        if report.added > 0 {
            TransactionStore.save(merged)
        }
        
        var message = "Добавлено операций: \(report.added)."
        if report.duplicates > 0 {
            message += "\nУже были в приложении: \(report.duplicates)."
        }
        if report.failed > 0 {
            message += "\nНе удалось разобрать строк: \(report.failed)."
        }
        dataMessage = message
    }
    
    // MARK: Header
    
    private var header: some View {
        
        HStack {
            
            Text("Ещё")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: Profile card
    
    private var profileCard: some View {
        
        HStack(spacing: 12) {
            
            Circle()
                .fill(Color(white: 0.34))
                .frame(width: 52, height: 52)
                .overlay {
                    
                    Text("А")
                        .font(.system(size: 21))
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 3) {
                
                Text("Алексей")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("+7 000 000-00-00")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    // MARK: Group
    
    private func group(_ rows: [MoreRow]) -> some View {
        
        VStack(spacing: 0) {
            
            ForEach(rows) { row in
                
                HStack(spacing: 10) {
                    
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(row.tint.opacity(0.18))
                        .frame(width: 30, height: 30)
                        .overlay {
                            
                            Image(systemName: row.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(row.tint)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        
                        Text(row.title)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                        
                        if let subtitle = row.subtitle {
                            
                            Text(subtitle)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 14)
                .frame(height: row.subtitle == nil ? 50 : 58)
                .contentShape(Rectangle())
                
                if row.id != rows.last?.id {
                    
                    Divider()
                        .background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: Section label
    
    private func sectionLabel(_ text: String) -> some View {
        
        HStack {
            
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MoreView()
    }
    .preferredColorScheme(.dark)
}
