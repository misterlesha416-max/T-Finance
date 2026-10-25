import SwiftUI

// MARK: - Transaction (реальная операция пользователя)
//
// Раньше здесь не было записей по отдельным операциям — только суммы по
// категориям (CategoryEntry) за период, а история строилась синтетически
// (см. старую TransactionHistory.synthesize). Теперь Transaction — это
// единственный источник правды: каждая запись, которую пользователь
// добавляет через AddCategorySheet, становится одной строкой здесь, с
// настоящей датой. Суммы по категориям для любого кольца (неделя/месяц/год)
// считаются агрегацией этого списка по датам конкретного периода —
// см. TransactionStore.categories(...). Так все три карусели остаются
// согласованными: одна и та же операция автоматически попадает в свою
// неделю, свой месяц и свой год, без необходимости вносить её трижды.

struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID
    var type: OperationType
    var categoryIcon: String
    var categoryName: String
    var amount: Double
    var date: Date
    /// Название магазина/организации, которое вписал пользователь (см.
    /// MerchantStore). Optional — старые операции без названия декодируются.
    var merchantName: String?
    
    init(
        id: UUID = UUID(),
        type: OperationType,
        categoryIcon: String,
        categoryName: String,
        amount: Double,
        date: Date,
        merchantName: String? = nil
    ) {
        self.id = id
        self.type = type
        self.categoryIcon = categoryIcon
        self.categoryName = categoryName
        self.amount = amount
        self.date = date
        self.merchantName = merchantName
    }
    
    /// Цвет категории не хранится — как и в CategoryEntry, он однозначно
    /// определяется иконкой через справочник PresetCategory.
    var categoryColor: Color {
        PresetCategory.all.first(where: { $0.icon == categoryIcon })?.color ?? DS.textSecondary
    }
}

// MARK: - Storage & aggregation

enum TransactionStore {
    private static let storageKey = "transactions"
    
    static func load() -> [Transaction] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Transaction].self, from: data)
        else {
            return []
        }
        return decoded
    }
    
    static func save(_ transactions: [Transaction]) {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    /// Схлопывает список реальных транзакций в суммы по категориям — один
    /// CategoryEntry на иконку категории, сумма всех транзакций с этой
    /// иконкой. Порядок/группировка "топ-5 + Остальное" накладывается
    /// отдельно через .groupedForDisplay() у вызывающего кода (то же самое
    /// разделение, что было раньше между "сырым" списком и отображаемым).
    static func categoryTotals(from transactions: [Transaction]) -> [CategoryEntry] {
        var byIcon: [String: (name: String, amount: Double, color: Color)] = [:]
        
        for transaction in transactions {
            byIcon[transaction.categoryIcon, default: (transaction.categoryName, 0, transaction.categoryColor)]
                .amount += transaction.amount
        }
        
        // Порядок словаря случайный и меняется от вызова к вызову — при
        // равных суммах категории «прыгали» местами на каждом обновлении
        // экрана. Фиксируем порядок: сумма по убыванию, затем иконка.
        return byIcon
            .sorted { lhs, rhs in
                lhs.value.amount != rhs.value.amount
                    ? lhs.value.amount > rhs.value.amount
                    : lhs.key < rhs.key
            }
            .map { icon, value in
                CategoryEntry(name: value.name, amount: value.amount, icon: icon, color: value.color)
            }
    }
}

// MARK: - Grouping & header formatting

enum HistoryGranularity {
    case week   // "Сегодня" / "Вчера" / "29 мая"
    case month  // "29 мая"
    case year   // "Май"
}

private struct HistoryGroup: Identifiable {
    let id: String
    let header: String
    let total: Double
    let transactions: [Transaction]
}

private func historyGroups(
    for transactions: [Transaction],
    granularity: HistoryGranularity
) -> [HistoryGroup] {
    let calendar = Calendar.current

    let keyed: [(key: Date, transaction: Transaction)] = transactions.map { transaction in
        switch granularity {
        case .week, .month:
            let day = calendar.startOfDay(for: transaction.date)
            return (day, transaction)
        case .year:
            let comps = calendar.dateComponents([.year, .month], from: transaction.date)
            let monthStart = calendar.date(from: comps) ?? transaction.date
            return (monthStart, transaction)
        }
    }

    let grouped = Dictionary(grouping: keyed, by: { $0.key })

    return grouped.keys.sorted(by: >).map { key in
        let items = grouped[key]!.map { $0.transaction }.sorted { $0.date > $1.date }
        // Со знаком: доходы плюсуются, расходы вычитаются — в одной группе
        // (день) на общей странице могут быть и те и другие.
        let total = items.reduce(0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
        return HistoryGroup(
            id: key.description,
            header: header(for: key, granularity: granularity, calendar: calendar),
            total: total,
            transactions: items
        )
    }
}

private func header(for date: Date, granularity: HistoryGranularity, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")

    switch granularity {
    case .week:
        if calendar.isDateInToday(date) { return "Сегодня" }
        if calendar.isDateInYesterday(date) { return "Вчера" }
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)

    case .month:
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)

    case .year:
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - History list view

struct TransactionHistorySection: View {
    let transactions: [Transaction]
    let granularity: HistoryGranularity

    private var groups: [HistoryGroup] {
        historyGroups(for: transactions, granularity: granularity)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(groups) { group in
                HStack {
                    Text(group.header)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(group.total >= 0 ? "+" : "−")\(formattedAmount(abs(group.total))) \(currencySymbol)")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(DS.textSecondary)
                }
                .padding(.horizontal, DS.margin)
                .padding(.top, 10)
                .padding(.bottom, 8)

                ForEach(group.transactions) { transaction in
                    TransactionRow(transaction: transaction)
                        .padding(.horizontal, DS.margin)
                        .padding(.vertical, 14)
                }
            }
        }
    }
}

private struct TransactionRow: View {
    let transaction: Transaction
    
    private var isIncome: Bool { transaction.type == .income }
    
    /// Времени операции у нас нет отдельного поля ввода — это фактическое
    /// время, когда пользователь нажал "Готово" в AddCategorySheet.
    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: transaction.date)
    }

    /// Иконка магазина, если пользователь её загрузил; иначе — иконка категории.
    @ViewBuilder
    private var avatar: some View {
        if let name = transaction.merchantName,
           let logo = MerchantStore.logo(forName: name) {
            Image(uiImage: logo)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(transaction.categoryColor)

                CategoryIconImage(icon: transaction.categoryIcon)
                    .frame(width: 22, height: 22)
            }
        }
    }

    /// Для операции с магазином под названием — категория, как в списке
    /// Т-Банка. Без магазина название и так равно категории.
    private var subtitle: String? {
        transaction.merchantName == nil ? nil : transaction.categoryName
    }

    /// Строка как в списке операций Т-Банка: слева иконка, название и
    /// подпись; справа сумма (доход — зелёным) и название счёта под ней.
    var body: some View {
        HStack(spacing: 14) {
            avatar
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchantName ?? transaction.categoryName)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Время не показываем: под названием магазина — только категория.
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(DS.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(isIncome ? "+" : "−")\(formattedAmount(transaction.amount)) \(currencySymbol)")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(isIncome ? Color(red: 52/255, green: 199/255, blue: 89/255) : .white)
                    .lineLimit(1)

                Text("Моя карта")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
