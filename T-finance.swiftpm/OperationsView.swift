import SwiftUI

struct OperationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    /// Индекс в MonthData.months — общий источник правды и для чипа месяца,
    /// и для карусели колец в OperationDetailView (свайп кольца двигает чип).
    @State private var selectedMonthIndex = 0
    @State private var selectedWeekIndex = 0
    @State private var selectedYearIndex = 0
    @State private var selectedPeriod: OperationDetailView.Period = .month
    @State private var selectedRing: OperationType?
    @State private var isCalendarPresented = false
    @State private var selectedStartDate: Date?
    @State private var selectedEndDate: Date?

    /// Единственный источник правды — реальные операции пользователя (с
    /// настоящей датой каждой). Раньше здесь был словарь сумм по категориям,
    /// отдельно для каждой комбинации тип+период+индекс — из-за этого
    /// неделя/месяц/год были никак не связаны между собой: одну и ту же
    /// трату приходилось бы вносить трижды. Теперь сумма по любому кольцу
    /// (для любой недели/месяца/года) считается на лету — фильтрацией этого
    /// списка по датам конкретного периода (см. categories(for:)), поэтому
    /// добавленная операция сама попадает в свою неделю, свой месяц и свой
    /// год. Новый календарный месяц/неделя/год просто получает пустое
    /// кольцо — MonthData/WeekData/YearData уже считают свои индексы от
    /// реальной даты устройства (Date()), а не от захардкоженной точки
    /// отсчёта.
    @State private var transactions: [Transaction] = TransactionStore.load()
    
    private func saveTransactions() {
        TransactionStore.save(transactions)
    }
    @State private var isAddCategoryPresented = false
    
    /// Чип показывает "✕" вместо "▼", когда выбран конкретный период через
    /// календарь, либо когда кольцом пролистали не на текущую страницу —
    /// а "текущая" зависит от того, какой период сейчас выбран (Нед/Мес/Год),
    /// а не всегда от месяца.
    private var isMonthFilterActive: Bool {
        if selectedStartDate != nil { return true }
        
        switch selectedPeriod {
        case .month: return selectedMonthIndex != 0
        case .week: return selectedWeekIndex != 0
        case .year: return selectedYearIndex != 0
        }
    }
    
    /// Заголовок чипа: диапазон дат, если период выбран вручную,
    /// иначе — название текущего месяца ("Июль" и т.д.)
    private var periodChipTitle: String {
        
        if selectedPeriod == .year {
            return YearData.years[selectedYearIndex].title
        }
        
        if selectedPeriod == .week {
            return WeekData.weeks[selectedWeekIndex].title
        }
        
        guard let start = selectedStartDate else {
            return MonthData.months[selectedMonthIndex].title
        }
        
        let end = selectedEndDate ?? start
        return "\(shortDate(start)) – \(shortDate(end))"
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    // MARK: - Category aggregation
    
    /// Границы конкретного периода (неделя/месяц/год под данным индексом) —
    /// то, по чему реальные транзакции фильтруются для этого кольца. Общий
    /// для всех трёх каруселей источник дат (WeekOption/MonthOption/YearOption.dateRange),
    /// поэтому неделя, месяц и год всегда согласованы между собой.
    private func dateRange(for period: OperationDetailView.Period, index: Int) -> ClosedRange<Date> {
        switch period {
        case .week:
            guard WeekData.weeks.indices.contains(index) else { return Date()...Date() }
            return WeekData.weeks[index].dateRange
        case .month:
            guard MonthData.months.indices.contains(index) else { return Date()...Date() }
            return MonthData.months[index].dateRange
        case .year:
            guard YearData.years.indices.contains(index) else { return Date()...Date() }
            return YearData.years[index].dateRange
        }
    }
    
    /// Произвольный промежуток, выбранный через календарь (chip "Май" →
    /// "✕"), а не через один из трёх стандартных периодов. nil, если
    /// календарём ничего не выбрано — тогда в силе обычная логика
    /// Нед/Мес/Год. Конец диапазона растягивается до конца выбранного дня,
    /// чтобы операции, добавленные в течение последнего дня диапазона,
    /// тоже туда попадали.
    private var customDateRange: ClosedRange<Date>? {
        guard let start = selectedStartDate else { return nil }
        
        let calendar = Calendar.current
        let end = selectedEndDate ?? start
        
        let dayStart = calendar.startOfDay(for: start)
        let nextDayStart = calendar.date(
            byAdding: DateComponents(day: 1),
            to: calendar.startOfDay(for: end)
        ) ?? end
        let dayEnd = calendar.date(byAdding: .second, value: -1, to: nextDayStart) ?? end
        
        return dayStart...dayEnd
    }
    
    /// Период, который сейчас реально определяет, что показывать на кольце
    /// и в истории — либо произвольный промежуток из календаря (если он
    /// выбран), либо текущая страница карусели Нед/Мес/Год.
    private var effectiveDateRange: ClosedRange<Date> {
        customDateRange ?? dateRange(for: selectedPeriod, index: currentPeriodIndex)
    }
    
    private func transactions(for type: OperationType, in range: ClosedRange<Date>) -> [Transaction] {
        transactions.filter { $0.type == type && range.contains($0.date) }
    }
    
    private func transactions(for type: OperationType, period: OperationDetailView.Period, index: Int) -> [Transaction] {
        transactions(for: type, in: dateRange(for: period, index: index))
    }

    private func categories(for type: OperationType, period: OperationDetailView.Period, index: Int) -> [CategoryEntry] {
        let raw = TransactionStore.categoryTotals(from: transactions(for: type, period: period, index: index))
        // Сортировка по убыванию + схлопывание хвоста в "Остальное" — здесь,
        // а не в каждом месте отображения, чтобы кольцо (CategoryDonut) и
        // чипы под ним (categoryChips) всегда показывали один и тот же
        // порядок и состав сегментов.
        return raw.groupedForDisplay()
    }

    private var currentPeriodIndex: Int {
        switch selectedPeriod {
        case .month: selectedMonthIndex
        case .week: selectedWeekIndex
        case .year: selectedYearIndex
        }
    }

    private var currentCategories: [CategoryEntry] {
        // Календарный промежуток — в приоритете: если он выбран, кольцо
        // должно показывать именно траты внутри него, а не то кольцо
        // Нед/Мес/Год, на котором в этот момент случайно стоит карусель.
        if let customDateRange {
            return TransactionStore.categoryTotals(from: transactions(for: activeType, in: customDateRange))
                .groupedForDisplay()
        }
        return categories(for: activeType, period: selectedPeriod, index: currentPeriodIndex)
    }

    /// То же самое сырое хранилище, что и categories(for:), но без
    /// схлопывания в "Остальное" — нужно, чтобы шит по тапу на капсулу
    /// "Остальное" показал реальные категории, а не уже сгруппированные.
    private func otherCategories(for type: OperationType, period: OperationDetailView.Period, index: Int) -> [CategoryEntry] {
        let raw = TransactionStore.categoryTotals(from: transactions(for: type, period: period, index: index))
        return raw.otherCategoriesForDisplay()
    }

    private var currentOtherCategories: [CategoryEntry] {
        if let customDateRange {
            return TransactionStore.categoryTotals(from: transactions(for: activeType, in: customDateRange))
                .otherCategoriesForDisplay()
        }
        return otherCategories(for: activeType, period: selectedPeriod, index: currentPeriodIndex)
    }

    private func categoriesForMonth(_ index: Int) -> [CategoryEntry] {
        categories(for: activeType, period: .month, index: index)
    }

    private func categoriesForWeek(_ index: Int) -> [CategoryEntry] {
        categories(for: activeType, period: .week, index: index)
    }

    private func categoriesForYear(_ index: Int) -> [CategoryEntry] {
        categories(for: activeType, period: .year, index: index)
    }

    /// Добавляет реальную операцию — с суммой/категорией из AddCategorySheet
    /// и датой, попадающей внутрь того периода, который сейчас открыт:
    /// произвольный промежуток из календаря, если он выбран, иначе —
    /// текущая страница карусели (сегодняшняя дата, если "сегодня"
    /// укладывается в этот период — иначе начало периода, если добавляют
    /// задним числом). Это единственное место, где рождается Transaction —
    /// дальше он сам агрегируется в свою неделю/месяц/год.
    private func addCategory(_ entry: CategoryEntry) {
        let range = effectiveDateRange
        let now = Date()
        let date = range.contains(now) ? now : range.lowerBound
        
        let transaction = Transaction(
            type: activeType,
            categoryIcon: entry.icon,
            categoryName: entry.name,
            amount: entry.amount,
            date: date
        )
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            transactions.append(transaction)
        }
    }
    
    /// Удаляет категорию полностью (тройной тап по плашке) — убирает ВСЕ
    /// реальные операции этой категории, попадающие в открытый период
    /// (произвольный промежуток из календаря, если выбран, иначе текущую
    /// страницу карусели), а не только уменьшает сумму.
    private func deleteCategory(_ entry: CategoryEntry) {
        let range = effectiveDateRange
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            transactions.removeAll {
                $0.type == activeType
                && $0.categoryIcon == entry.icon
                && range.contains($0.date)
            }
        }
    }

    /// Сумма по типу за текущий выбранный период (используется и заголовком
    /// в hero-overlay, и карточками на главном экране — один источник
    /// правды для обоих мест, чтобы они не расходились).
    private func totalAmount(for type: OperationType) -> Double {
        categories(for: type, period: selectedPeriod, index: currentPeriodIndex)
            .reduce(0) { $0 + $1.amount }
    }

    /// Заголовок ("Нет трат"/"Нет доходов" или сумма) для конкретного типа —
    /// то же правило, что и в OperationDetailView.displayTitle.
    private func displayTitle(for type: OperationType) -> String {
        let total = totalAmount(for: type)
        return total > 0 ? "\(formattedAmount(total)) \(currencySymbol)" : type.title
    }
    

    /// Frames published by the invisible title placeholders (compact card
    /// titles + expanded detail title), collected via FramePreferenceKey.
    @State private var heroFrames: [String: CGRect] = [:]
@State private var pullOffset: CGFloat = 0

    // MARK: - Collapsing header (поиск → фильтры → карточки)
    //
    // Аналог contentOffset у скролла: 0 — шапка раскрыта, collapseRange —
    // свёрнута полностью. Сначала (0...searchCollapseRange) сужается и
    // пропадает строка поиска, затем (дальше cardsCollapseRange) сжимаются
    // карточки "Нет трат"/"Нет доходов": пропадает полоска снизу и уменьшается
    // высота. Фильтры при этом поднимаются вверх вместе с поиском.

    @State private var collapse: CGFloat = 0
    @State private var listScroll = ScrollPosition(edge: .top)

    private let searchCollapseRange: CGFloat = DS.searchHeight + 16
    private let cardsCollapseRange: CGFloat = 30
    private var collapseRange: CGFloat { searchCollapseRange + cardsCollapseRange }

    private var effectiveCollapse: CGFloat {
        min(max(collapse, 0), collapseRange)
    }

    private var searchFieldHeight: CGFloat {
        max(0, min(DS.searchHeight, searchCollapseRange - effectiveCollapse - 16))
    }

    private var searchBottomPadding: CGFloat {
        max(0, min(16, searchCollapseRange - effectiveCollapse))
    }

    private var searchContentOpacity: Double {
        Double(max(0, 1 - effectiveCollapse / 12))
    }

    /// 0 — карточки полные, 1 — сжаты до минимума.
    private var cardsCompact: CGFloat {
        min(max((effectiveCollapse - searchCollapseRange) / cardsCollapseRange, 0), 1)
    }

    /// Тонкая линия над фильтрами, пока поиск уезжает под шапку.
    private var collapseDivider: some View {
        let o = effectiveCollapse
        let visibility = min(1, o / 4) * max(0, min(1, (44 - o) / 8))
        return Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 0.5)
            .offset(y: -5)
            .opacity(Double(visibility))
            .allowsHitTesting(false)
    }

    private var isExpanded: Bool { selectedRing != nil }

    /// OperationDetailView stays permanently mounted (see rationale there),
    /// so it always needs *some* type to lay out its title placeholder with —
    /// falls back to .spending while collapsed.
    private var activeType: OperationType { selectedRing ?? .spending }

    var body: some View {
        ZStack {
            // Единый фон на уровне корневого экрана — никогда не пересоздаётся
            // и не фейдится сам по себе, поэтому нет ощущения "новой страницы".
            DS.background
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // "Закрыть" закрывает всю шторку целиком, а не только
                // детали кольца (для деталей есть крестик справа).
                OperationsHeader(showClose: true) {
                    dismiss()
                }

                VStack(spacing: 0) {

                    SearchField(
                        text: $searchText,
                        height: searchFieldHeight,
                        contentOpacity: searchContentOpacity,
                        bottomPadding: searchBottomPadding
                    )

                    filterChips
                        .overlay(alignment: .top) { collapseDivider }

                    // Оба состояния смонтированы постоянно и кросс-фейдятся через
                    // opacity — никакого if/else, который убирал бы view из
                    // дерева и ломал анимацию заголовка.
                    ZStack {
                        collapsedContent
                            .opacity(isExpanded ? 0 : 1)
                            .allowsHitTesting(!isExpanded)

                        OperationDetailView(
                            type: activeType,
                            isExpanded: isExpanded,
                            selectedMonthIndex: $selectedMonthIndex,
                            selectedWeekIndex: $selectedWeekIndex,
                            selectedYearIndex: $selectedYearIndex,
                            selectedPeriod: $selectedPeriod,
                            currentCategories: currentCategories,
                            currentOtherCategories: currentOtherCategories,
                            transactions: transactions,
                            customDateRange: customDateRange,
                            categoriesForMonth: categoriesForMonth,
                            categoriesForWeek: categoriesForWeek,
                            categoriesForYear: categoriesForYear,
                            onRingTap: {
                                isAddCategoryPresented = true
                            },
                            onDeleteCategory: { entry in
                                deleteCategory(entry)
                            },
                            onClearCustomRange: {
                                selectedStartDate = nil
                                selectedEndDate = nil
                                selectedMonthIndex = 0
                            },
                            close: {
                                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                                    selectedRing = nil
                                }
                            }
                        )
                        .allowsHitTesting(isExpanded)
                    }
                }
            }

            heroTitleOverlay
        }
        .coordinateSpace(name: "hero")
        .onPreferenceChange(FramePreferenceKey.self) { heroFrames = $0 }
        .onChange(of: transactions) { _, _ in
            saveTransactions()
        }
        .sheet(isPresented: $isCalendarPresented) {
            PeriodCalendarView(
                initialMonth: MonthData.months[selectedMonthIndex].firstDate,
                startDate: $selectedStartDate,
                endDate: $selectedEndDate,
                onDone: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        updateMonthFromSelectedPeriod()
                    }
                    isCalendarPresented = false
                },
                onClose: {
                    isCalendarPresented = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(22)
        }
        .sheet(isPresented: $isAddCategoryPresented) {
            AddCategorySheet(
                isIncome: activeType == .income,
                onAdd: { entry in
                    addCategory(entry)
                    isAddCategoryPresented = false
                },
                onClose: {
                    isAddCategoryPresented = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(22)
        }
    }

    // MARK: - Collapsed content (cards + empty list state)

    /// Все операции (и доходы, и расходы) за выбранный период, с учётом поиска.
    private var visibleOperations: [Transaction] {
        let range = effectiveDateRange
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return transactions
            .filter { range.contains($0.date) }
            .filter { query.isEmpty || $0.categoryName.lowercased().contains(query) }
            .sorted { $0.date > $1.date }
    }

    private var historyGranularity: HistoryGranularity {
        if customDateRange != nil { return .month }
        switch selectedPeriod {
        case .week: return .week
        case .month: return .month
        case .year: return .year
        }
    }

    private var collapsedContent: some View {
        VStack(spacing: 0) {
            summaryCards
                .offset(y: pullOffset)

            ZStack {
                GeometryReader { geo in
                    ScrollView {
                        TransactionHistorySection(
                            transactions: visibleOperations,
                            granularity: historyGranularity
                        )
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        // Минимальная высота даёт прокрутку даже когда
                        // операций мало — шапка всё равно успевает свернуться.
                        .frame(
                            maxWidth: .infinity,
                            minHeight: geo.size.height + collapseRange,
                            alignment: .top
                        )
                    }
                    .scrollPosition($listScroll)
                    .scrollBounceBehavior(.always)
                    .onScrollGeometryChange(for: CGFloat.self) { scroll in
                        scroll.contentOffset.y + scroll.contentInsets.top
                    } action: { _, offset in
                        collapse = min(max(offset, 0), collapseRange)
                    }
                }

                if visibleOperations.isEmpty {
                    // Шапка сжимается, а подсказка по центру остаётся на месте —
                    // компенсируем сдвиг, который даёт центрирование.
                    Text("Тут будем показывать\nвсе ваши операции")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DS.textSecondary)
                        .font(.system(size: DS.emptyStateCompactFont))
                        .offset(y: (min(effectiveCollapse, searchCollapseRange) + cardsCompact * 29) / 2)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(
                    title: periodChipTitle,
                    isActive: true,
                    showChevron: !isMonthFilterActive,
                    showClose: isMonthFilterActive,
                    onTap: {
                        isCalendarPresented = true
                    },
                    onClose: {
                        guard isMonthFilterActive else { return }
                        
                        selectedStartDate = nil
                        selectedEndDate = nil
                        
                        switch selectedPeriod {
                        case .month: selectedMonthIndex = 0
                        case .week: selectedWeekIndex = 0
                        case .year: selectedYearIndex = 0
                        }
                    }
                )
                Chip(
                    title: "Счета и карты",
                    showChevron: true,
                    onTap: {}
                )
                
                Chip(
                    title: "Без переводов",
                    onTap: {}
                )
            }
            .padding(.leading, 18)
            .padding(.trailing, DS.margin)
        }
        .padding(.bottom, DS.rowGap)
    }

    // MARK: - Summary cards

    private var summaryCards: some View {
        HStack(spacing: DS.rowGap) {
            SummaryCard(
                type: .spending,
                amount: totalAmount(for: .spending),
                categories: categories(for: .spending, period: selectedPeriod, index: currentPeriodIndex),
                compact: cardsCompact
            ) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    collapse = 0
                    resetPeriodIndices()
                    selectedRing = .spending
                }
            }

            SummaryCard(
                type: .income,
                amount: totalAmount(for: .income),
                categories: categories(for: .income, period: selectedPeriod, index: currentPeriodIndex),
                compact: cardsCompact
            ) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    collapse = 0
                    resetPeriodIndices()
                    selectedRing = .income
                }
            }
        }
        .padding(.horizontal, DS.margin)
    }
    
    /// При любом открытии деталей (тап по карточке "Нет трат"/"Нет доходов")
    /// все три карусели — месяцы, недели, годы — должны стартовать с крайнего
    /// (самого нового) кольца, а не с того места, где их оставили в прошлый раз.
    private func resetPeriodIndices() {
        listScroll.scrollTo(y: 0)
        selectedMonthIndex = 0
        selectedWeekIndex = 0
        selectedYearIndex = 0
    }

    // MARK: - Hero title overlay
    //
    // The only visibly-rendered copy of each operation title. Both card
    // titles and the detail title are invisible placeholders (opacity 0);
    // these two Text views are what the user actually sees, and they are
    // simply repositioned/rescaled from `isExpanded` inside a withAnimation
    // block — a persistent, state-driven view rather than a transition
    // attached to a view being mounted/unmounted.

    private var heroTitleOverlay: some View {
        ZStack(alignment: .topLeading) {
            ForEach([OperationType.spending, .income]) { type in
                let isActive = selectedRing == type
                let frame = isActive
                    ? heroFrames["detailTitle"]
                    : heroFrames["card_\(type.id)"]

                if let frame = frame {
                    Text(displayTitle(for: type))
                        .font(.system(size: DS.detailTitleFont, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .contentTransition(.opacity)
                        .scaleEffect(isActive ? 1 : DS.cardTitleScale, anchor: .topLeading)
                        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                      .offset(x: frame.minX + (isActive ? 3 : 0), y: frame.minY)
                        // The inactive title's card fades away with the rest
                        // of collapsedContent — hide its hero too, or it'd be
                        // left floating with no card behind it.
                        .opacity(selectedRing == nil || isActive ? 1 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
    private func updateMonthFromSelectedPeriod() {
        guard let date = selectedStartDate else {
            return
        }
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        
        guard let index = MonthData.months.firstIndex(where: {
            $0.year == year && $0.month == month
        }) else {
            return
        }
        
        selectedMonthIndex = index
    }
}

// MARK: - Summary card

private struct SummaryCard: View {
    let type: OperationType
    let amount: Double
    let categories: [CategoryEntry]
    /// 0 — карточка полная, 1 — сжата (полоска исчезла, высота меньше).
    var compact: CGFloat = 0
    let action: () -> Void

    private var cardHeight: CGFloat {
        let minHeight: CGFloat = amount > 0 ? 82 : 76
        return 105 - (105 - minHeight) * compact
    }

    private var displayTitle: String {
        amount > 0 ? "\(formattedAmount(amount)) \(currencySymbol)" : type.title
    }

    /// Та же группировка, что уже используется кольцом (топ-5 + "Остальное"
    /// хвостом) — так порядок и цвета сегментов в капсуле совпадают с тем,
    /// что человек видит на самом кольце, когда открывает детали.
    private var barSegments: [CategoryEntry] {
        categories.groupedForDisplay()
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Реальный текст здесь невидим — единственная видимая копия
                // рисуется как hero-overlay в OperationsView. Этот Text нужен
                // только чтобы резервировать место в layout'е и опубликовать
                // свой фрейм для измерения. Строка должна совпадать с тем,
                // что покажет hero-overlay (displayTitle) — иначе измеренный
                // фрейм останется под "Нет трат" и сумма не впишется.
                Text(displayTitle)
                    .font(.system(size: DS.detailTitleFont, weight: .medium))
                    .fixedSize()
                    .scaleEffect(DS.cardTitleScale, anchor: .topLeading)
                    .frame(
                        width: 170 - DS.cardPadding * 2,
                        height: DS.cardTitleFont * 1.25,
                        alignment: .topLeading
                    )
                    .opacity(0)
                    .measureFrame(id: "card_\(type.id)")
                
                if amount > 0 {
                    Text(type.shortTitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white)
                        .padding(.top, 3)
                }
                

                Spacer(minLength: 0)

                HStack {
                    if amount > 0, !barSegments.isEmpty {
                        // Сегментированная капсула цветами категорий —
                        // ширина каждого сегмента пропорциональна его доле
                        // в общей сумме, сегменты идут вплотную друг к другу,
                        // а Capsule() снаружи скругляет только крайние края.
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                ForEach(barSegments) { category in
                                    Rectangle()
                                        .fill(category.color)
                                        .frame(
                                            width: max(
                                                0,
                                                geo.size.width * CGFloat(category.amount / amount)
                                            )
                                        )
                                }
                            }
                        }
                        .frame(width: 130, height: DS.capsuleBarHeight)
                        .clipShape(Capsule())
                    } else {
                        // Серая капсула-плейсхолдер — только пока по этому
                        // типу ещё нет ни одной операции.
                        Capsule()
                            .fill(DS.capsulePlaceholder)
                            .frame(width: 130, height: DS.capsuleBarHeight)
                            .fixedSize()
                    }

                    Spacer()
                }
                .opacity(Double(max(0, 1 - compact * 2.5)))
            }
            .padding(DS.cardPadding)
            .frame(width: 170, alignment: .leading)
            .frame(height: cardHeight, alignment: .topLeading)
            .background(DS.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OperationsView()
        .preferredColorScheme(.dark)

}
