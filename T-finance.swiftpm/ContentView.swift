import SwiftUI
import PhotosUI

// MARK: - Card model

struct CardData: Codable, Identifiable {
    let id: UUID
    var number: String
    var imageData: Data?
    var designIndex: Int
    var numberColor: String
    
    init(
        number: String,
        imageData: Data? = nil,
        designIndex: Int = 0,
        numberColor: String = "white"
    ) {
        self.id = UUID()
        self.number = number
        self.imageData = imageData
        self.designIndex = designIndex
        self.numberColor = numberColor
    }
}

// MARK: - Card storage

enum CardStorage {
    
    private static let key = "saved_black_cards"
    
    static func saveCards(_ cards: [CardData]) {
        do {
            let data = try JSONEncoder().encode(cards)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Ошибка сохранения карт: \(error)")
        }
    }
    
    static func loadCards() -> [CardData] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode(
                [CardData].self,
                from: data
            )
        } catch {
            print("Ошибка загрузки карт: \(error)")
            return []
        }
    }
}

// MARK: - App tab

enum AppTab {
    case home
    case payments
    case analytics
    case chat
    case more
}

// MARK: - ContentView

struct ContentView: View {
    
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    
    @State private var showOperations = false
    @State private var operationsDragOffset: CGFloat = 0
    
    // MARK: All operations (screens from FinanceApp)
    
    @State private var showAllOperations = false
    
    /// Те же операции, что сохраняет вкладка "Операции" (ключ "transactions" в
    /// UserDefaults). @AppStorage следит за ключом, поэтому карточка "Все
    /// операции" обновляется сама, как только в шторке что-то добавили или удалили.
    @AppStorage("transactions") private var transactionsData = Data()
    
    private static let monthsPrepositional = [
        "январе", "феврале", "марте", "апреле", "мае", "июне",
        "июле", "августе", "сентябре", "октябре", "ноябре", "декабре"
    ]
    
    private var currentMonthPrepositional: String {
        let month = Calendar.current.component(.month, from: Date())
        return Self.monthsPrepositional[month - 1]
    }
    
    /// Траты за текущий месяц — тот же период (MonthData.months[0]) и та же
    /// группировка, что у кольца в OperationsView.
    private var allTransactions: [Transaction] {
        (try? JSONDecoder().decode([Transaction].self, from: transactionsData)) ?? []
    }
    
    /// Баланс карты: все доходы минус все расходы.
    private var totalBalance: Double {
        FinanceSummary.net(allTransactions)
    }
    
    /// Бюджет месяца: что остаётся после доходов и расходов текущего месяца.
    private var monthBudgetLeft: Double {
        let range = MonthData.months[0].dateRange
        return FinanceSummary.net(allTransactions.filter { range.contains($0.date) })
    }
    
    private var monthSpendingCategories: [CategoryEntry] {
        let all = allTransactions
        let range = MonthData.months[0].dateRange
        let spending = all.filter { $0.type == .spending && range.contains($0.date) }
        return TransactionStore.categoryTotals(from: spending).groupedForDisplay()
    }
    
    private var monthSpendingTotal: Double {
        monthSpendingCategories.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: Tabs
    
    @State private var selectedTab: AppTab = .home
    
    // MARK: Cards
    
    @State private var cards: [CardData] = []
    @State private var selectedCardIndex = 0
    
    // MARK: Editing
    
    @State private var selectedCardImage: PhotosPickerItem? = nil
    @State private var cardNumberText = ""
    
    private let maxCards = 3
    
    // MARK: Card designs
    
    private let cardDesigns: [LinearGradient] = [
        
        LinearGradient(
            colors: [
                Color(white: 0.17),
                Color(white: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        
        LinearGradient(
            colors: [
                Color(red: 0.50, green: 0.47, blue: 0.87),
                Color(red: 0.15, green: 0.13, blue: 0.36)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        
        LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.62, blue: 0.46),
                Color(red: 0.02, green: 0.20, blue: 0.17)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        
        LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.35, blue: 0.19),
                Color(red: 0.29, green: 0.11, blue: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    ]
    
    // MARK: Init
    
    init() {
        
        let loadedCards = CardStorage.loadCards()
        
        if loadedCards.isEmpty {
            
            _cards = State(
                initialValue: [
                    CardData(
                        number: "6505",
                        imageData: nil,
                        designIndex: 0,
                        numberColor: "white"
                    )
                ]
            )
            
        } else {
            
            _cards = State(
                initialValue: loadedCards
            )
        }
    }
    
    // MARK: Body
    
    var body: some View {
        
        ZStack(alignment: .bottom) {
            
            Color.black
                .ignoresSafeArea()
            
            // MARK: Main screen
            
            ZStack(alignment: .bottom) {
                
                if selectedTab == .home {
                    
                    ScrollView(showsIndicators: false) {
                        
                        VStack(spacing: 0) {
                            
                            profileHeader
                                .padding(.top, 22)
                            
                            searchField
                                .padding(.top, 16)
                            
                            promoCards
                                .padding(.top, 18)
                            
                            mainCards
                                .padding(.top, 20)
                            
                            accountCard
                                .padding(.top, 18)
                            
                            promoBanner
                                .padding(.top, 18)
                            
                            Spacer()
                                .frame(height: 104)
                        }
                        .padding(.top, 30)
                        .background(
                            GeometryReader { proxy in
                                
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: proxy
                                            .frame(in: .named("mainScroll"))
                                            .minY
                                    )
                            }
                        )
                    }
                    .coordinateSpace(name: "mainScroll")
                    .onPreferenceChange(
                        ScrollOffsetPreferenceKey.self
                    ) { value in
                        scrollOffset = value
                    }
                }
                
                if selectedTab == .payments {
                    
                    PaymentsView()
                        .transition(.opacity)
                }
                
                if selectedTab == .analytics {
                    
                    AnalyticsView()
                        .transition(.opacity)
                }
                
                if selectedTab == .chat {
                    
                    ChatView()
                        .transition(.opacity)
                }
                
                if selectedTab == .more {
                    
                    MoreView()
                        .transition(.opacity)
                }
                
                bottomTabBar
                
                Color.white
                    .opacity(
                        showOperations
                        ? 0.10 * (1 - operationsProgress)
                        : 0
                    )
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .bottom)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
            .background(Color.black)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )
            .scaleEffect(
                showOperations
                ? 0.94 + (0.06 * operationsProgress)
                : 1.0,
                anchor: .top
            )
            .offset(
                y: showOperations
                ? 22 * (1 - operationsProgress)
                : 0
            )
            
            // MARK: Dim background
            
            if showOperations {
                
                Color.black
                    .opacity(
                        0.06 * (1 - operationsProgress)
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(5)
            }
            
            // MARK: Operations
            
            if showOperations {
                
                operationsView
                    .transition(
                        .move(edge: .bottom)
                        .combined(with: .opacity)
                    )
                    .zIndex(10)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAllOperations) {
            
            OperationsView()
                .preferredColorScheme(.dark)
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(10)
        }
    }
    
    // MARK: Scroll Offset
    
    private struct ScrollOffsetPreferenceKey: PreferenceKey {
        
        static var defaultValue: CGFloat = 0
        
        static func reduce(
            value: inout CGFloat,
            nextValue: () -> CGFloat
        ) {
            value = nextValue()
        }
    }
    
    // MARK: Operations progress
    
    private var operationsProgress: CGFloat {
        
        let height =
        UIScreen.main.bounds.height * 0.963
        
        return min(
            max(
                operationsDragOffset / height,
                0
            ),
            1
        )
    }
    
    // MARK: Number color
    
    private func cardNumberColor(
        _ color: String
    ) -> Color {
        
        switch color {
            
        case "blue":
            return .blue
            
        case "green":
            return .green
            
        case "red":
            return .red
            
        case "yellow":
            return .yellow
            
        case "gray":
            return .gray
            
        case "white":
            return .white
            
        default:
            return .white
        }
    }
    
    // MARK: Profile
    
    private var profileHeader: some View {
        
        HStack(spacing: 11) {
            
            Circle()
                .fill(Color(white: 0.34))
                .frame(
                    width: 40,
                    height: 40
                )
                .overlay {
                    
                    Text("A")
                        .font(
                            .system(
                                size: 17,
                                weight: .regular
                            )
                        )
                        .foregroundStyle(.white)
                }
            
            Text("Алексей")
                .font(
                    .system(
                        size: 27,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
            
            Image(systemName: "chevron.right")
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: Search
    
    private var searchField: some View {
        
        let progress = min(
            max(-scrollOffset / 70, 0),
            1
        )
        
        return ZStack {
            
            HStack(spacing: 9) {
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        Color.white.opacity(0.50)
                    )
                
                ZStack(alignment: .leading) {
                    
                    if searchText.isEmpty {
                        
                        Text("Поиск")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                Color.white.opacity(0.50)
                            )
                            .offset(x: -6)
                    }
                    
                    TextField(
                        "",
                        text: $searchText
                    )
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 34)
            .background(
                Color(
                    red: 0.105,
                    green: 0.105,
                    blue: 0.115
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )
            .scaleEffect(
                x: 1,
                y: 1 - progress,
                anchor: .bottom
            )
            .opacity(1 - progress)
            
            HStack {
                
                Text("Главная")
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .opacity(progress)
            .scaleEffect(
                x: 1,
                y: 0.85 + progress * 0.15,
                anchor: .bottom
            )
        }
        .frame(height: 34)
        .padding(.horizontal, 16)
    }
    
    // MARK: Promo cards
    
    private var promoCards: some View {
        
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            
            HStack(spacing: 6) {
                
                PromoCard(
                    title: "Сегодня",
                    subtitle: "−1 240 Br",
                    icon: "calendar"
                )
                
                PromoCard(
                    title: "Подписки",
                    subtitle: "1 890 Br",
                    icon: "repeat"
                )
                
                PromoCard(
                    title: "Регулярные",
                    subtitle: "19 авг",
                    icon: "clock.fill"
                )
                
                PromoCard(
                    title: "Прогноз",
                    subtitle: "28 400 Br",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: Main cards
    
    private var mainCards: some View {
        
        HStack(spacing: 20) {
            
            operationCard
            budgetCard
        }
        .padding(.horizontal, 16)
    }
    
    private var operationCard: some View {
        
        RoundedRectangle(
            cornerRadius: 24,
            style: .continuous
        )
        .fill(
            Color(
                red: 0.110,
                green: 0.110,
                blue: 0.118
            )
        )
        .frame(
            width: 165,
            height: 125
        )
        .overlay(alignment: .topLeading) {
            
            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                
                Text("Все операции")
                    .font(
                        .system(
                            size: 16,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                
                if monthSpendingTotal > 0 {
                    Text("Трат в \(currentMonthPrepositional)\n\(formattedAmount(monthSpendingTotal)) \(currencySymbol)")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(.top, 12)
                } else {
                    Text("Нет трат\nв \(currentMonthPrepositional)")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(.top, 12)
                }
                
                Spacer()
                
                if monthSpendingTotal > 0 {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(monthSpendingCategories) { category in
                                Rectangle()
                                    .fill(category.color)
                                    .frame(
                                        width: max(
                                            0,
                                            geo.size.width * CGFloat(category.amount / monthSpendingTotal)
                                        )
                                    )
                            }
                        }
                    }
                    .frame(height: 11)
                    .clipShape(Capsule())
                } else {
                    Capsule()
                        .fill(
                            Color.white.opacity(0.18)
                        )
                        .frame(height: 11)
                }
            }
            .padding(17)
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .onTapGesture {
            
            showAllOperations = true
        }
    }
    
    private var budgetCard: some View {
        
        RoundedRectangle(
            cornerRadius: 24,
            style: .continuous
        )
        .fill(
            Color(
                red: 0.110,
                green: 0.110,
                blue: 0.118
            )
        )
        .frame(
            width: 165,
            height: 125
        )
        .overlay(alignment: .topLeading) {
            
            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                
                Text("Бюджет\nмесяца")
                    .font(
                        .system(
                            size: 16,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Осталось")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        .white.opacity(0.55)
                    )
                
                Text(formattedMoney(monthBudgetLeft))
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 2)
            }
            .padding(17)
        }
    }
    
    // MARK: Account
    
    private var accountCard: some View {
        
        ZStack(alignment: .topLeading) {
            
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
            .fill(
                Color(
                    red: 0.110,
                    green: 0.110,
                    blue: 0.118
                )
            )
            .frame(
                width: 350,
                height: 120
            )
            
            Image("Image Asset")
                .resizable()
                .scaledToFit()
                .frame(
                    width: 70,
                    height: 70
                )
                .offset(
                    x: 3,
                    y: 3
                )
            
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                
                Text(formattedMoney(totalBalance))
                    .font(
                        .system(
                            size: 17,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                    .offset(
                        x: 70,
                        y: 18
                    )
                
                Text("Black")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .offset(
                        x: 70,
                        y: 19
                    )
            }
            
            // MARK: Cards on main screen
            
            HStack(spacing: 7) {
                
                ForEach(
                    cards.indices,
                    id: \.self
                ) { index in
                    
                    VStack(spacing: 1) {
                        
                        smallCard(
                            card: cards[index]
                        )
                        .onTapGesture {
                            
                            selectedCardIndex = index
                            prepareEditingCard()
                            
                            withAnimation(
                                .spring(
                                    response: 0.42,
                                    dampingFraction: 0.88
                                )
                            ) {
                                
                                operationsDragOffset = 0
                                showOperations = true
                            }
                        }
                        
                        Text(cards[index].number)
                            .font(
                                .system(
                                    size: 8,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(
                                cardNumberColor(
                                    cards[index].numberColor
                                )
                            )
                            .frame(
                                width: 41,
                                height: 12
                            )
                            .offset(
                                x: -8,
                                y: -12
                            )
                    }
                }
            }
            .offset(
                x: 72,
                y: 70
            )
        }
        .frame(
            width: 350,
            height: 120
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: Small card
    
    private func smallCard(
        card: CardData
    ) -> some View {
        
        Group {
            
            if let data = card.imageData,
               let image = UIImage(data: data) {
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                
            } else {
                
                RoundedRectangle(
                    cornerRadius: 4,
                    style: .continuous
                )
                .fill(
                    cardDesigns[
                        min(
                            card.designIndex,
                            cardDesigns.count - 1
                        )
                    ]
                )
            }
        }
        .frame(
            width: 41,
            height: 25
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 4,
                style: .continuous
            )
        )
        .overlay {
            
            RoundedRectangle(
                cornerRadius: 4,
                style: .continuous
            )
            .stroke(
                Color.green,
                lineWidth: 0.5
            )
        }
    }
    
    // MARK: Banner
    
    private var promoBanner: some View {
        
        RoundedRectangle(
            cornerRadius: 25,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    Color(
                        red: 0.96,
                        green: 0.29,
                        blue: 0.25
                    ),
                    Color(
                        red: 0.97,
                        green: 0.05,
                        blue: 0.27
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(height: 110)
        .overlay(alignment: .topLeading) {
            
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                
                HStack(alignment: .top) {
                    
                    Text("Финансовый инсайт")
                        .font(
                            .system(
                                size: 20,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Circle()
                        .fill(
                            Color.black.opacity(0.17)
                        )
                        .frame(
                            width: 20,
                            height: 20
                        )
                        .overlay {
                            
                            Image(systemName: "xmark")
                                .font(
                                    .system(
                                        size: 12,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(.white)
                        }
                }
                
                Text(
                    "На кафе в этом месяце ушло\nна 2 340 Br больше обычного"
                )
                .font(.system(size: 12))
                .foregroundStyle(.white)
            }
            .padding(17)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: Operations
    
    private var operationsView: some View {
        
        ZStack(alignment: .top) {
            
            Color(
                red: 28 / 255,
                green: 28 / 255,
                blue: 30 / 255
            )
            
            ScrollView(showsIndicators: false) {
                
                VStack(spacing: 0) {
                    
                    // MARK: Header
                    
                    HStack {
                        
                        Button {
                            closeOperations()
                        } label: {
                            
                            Text("Закрыть")
                                .font(.system(size: 15))
                                .foregroundStyle(.blue)
                                .offset(y: 5)
                        }
                        
                        Spacer()
                        
                        Text("Карты")
                            .font(
                                .system(
                                    size: 15,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)
                            .offset(x: -10, 
                                    y: 5)
                        
                        Spacer()
                        
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // MARK: Card selector
                    
                    cardsSelector
                        .padding(.top, 18)
                    
                    // MARK: Big card
                    
                    cardPreview
                        .padding(.top, 18)
                        .padding(.horizontal, 16)
                    
                    // MARK: Settings
                    
                    sectionLabel("Настройки карты")
                        .padding(.top, 28)
                    
                    settingsGroup
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                    
                    Button {
                        
                    } label: {
                        
                        Text("Заблокировать карту")
                            .font(.system(size: 15))
                            .foregroundStyle(.red)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                        .frame(height: 60)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(
            height: UIScreen.main.bounds.height * 0.963
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
        )
        .padding(.bottom, -34)
        .offset(
            y: operationsDragOffset
        )
        .highPriorityGesture(
            
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    
                    let translation =
                    value.translation.height
                    
                    if translation > 0 {
                        operationsDragOffset =
                        translation
                    }
                }
                .onEnded { value in
                    
                    let dragDistance =
                    value.translation.height
                    
                    if dragDistance > 120 {
                        
                        withAnimation(
                            .spring(
                                response: 0.42,
                                dampingFraction: 0.88
                            )
                        ) {
                            
                            operationsDragOffset =
                            UIScreen.main.bounds.height
                        }
                        
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.42
                        ) {
                            
                            showOperations = false
                            operationsDragOffset = 0
                        }
                        
                    } else {
                        
                        withAnimation(
                            .spring(
                                response: 0.42,
                                dampingFraction: 0.88
                            )
                        ) {
                            
                            operationsDragOffset = 0
                        }
                    }
                }
        )
    }
    
    // MARK: Cards selector
    
    private var cardsSelector: some View {
        
        HStack(spacing: 10) {
            
            ForEach(
                cards.indices,
                id: \.self
            ) { index in
                
                Button {
                    
                    withAnimation(
                        .easeInOut(duration: 0.2)
                    ) {
                        
                        selectedCardIndex = index
                        prepareEditingCard()
                    }
                    
                } label: {
                    
                    ZStack {
                        
                        smallCard(
                            card: cards[index]
                        )
                        
                        if selectedCardIndex == index {
                            
                            RoundedRectangle(
                                cornerRadius: 5,
                                style: .continuous
                            )
                            .stroke(
                                Color.blue,
                                lineWidth: 2
                            )
                        }
                    }
                    .frame(
                        width: 50,
                        height: 34
                    )
                }
                .buttonStyle(.plain)
            }
            
            // MARK: Add card
            
            if cards.count < maxCards {
                
                Button {
                    addNewCard()
                } label: {
                    
                    RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                    .fill(
                        Color.white.opacity(0.06)
                    )
                    .frame(
                        width: 50,
                        height: 34
                    )
                    .overlay {
                        
                        Image(systemName: "plus")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(0.55)
                            )
                    }
                    .overlay {
                        
                        RoundedRectangle(
                            cornerRadius: 7,
                            style: .continuous
                        )
                        .stroke(
                            Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                    }
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: Big card
    
    private var cardPreview: some View {
        
        GeometryReader { geometry in
            
            if cards.indices.contains(selectedCardIndex) {
                
                let card = cards[selectedCardIndex]
                
                ZStack {
                    
                    if let data = card.imageData,
                       let image = UIImage(data: data) {
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(
                                contentMode: .fill
                            )
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipped()
                        
                    } else {
                        
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .fill(
                            cardDesigns[
                                min(
                                    card.designIndex,
                                    cardDesigns.count - 1
                                )
                            ]
                        )
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                )
                .overlay(alignment: .topLeading) {
                    
                    if card.imageData == nil {
                        
                        VStack(
                            alignment: .leading,
                            spacing: 0
                        ) {
                            
                            Text("Баланс")
                                .font(.system(size: 12))
                                .foregroundStyle(
                                    .white.opacity(0.55)
                                )
                            
                            Text(formattedMoney(totalBalance))
                                .font(
                                    .system(
                                        size: 26,
                                        weight: .semibold
                                    )
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(.white)
                                .padding(.top, 4)
                            
                            Spacer()
                            
                            Text(
                                "•••• •••• •••• \(card.number)"
                            )
                            .font(.system(size: 14))
                            .foregroundStyle(
                                .white.opacity(0.75)
                            )
                            .tracking(2)
                        }
                        .padding(20)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    
                    RoundedRectangle(
                        cornerRadius: 5,
                        style: .continuous
                    )
                    .fill(
                        Color.white.opacity(0.92)
                    )
                    .frame(
                        width: 44,
                        height: 28
                    )
                    .overlay {
                        
                        Text("VISA")
                            .font(
                                .system(
                                    size: 10,
                                    weight: .semibold
                                )
                            )
                            .italic()
                            .foregroundStyle(
                                Color.black.opacity(0.75)
                            )
                    }
                    .padding(20)
                }
            }
        }
        .frame(
            maxWidth: .infinity
        )
        .frame(height: 150)
    }
    
    // MARK: Settings
    
    private var settingsGroup: some View {
        
        VStack(spacing: 0) {
            
            // MARK: Change image
            
            PhotosPicker(
                selection: $selectedCardImage,
                matching: .images,
                photoLibrary: .shared()
            ) {
                
                settingsRow(
                    icon: "photo",
                    title: "Изменить изображение карты"
                )
            }
            .buttonStyle(.plain)
            
            // MARK: Designs
            
            designSwatches
                .padding(.vertical, 12)
            
            Divider()
                .background(
                    Color.white.opacity(0.08)
                )
            
            // MARK: Card number
            
            HStack(spacing: 10) {
                
                Image(systemName: "creditcard")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                
                Text("Номер карты")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("••")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        .white.opacity(0.45)
                    )
                
                TextField(
                    "",
                    text: $cardNumberText
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 55)
                .onChange(
                    of: cardNumberText
                ) { _, newValue in
                    
                    let filtered =
                    newValue.filter {
                        $0.isNumber
                    }
                    
                    let limited =
                    String(
                        filtered.prefix(4)
                    )
                    
                    if cardNumberText != limited {
                        cardNumberText = limited
                    }
                    
                    saveCurrentCard()
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            
            Divider()
                .background(
                    Color.white.opacity(0.08)
                )
            
            // MARK: Number color
            
            HStack(spacing: 10) {
                
                Image(systemName: "paintpalette")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                
                Text("Цвет номера")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    
                    numberColorButton(
                        "white",
                        .white
                    )
                    
                    numberColorButton(
                        "gray",
                        .gray
                    )
                    
                    numberColorButton(
                        "blue",
                        .blue
                    )
                    
                    numberColorButton(
                        "green",
                        .green
                    )
                    
                    numberColorButton(
                        "red",
                        .red
                    )
                    
                    numberColorButton(
                        "yellow",
                        .yellow
                    )
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            
            Divider()
                .background(
                    Color.white.opacity(0.08)
                )
            
            settingsRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Перевыпустить номер"
            )
            
            // MARK: Delete card
            
            if cards.count > 1 {
                
                Divider()
                    .background(
                        Color.white.opacity(0.08)
                    )
                
                Button {
                    deleteCurrentCard()
                } label: {
                    
                    HStack(spacing: 10) {
                        
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                        
                        Text("Удалить карту")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .background(
            Color.white.opacity(0.05)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .onChange(
            of: selectedCardImage
        ) { _, newItem in
            
            guard let newItem else {
                return
            }
            
            Task {
                
                do {
                    
                    if let data =
                        try await newItem.loadTransferable(
                            type: Data.self
                        ) {
                        
                        await MainActor.run {
                            
                            guard cards.indices.contains(
                                selectedCardIndex
                            ) else {
                                return
                            }
                            
                            cards[selectedCardIndex]
                                .imageData = data
                            
                            CardStorage.saveCards(cards)
                        }
                    }
                    
                } catch {
                    
                    print(
                        "Ошибка загрузки изображения: \(error)"
                    )
                }
            }
        }
    }
    
    // MARK: Number color button
    
    private func numberColorButton(
        _ name: String,
        _ color: Color
    ) -> some View {
        
        Circle()
            .fill(color)
            .frame(
                width: 20,
                height: 20
            )
            .overlay {
                
                Circle()
                    .stroke(
                        Color.blue,
                        lineWidth:
                            cards.indices.contains(selectedCardIndex) &&
                        cards[selectedCardIndex]
                            .numberColor == name
                        ? 2
                        : 0
                    )
            }
            .overlay {
                
                if name == "white" {
                    
                    Circle()
                        .stroke(
                            Color.white.opacity(0.25),
                            lineWidth: 0.5
                        )
                }
            }
            .onTapGesture {
                
                guard cards.indices.contains(
                    selectedCardIndex
                ) else {
                    return
                }
                
                withAnimation(
                    .easeInOut(duration: 0.15)
                ) {
                    
                    cards[selectedCardIndex]
                        .numberColor = name
                    
                    CardStorage.saveCards(cards)
                }
            }
    }
    
    // MARK: Settings row
    
    private func settingsRow(
        icon: String,
        title: String
    ) -> some View {
        
        HStack(spacing: 10) {
            
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(
                    .white.opacity(0.3)
                )
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .contentShape(Rectangle())
    }
    
    // MARK: Designs
    
    private var designSwatches: some View {
        
        HStack(spacing: 10) {
            
            ForEach(
                cardDesigns.indices,
                id: \.self
            ) { index in
                
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
                .fill(
                    cardDesigns[index]
                )
                .frame(
                    width: 44,
                    height: 28
                )
                .overlay {
                    
                    RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                    .stroke(
                        cards.indices.contains(selectedCardIndex) &&
                        cards[selectedCardIndex]
                            .designIndex == index &&
                        cards[selectedCardIndex]
                            .imageData == nil
                        ? Color.blue
                        : Color.clear,
                        lineWidth: 1.5
                    )
                }
                .onTapGesture {
                    
                    guard cards.indices.contains(
                        selectedCardIndex
                    ) else {
                        return
                    }
                    
                    withAnimation(
                        .easeInOut(duration: 0.2)
                    ) {
                        
                        cards[selectedCardIndex]
                            .designIndex = index
                        
                        cards[selectedCardIndex]
                            .imageData = nil
                        
                        selectedCardImage = nil
                        
                        CardStorage.saveCards(cards)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
    }
    
    // MARK: Section label
    
    private func sectionLabel(
        _ text: String
    ) -> some View {
        
        HStack {
            
            Text(text)
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.45)
                )
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: Prepare editing
    
    private func prepareEditingCard() {
        
        guard cards.indices.contains(
            selectedCardIndex
        ) else {
            return
        }
        
        cardNumberText =
        cards[selectedCardIndex].number
        
        selectedCardImage = nil
    }
    
    // MARK: Save current card
    
    private func saveCurrentCard() {
        
        guard cards.indices.contains(
            selectedCardIndex
        ) else {
            return
        }
        
        cards[selectedCardIndex].number =
        cardNumberText
        
        CardStorage.saveCards(cards)
    }
    
    // MARK: Add new card
    
    private func addNewCard() {
        
        guard cards.count < maxCards else {
            return
        }
        
        let newCard = CardData(
            number: "0000",
            imageData: nil,
            designIndex:
                cards.count % cardDesigns.count,
            numberColor: "white"
        )
        
        cards.append(newCard)
        
        selectedCardIndex =
        cards.count - 1
        
        cardNumberText = "0000"
        selectedCardImage = nil
        
        CardStorage.saveCards(cards)
    }
    
    // MARK: Delete current card
    
    private func deleteCurrentCard() {
        
        // Нельзя удалить последнюю карту
        guard cards.count > 1 else {
            return
        }
        
        guard cards.indices.contains(
            selectedCardIndex
        ) else {
            return
        }
        
        // Удаляем выбранную карту
        cards.remove(
            at: selectedCardIndex
        )
        
        // Если индекс вышел за границы,
        // выбираем последнюю оставшуюся карту
        if selectedCardIndex >= cards.count {
            selectedCardIndex =
            cards.count - 1
        }
        
        // Обновляем поле номера
        cardNumberText =
        cards[selectedCardIndex].number
        
        // Сбрасываем выбранную фотографию
        selectedCardImage = nil
        
        // Сохраняем новый список
        CardStorage.saveCards(cards)
    }
    
    // MARK: Close
    
    private func closeOperations() {
        
        saveCurrentCard()
        
        withAnimation(
            .spring(
                response: 0.42,
                dampingFraction: 0.88
            )
        ) {
            
            operationsDragOffset =
            UIScreen.main.bounds.height
        }
        
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.42
        ) {
            
            showOperations = false
            operationsDragOffset = 0
        }
    }
    
    // MARK: Bottom bar
    
    private var bottomTabBar: some View {
        
        HStack {
            
            tabItem(
                tab: .home,
                icon: "house.fill",
                title: "Главная"
            )
            
            tabItem(
                tab: .payments,
                icon: "creditcard.fill",
                title: "Платежи"
            )
            
            tabItem(
                tab: .analytics,
                icon: "chart.pie.fill",
                title: "Аналитика"
            )
            
            tabItem(
                tab: .chat,
                icon: "message.fill",
                title: "Чат"
            )
            
            tabItem(
                tab: .more,
                icon: "square.grid.2x2.fill",
                title: "Ещё"
            )
        }
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background {
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(
                    edges: .bottom
                )
        }
    }
    
    private func tabItem(
        tab: AppTab,
        icon: String,
        title: String
    ) -> some View {
        
        Button {
            
            withAnimation(
                .easeInOut(duration: 0.16)
            ) {
                selectedTab = tab
            }
            
        } label: {
            
            VStack(spacing: 4) {
                
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                
                Text(title)
                    .font(
                        .system(
                            size: 10.5,
                            weight: .medium
                        )
                    )
            }
            .foregroundStyle(
                selectedTab == tab
                ? Color.blue
                : Color.white.opacity(0.45)
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Promo Card

private struct PromoCard: View {
    
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        
        RoundedRectangle(
            cornerRadius: 21,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.065)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(
            width: 96,
            height: 100
        )
        .overlay(alignment: .topLeading) {
            
            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 21,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text(title)
                    .font(
                        .system(
                            size: 13.5,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(
                        .white.opacity(0.7)
                    )
                    .padding(.top, 2)
                    .lineLimit(1)
            }
            .padding(11)
        }
        .overlay {
            
            RoundedRectangle(
                cornerRadius: 21,
                style: .continuous
            )
            .stroke(
                Color.blue,
                lineWidth: 1.3
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
