import SwiftUI
import UniformTypeIdentifiers

// MARK: - Валюта

/// Валюта приложения — белорусский рубль (BYN). Символ — "Br".
let currencySymbol = "Br"

/// Сумма со знаком и валютой: "1 200 Br" / "−350 Br".
func formattedMoney(_ value: Double) -> String {
    let sign = value < 0 ? "−" : ""
    return "\(sign)\(formattedAmount(abs(value))) \(currencySymbol)"
}

// MARK: - Итоги

enum FinanceSummary {
    /// Доходы минус расходы по списку операций.
    static func net(_ transactions: [Transaction]) -> Double {
        transactions.reduce(0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
    }
}

// MARK: - CSV: экспорт и импорт операций
//
// Формат (разделитель ";", кодировка UTF-8, открывается в Excel):
//
//   date;type;category;amount
//   2026-10-05 14:30;Расход;Супермаркеты;45.60
//   2026-10-01 09:00;Доход;Зарплата;2500
//
// При импорте каждая строка сама попадает в свою неделю, месяц и год —
// по дате, а в категорию — по названию из справочника (если названия нет
// в справочнике, ставится "Другое" для расходов и "Пополнения" для доходов).
// Дата принимается как 2026-10-05, 2026-10-05 14:30, 05.10.2026 или
// 05.10.2026 14:30; тип — Доход/Расход (или income/expense, +/−).
// Уже существующие операции (та же дата до минуты, тип, категория и
// сумма) повторно не добавляются, поэтому один и тот же файл можно
// загружать несколько раз.

enum TransactionCSV {

    static let header = "date;type;category;amount"

    struct ImportResult {
        var added = 0
        var duplicates = 0
        var failed = 0
    }

    // MARK: Export

    static func export(_ transactions: [Transaction]) -> String {
        let formatter = makeFormatter("yyyy-MM-dd HH:mm")
        var lines = [header]

        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            let type = transaction.type == .income ? "Доход" : "Расход"
            let name = transaction.categoryName.replacingOccurrences(of: ";", with: ",")
            lines.append(
                "\(formatter.string(from: transaction.date));\(type);\(name);\(amountString(transaction.amount))"
            )
        }

        // BOM — чтобы Excel сразу понял кодировку UTF-8.
        return "\u{FEFF}" + lines.joined(separator: "\n") + "\n"
    }

    private static func amountString(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
    }

    // MARK: Import

    static func importTransactions(
        from text: String,
        into existing: [Transaction]
    ) -> (merged: [Transaction], result: ImportResult) {

        var result = ImportResult()
        var merged = existing
        var seen = Set(existing.map(key(for:)))

        let cleaned = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        let lines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let firstLine = lines.first else { return (merged, result) }

        let delimiter: Character =
            firstLine.contains(";") ? ";" : (firstLine.contains("\t") ? "\t" : ",")

        for (index, line) in lines.enumerated() {
            let fields = line
                .split(separator: delimiter, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) }

            guard fields.count >= 4, let date = parseDate(fields[0]) else {
                // Первая строка без даты — заголовок, это не ошибка.
                if index > 0 { result.failed += 1 }
                continue
            }

            guard
                let amountRaw = parseAmount(fields[3]),
                amountRaw != 0
            else {
                result.failed += 1
                continue
            }

            let type = parseType(fields[1]) ?? (amountRaw < 0 ? .spending : .income)
            let amount = abs(amountRaw)
            let preset = category(named: fields[2], type: type)

            let transaction = Transaction(
                type: type,
                categoryIcon: preset.icon,
                categoryName: preset.name,
                amount: amount,
                date: date
            )

            let transactionKey = key(for: transaction)
            if seen.contains(transactionKey) {
                result.duplicates += 1
                continue
            }

            seen.insert(transactionKey)
            merged.append(transaction)
            result.added += 1
        }

        return (merged, result)
    }

    // MARK: Parsing helpers

    private static func key(for transaction: Transaction) -> String {
        let minute = Int(transaction.date.timeIntervalSince1970 / 60)
        let cents = Int((transaction.amount * 100).rounded())
        return "\(minute)|\(transaction.type.rawValue)|\(transaction.categoryIcon)|\(cents)"
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    private static func parseDate(_ string: String) -> Date? {
        let withTime = [
            "yyyy-MM-dd HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss",
            "dd.MM.yyyy HH:mm", "dd.MM.yyyy HH:mm:ss"
        ]
        for format in withTime {
            if let date = makeFormatter(format).date(from: string) { return date }
        }

        // Только дата — ставим полдень, чтобы операция гарантированно
        // осталась в этом дне при любом часовом поясе.
        for format in ["yyyy-MM-dd", "dd.MM.yyyy"] {
            if let day = makeFormatter(format).date(from: string) {
                return Calendar.current.date(byAdding: .hour, value: 12, to: day) ?? day
            }
        }
        return nil
    }

    private static func parseType(_ string: String) -> OperationType? {
        let value = string.lowercased()
        if ["доход", "income", "приход", "поступ", "+"].contains(where: { value.contains($0) }) {
            return .income
        }
        if ["расход", "трата", "траты", "spending", "expense", "списан", "-", "−"].contains(where: { value.contains($0) }) {
            return .spending
        }
        return nil
    }

    private static func parseAmount(_ string: String) -> Double? {
        let allowed = CharacterSet(charactersIn: "0123456789.,-−")
        var cleaned = String(string.unicodeScalars.filter { allowed.contains($0) })
        cleaned = cleaned
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    private static func category(named name: String, type: OperationType) -> PresetCategory {
        let lowered = name.lowercased()
        let preferred = type == .income ? PresetCategory.income : PresetCategory.expense

        if let match = preferred.first(where: { $0.name.lowercased() == lowered }) {
            return match
        }
        if let match = PresetCategory.all.first(where: { $0.name.lowercased() == lowered }) {
            return match
        }

        let fallbackName = type == .income ? "Пополнения" : "Другое"
        return preferred.first(where: { $0.name == fallbackName }) ?? preferred[0]
    }
}

// MARK: - Документ для fileExporter

struct TransactionsFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard
            let data = configuration.file.regularFileContents,
            let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
