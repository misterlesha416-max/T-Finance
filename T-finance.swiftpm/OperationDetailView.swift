import SwiftUI

/// Математика «схлопывания» шапки с кольцом при прокрутке истории вниз.
///
/// Один и тот же offset прокрутки (contentOffset.y) делится на две фазы:
///   0 ... searchRange                — уезжает строка поиска (её двигает OperationsView);
///   searchRange ... totalRange       — кольцо уменьшается и уезжает вправо-вверх,
///                                      превращаясь в карточку «Нет трат / 3 702 ₽» с кольцом
///                                      справа (финальный кадр — последний скрин).
/// Все координаты — в системе детали (0 — верх OperationDetailView).
enum RingCollapse {
    static let searchRange: CGFloat = DS.searchHeight + 16
    /// Сколько pt прокрутки уходит на схлопывание кольца после поиска.
    static let scrollRange: CGFloat = 100
    static var totalRange: CGFloat { searchRange + scrollRange }

    /// Верх кольца в покое: заголовок (4 + ~57) + 20.
    static let ringTopInset: CGFloat = 81
    static let ringBlock: CGFloat = DS.ringDiameter + DS.ringStroke
    static var restCenterY: CGFloat { ringTopInset + ringBlock / 2 }
    static var pickerRestY: CGFloat { ringTopInset + ringBlock + DS.ringToControlsGap }
    /// За сколько pt прокрутки пикер Нед/Мес/Год полностью исчезает под кольцом.
    static let pickerFadeDistance: CGFloat = 30

    // Финальная карточка
    static let cardHeight: CGFloat = 75
    static let cardCorner: CGFloat = 24
    static let finalRingOuter: CGFloat = 44
    static let finalCenterY: CGFloat = cardHeight / 2
    /// Центр маленького кольца — на столько pt левее правого края экрана.
    static let finalCenterInsetFromTrailing: CGFloat = 100

    // Заголовок («Нет трат» / сумма) и подпись
    static let titleScaleFinal: CGFloat = 17 / DS.detailTitleFont
    static let titleShiftX: CGFloat = 17
    static func titleShiftY(hasAmount: Bool) -> CGFloat { hasAmount ? 13.5 : 23.3 }
    static let subtitleShiftX: CGFloat = 17
    static let subtitleShiftY: CGFloat = -3
    // Кнопка закрытия
    static let closeShiftX: CGFloat = -16
    static let closeShiftY: CGFloat = 18.5

    static func clamp01(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
    static func progress(_ offset: CGFloat) -> CGFloat { clamp01((offset - searchRange) / scrollRange) }
    static func ease(_ t: CGFloat) -> CGFloat { let c = clamp01(t); return c * c * (3 - 2 * c) }
    /// Текущий offset прокрутки по положению блока кольца в координатах ScrollView.
    static func scrollOffset(minY: CGFloat) -> CGFloat { max(0, ringTopInset - minY) }

    static func ringScale(_ e: CGFloat) -> CGFloat { 1 + (finalRingOuter / ringBlock - 1) * e }
    static func ringCenterY(_ e: CGFloat) -> CGFloat { restCenterY + (finalCenterY - restCenterY) * e }
    /// Нижняя граница «шторки», под которой прячется уезжающий вверх контент.
    static func coverHeight(_ e: CGFloat) -> CGFloat {
        ringCenterY(e) + ringBlock * ringScale(e) / 2 + 10
    }
}

struct OperationDetailView: View {
    let type: OperationType
    let isExpanded: Bool
    @Binding var selectedMonthIndex: Int
    @Binding var selectedWeekIndex: Int
    @Binding var selectedYearIndex: Int
    @Binding var selectedPeriod: Period
    let currentCategories: [CategoryEntry]
    /// Категории, схлопнутые в капсулу "Остальное" — показываются в шите
    /// по тапу на неё (см. otherCategoriesSheet).
    let currentOtherCategories: [CategoryEntry]
    /// Все реальные операции пользователя (общий источник для недели,
    /// месяца и года — см. OperationsView.transactions) — здесь
    /// отфильтровываются под currentDateRange для истории под кольцом.
    let transactions: [Transaction]
    /// Произвольный промежуток из календаря (chip "Май" → выбор дат) —
    /// когда не nil, он важнее выбранной страницы карусели: и кольцо, и
    /// история под ним показывают траты именно за этот промежуток.
    let customDateRange: ClosedRange<Date>?
    let categoriesForMonth: (Int) -> [CategoryEntry]
    let categoriesForWeek: (Int) -> [CategoryEntry]
    let categoriesForYear: (Int) -> [CategoryEntry]
    let onRingTap: () -> Void
    let onDeleteCategory: (CategoryEntry) -> Void
    /// Вызывается, когда пользователь переключает Нед/Мес/Год вручную,
    /// пока активен произвольный промежуток из календаря — период-пикер
    /// должен снова управлять кольцом, а не оставаться "мёртвой" кнопкой
    /// рядом с уже показанным календарным кольцом.
    let onClearCustomRange: () -> Void
    let close: () -> Void
    /// 0 — шапка раскрыта, 1 — кольцо схлопнулось в карточку (см. RingCollapse).
    let ringCollapse: CGFloat
    /// Сообщает наверх offset прокрутки — по нему OperationsView сворачивает
    /// поиск и считает ringCollapse.
    let onScrollOffsetChange: (CGFloat) -> Void

    @State private var detailScroll = ScrollPosition(edge: .top)
    @State private var currentScrollOffset: CGFloat = 0
    /// Увеличивается, когда кольцу нужно «нарисоваться» заново.
    @State private var revealID = 0
    @State private var searchText = ""
    @State private var isOtherCategoriesPresented = false
    @State private var selectedYear = "2026"
    @State private var selectedChartMode = 0
    @Namespace private var periodCapsuleAnimation
    @Namespace private var chartModeAnimation

    enum Period: String, CaseIterable {
        case week = "Нед"
        case month = "Мес"
        case year = "Год"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // ScrollView занимает всю высоту детали: кольцо внутри него
                // «приколото» через visualEffect (см. pinnedRingHeader) — при
                // прокрутке оно не уезжает, а уменьшается и смещается в
                // карточку. История и чипы едут под ним как обычно.
                ScrollView {
                    VStack(spacing: 0) {
                        pinnedRingHeader

                        periodPicker
                            .visualEffect { content, proxy in
                                let o = max(0, RingCollapse.pickerRestY - proxy.frame(in: .scrollView).minY)
                                return content.opacity(1 - Double(RingCollapse.clamp01(o / RingCollapse.pickerFadeDistance)))
                            }
                            .padding(.top, DS.ringToControlsGap)

                        categoryChips
                            .padding(.top, DS.rowGap)

                        ZStack {
                            emptyState
                                .frame(maxWidth: .infinity, minHeight: 280)
                                .opacity(currentCategories.isEmpty ? 1 : 0)
                                .allowsHitTesting(currentCategories.isEmpty)

                            TransactionHistorySection(
                                transactions: currentTransactions,
                                granularity: currentHistoryGranularity
                            )
                            .padding(.top, DS.rowGap)
                            .padding(.bottom, 24)
                            .opacity(currentCategories.isEmpty ? 0 : 1)
                            .allowsHitTesting(!currentCategories.isEmpty)
                        }
                    }
                    // Минимальная высота даёт прокрутку даже при пустой
                    // истории — шапка всё равно успевает свернуться.
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geo.size.height + RingCollapse.totalRange,
                        alignment: .top
                    )
                }
                .scrollPosition($detailScroll)
                .scrollBounceBehavior(.always)
                .onScrollGeometryChange(for: CGFloat.self) { scroll in
                    scroll.contentOffset.y + scroll.contentInsets.top
                } action: { _, offset in
                    currentScrollOffset = max(offset, 0)
                    onScrollOffsetChange(max(offset, 0))
                }
                .opacity(isExpanded ? 1 : 0)

                // sectionTitle остаётся вне скролла — он завязан на
                // heroTitleOverlay/measureFrame в OperationsView.
                sectionTitle
                    .padding(.top, 4)
            }
        }
        // Постоянно смонтировано. Появление/исчезновение всего блока — это
        // просто opacity, управляемая тем же isExpanded/withAnimation, что и
        // переключение selectedRing в OperationsView.
        .opacity(isExpanded ? 1 : 0)
        .onChange(of: isExpanded) { _, expanded in
            // Деталь смонтирована всегда — при каждом открытии начинаем сверху.
            if expanded {
                detailScroll.scrollTo(y: 0)
                revealID += 1
            }
        }
        .onChange(of: selectedPeriod) { _, _ in revealID += 1 }
        .onChange(of: customDateRange != nil) { _, _ in revealID += 1 }
        .sheet(isPresented: $isOtherCategoriesPresented) {
            OtherCategoriesSheet(
                categories: currentOtherCategories,
                onClose: { isOtherCategoriesPresented = false }
            )
        }
    }

    // MARK: - Pinned ring header (кольцо → карточка при прокрутке)

    private var pinnedRingHeader: some View {
        ZStack {
            headerCover
            headerCard
            ringLayer
        }
        .frame(height: RingCollapse.ringBlock)
        .padding(.top, RingCollapse.ringTopInset)
        .zIndex(1)
    }

    /// «Шторка» цвета фона: прячет историю/чипы, уезжающие вверх под кольцо.
    private var headerCover: some View {
        Rectangle()
            .fill(DS.background)
            .allowsHitTesting(false)
            .visualEffect { content, proxy in
                let o = RingCollapse.scrollOffset(minY: proxy.frame(in: .scrollView).minY)
                let e = RingCollapse.ease(RingCollapse.progress(o))
                let height = RingCollapse.coverHeight(e)
                return content
                    .scaleEffect(x: 1, y: height / RingCollapse.ringBlock, anchor: .top)
                    .offset(y: o - RingCollapse.ringTopInset)
            }
    }

    /// Фон итоговой карточки — проявляется в самом конце схлопывания.
    private var headerCard: some View {
        RoundedRectangle(cornerRadius: RingCollapse.cardCorner, style: .continuous)
            .fill(DS.cardBackground)
            .frame(height: RingCollapse.cardHeight)
            .padding(.horizontal, DS.margin)
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)
            .visualEffect { content, proxy in
                let o = RingCollapse.scrollOffset(minY: proxy.frame(in: .scrollView).minY)
                let t = RingCollapse.progress(o)
                let alpha = RingCollapse.clamp01((t - 0.6) / 0.3)
                return content
                    .opacity(Double(alpha))
                    .offset(y: o + (RingCollapse.finalCenterY - RingCollapse.restCenterY))
            }
    }

    /// Карусель колец + статичное маленькое кольцо без иконок. Весь блок
    /// масштабируется и переезжает вправо-вверх; карусель по пути гаснет,
    /// статичное кольцо проявляется под ней.
    private var ringLayer: some View {
        ZStack {
            donutChart
                .allowsHitTesting(currentScrollOffset < 10)
                .visualEffect { content, proxy in
                    // Соседние кольца (и иконки) пропадают почти сразу, как
                    // только пошла прокрутка — остаётся только выбранное.
                    let o = RingCollapse.scrollOffset(minY: proxy.frame(in: .scrollView).minY)
                    return content.opacity(1 - Double(RingCollapse.clamp01(o / 10)))
                }

            staticRing
                .allowsHitTesting(false)
                .visualEffect { content, proxy in
                    let o = RingCollapse.scrollOffset(minY: proxy.frame(in: .scrollView).minY)
                    return content.opacity(Double(RingCollapse.clamp01(o / 4)))
                }
        }
        .frame(height: RingCollapse.ringBlock)
        .visualEffect { content, proxy in
            let o = RingCollapse.scrollOffset(minY: proxy.frame(in: .scrollView).minY)
            let e = RingCollapse.ease(RingCollapse.progress(o))
            let w = proxy.size.width
            return content
                .scaleEffect(RingCollapse.ringScale(e))
                .offset(
                    x: (w / 2 - RingCollapse.finalCenterInsetFromTrailing) * e,
                    y: o + (RingCollapse.finalCenterY - RingCollapse.restCenterY) * e
                )
        }
    }

    private var staticRing: some View {
        ZStack {
            Circle()
                .stroke(
                    DS.ringTrack,
                    style: StrokeStyle(lineWidth: DS.ringStroke, lineCap: .round)
                )
                .frame(width: DS.ringDiameter, height: DS.ringDiameter)

            CategoryDonut(categories: currentCategories, showDetails: false)
        }
        .frame(height: RingCollapse.ringBlock)
    }

    // MARK: - Section title

    private var sectionTitle: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Реальный текст невидим — единственная видимая копия заголовка
                // рисуется как hero-overlay в OperationsView. Этот Text нужен
                // только чтобы зарезервировать место в layout'е и опубликовать
                // свой фрейм для измерения (замена matchedGeometryEffect).
                // Важно: строка здесь должна совпадать с тем, что реально
                // покажет hero-overlay (displayTitle), иначе измеренный фрейм
                // будет рассчитан под "Нет трат", а не под сумму — и текст с
                // суммой не влезет/съедется при появлении.
                Text(displayTitle)
                    .font(.system(size: DS.detailTitleFont, weight: .medium))
                    .fixedSize()
                    .opacity(0)
                    .measureFrame(id: "detailTitle")

                // Подпись под суммой — просто текст, без капсулы-фона.
                // Смонтирована всегда (см. комментарий про паттерн "always
                // mounted + opacity" в верхней части файла), видна только
                // когда сумма действительно есть.
                Text(type == .spending ? "Траты" : "Доходы")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white)
                    .opacity(isExpanded && totalAmount > 0 ? 1 : 0)
                    .padding(.leading, 4)
                    .offset(
                        x: RingCollapse.subtitleShiftX * collapseEase,
                        y: RingCollapse.subtitleShiftY * collapseEase
                    )
            }

            Spacer(minLength: 0)

            closeButton
                .opacity(isExpanded ? 1 : 0)
                .offset(
                    x: RingCollapse.closeShiftX * collapseEase,
                    y: RingCollapse.closeShiftY * collapseEase
                )
        }
        .padding(.horizontal, DS.margin)
    }

    /// То, что должно быть видно вместо "Нет трат"/"Нет доходов" — как
    /// только по текущему периоду появилась хоть одна категория, заголовок
    /// сам становится суммой. OperationsView.heroTitleOverlay считает то же
    /// самое по тем же данным (currentCategories там и здесь — один и тот
    /// же источник), поэтому подписи совпадают 1-в-1.
    private var displayTitle: String {
        totalAmount > 0 ? "\(formattedAmount(totalAmount)) \(currencySymbol)" : type.title
    }

    private var collapseEase: CGFloat { RingCollapse.ease(ringCollapse) }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.closeButtonIcon)
                .frame(width: DS.closeButtonDiameter, height: DS.closeButtonDiameter)
                .background(DS.closeButtonBg)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Total amount (появляется, когда для текущего периода уже есть категории)

    private var totalAmount: Double {
        currentCategories.reduce(0) { $0 + $1.amount }
    }

    /// Ширина, доступная под ряды чипов — читается один раз через
    /// preference key с фонового GeometryReader (см. categoryChips), а не
    /// используется для того, чтобы ЗАДАТЬ высоту контейнера. Раньше здесь
    /// была высота (chipsFlowHeight), которую GeometryReader сам себе
    /// назначал через .frame(height:) — из-за задержки в один кадр между
    /// реальной высотой раскладки и уже применённым чипсам старым значением
    /// плитки "наезжали" на историю операций под ними. Ширина в этой роли
    /// безопасна: если на один кадр она чуть устареет, максимальная ширина
    /// капсулы будет на кадр неточной, но раскладка по высоте (а значит и
    /// положение истории операций ниже) больше ни от чего не зависит и не
    /// "прыгает".
    @State private var chipsContainerWidth: CGFloat = 340
    
    private struct ChipsWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 340
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    // MARK: - Transaction history (синтетическая, из currentCategories)

    /// Границы выбранного периода — произвольный промежуток из календаря в
    /// приоритете (см. customDateRange), иначе те же границы, что использует
    /// OperationsView для агрегации (WeekOption/MonthOption/YearOption.dateRange),
    /// поэтому история операций ниже и сумма кольца всегда согласованы.
    private var currentDateRange: ClosedRange<Date> {
        if let customDateRange { return customDateRange }
        
        switch selectedPeriod {
        case .week:
            guard WeekData.weeks.indices.contains(selectedWeekIndex) else {
                return Date()...Date()
            }
            return WeekData.weeks[selectedWeekIndex].dateRange

        case .month:
            guard MonthData.months.indices.contains(selectedMonthIndex) else {
                return Date()...Date()
            }
            return MonthData.months[selectedMonthIndex].dateRange

        case .year:
            guard YearData.years.indices.contains(selectedYearIndex) else {
                return Date()...Date()
            }
            return YearData.years[selectedYearIndex].dateRange
        }
    }

    private var currentHistoryGranularity: HistoryGranularity {
        switch selectedPeriod {
        case .week: return .week
        case .month: return .month
        case .year: return .year
        }
    }

    /// Реальные операции пользователя, попадающие в открытый период —
    /// раньше здесь генерировались синтетические строки из сумм по
    /// категориям (TransactionHistory.synthesize); теперь это просто
    /// фильтр по типу и дате над общим списком transactions.
    private var currentTransactions: [Transaction] {
        transactions
            .filter { $0.type == type && currentDateRange.contains($0.date) }
            .sorted { $0.date > $1.date }
    }

    
    private var categoryChips: some View {
        let maxCapsuleWidth = chipsContainerWidth * 0.49
        
        return Group {
            if !currentCategories.isEmpty {
                // Layout-контейнер сам считает свою высоту по реальному
                // числу строк — никакого .frame(height:) сверху не нужно,
                // поэтому то, что рисуется под чипами (история операций),
                // больше не может встать поверх ещё не домеренных рядов.
                CategoryCapsuleFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(currentCategories) { category in
                        CategoryChipCard(category: category, maxWidth: maxCapsuleWidth)
                            // simultaneousGesture, а не onTapGesture(count: 1) —
                            // чтобы одиночный тап не "съедал" тройной тап,
                            // который ниже отвечает за удаление обычных
                            // категорий (два независимых распознавателя
                            // вместо одного, который бы просто заменил
                            // собой предыдущий .gesture).
                            .simultaneousGesture(
                                TapGesture(count: 1).onEnded {
                                    guard category.icon == CategoryEntry.otherIconKey else { return }
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        isOtherCategoriesPresented = true
                                    }
                                }
                            )
                            .onTapGesture(count: 3) {
                                guard category.icon != CategoryEntry.otherIconKey else { return }
                                onDeleteCategory(category)
                            }
                    }
                }
                .padding(.horizontal, DS.margin)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Ширина читается фоновым GeometryReader — background не влияет на
        // размер самого Group, только измеряет уже вычисленные границы,
        // так что это никак не сталкивается с самосайзингом чипов сверху.
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ChipsWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(ChipsWidthKey.self) { chipsContainerWidth = $0 }
        .opacity(isExpanded ? 1 : 0)
    }

    // MARK: - Donut chart carousel

    private var donutChart: some View {
        // Все три кольца смонтированы постоянно и кросс-фейдятся через opacity —
        // тот же приём, что используется в OperationsView для карточек/деталей:
        // никакого if/else, который убирал бы карусель из дерева при
        // переключении "Нед"/"Мес"/"Год" и ломал бы её собственную анимацию скролла.
        ZStack {
            RingCarousel(
                itemCount: MonthData.months.count,
                selectedIndex: $selectedMonthIndex,
                categoriesForIndex: categoriesForMonth,
                onRingTap: onRingTap,
                revealID: revealID
            )
                .opacity(customDateRange == nil && selectedPeriod == .month ? 1 : 0)
                .allowsHitTesting(customDateRange == nil && selectedPeriod == .month)

            RingCarousel(
                itemCount: WeekData.weeks.count,
                selectedIndex: $selectedWeekIndex,
                categoriesForIndex: categoriesForWeek,
                onRingTap: onRingTap,
                revealID: revealID
            )
                .opacity(customDateRange == nil && selectedPeriod == .week ? 1 : 0)
                .allowsHitTesting(customDateRange == nil && selectedPeriod == .week)

            RingCarousel(
                itemCount: YearData.years.count,
                selectedIndex: $selectedYearIndex,
                categoriesForIndex: categoriesForYear,
                onRingTap: onRingTap,
                revealID: revealID
            )
                .opacity(customDateRange == nil && selectedPeriod == .year ? 1 : 0)
                .allowsHitTesting(customDateRange == nil && selectedPeriod == .year)
            
            // Произвольный промежуток из календаря — не карусель (соседних
            // страниц у него нет), поэтому просто одно кольцо с теми же
            // currentCategories, что уже питают заголовок/чипы/историю ниже.
            // Смонтировано всегда, как и три карусели выше — переключение
            // видимости через opacity, без if/else.
            Button(action: onRingTap) {
                ZStack {
                    Circle()
                        .stroke(
                            DS.ringTrack,
                            style: StrokeStyle(
                                lineWidth: DS.ringStroke,
                                lineCap: .round
                            )
                        )
                        .frame(width: DS.ringDiameter, height: DS.ringDiameter)
                    
                    CategoryDonut(categories: currentCategories, showDetails: true, revealID: revealID)
                }
            }
            .buttonStyle(.plain)
            .opacity(customDateRange != nil ? 1 : 0)
            .allowsHitTesting(customDateRange != nil)
        }
            // Карусель смонтирована постоянно; "выезд" сверху вниз — это
            // обычные offset+opacity, управляемые isExpanded. Своя, более
            // резкая анимация (короткий response, высокий dampingFraction —
            // почти без перехлёста), а не унаследованная мягкая пружина
            // из withAnimation в OperationsView.
            .offset(y: isExpanded ? 0 : -36)
            .opacity(isExpanded ? 1 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isExpanded)
            .animation(.easeInOut(duration: 0.2), value: selectedPeriod)
            .animation(.easeInOut(duration: 0.2), value: customDateRange != nil)
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        HStack(spacing: 40) {
            periodButtons
            chartModeButton
        }
        .padding(.horizontal, DS.margin)
        .offset(y: isExpanded ? 0 : -20)
        .opacity(isExpanded ? 1 : 0)
        .animation(
            .spring(response: 0.25, dampingFraction: 0.85),
            value: isExpanded
        )
    }
    
    private var periodButtons: some View {
        HStack(spacing: 0) {
            periodButton(title: "Нед", value: .week)
            periodButton(title: "Мес", value: .month)
            periodButton(title: "Год", value: .year)
        }
        .padding(1)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(DS.periodPickerBackground)
        .clipShape(Capsule())
    }
    
    private var periodIndex: Int {
        Period.allCases.firstIndex(of: selectedPeriod) ?? 0
    }
    
    private func periodButton(
        title: String,
        value: Period
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedPeriod = value
            }
            if customDateRange != nil {
                onClearCustomRange()
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background {
                    if selectedPeriod == value {
                        Capsule()
                            .fill(DS.periodPickerSelected)
                            .padding(.horizontal, 1.5)
                            .matchedGeometryEffect(
                                id: "periodCapsule",
                                in: periodCapsuleAnimation
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }
    
    private var chartModeButton: some View {
        HStack(spacing: 0) {
            chartIconButton(value: 0) {
                DashedCircleIcon()
            }
            
            chartIconButton(value: 1) {
                FiveBarsIcon()
            }
        }
        .padding(2)
        .frame(height: 32)
        .background(DS.periodPickerBackground) // #3e3e40
        .clipShape(Capsule())
    }
    
    private func chartIconButton<Icon: View>(
        value: Int,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedChartMode = value
            }
        } label: {
            ZStack {
                if selectedChartMode == value {
                    Capsule()
                        .fill(DS.periodPickerSelected)
                        .matchedGeometryEffect(
                            id: "chartModeCapsule",
                            in: chartModeAnimation
                        )
                }
                
                icon()
            }
            .frame(width: 36, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text("Таких операций нет.\nПопробуйте поменять даты")
            .multilineTextAlignment(.center)
            .foregroundStyle(DS.textSecondary)
            .font(.system(size: DS.emptyStateFont))
    }
}

struct DashedCircleIcon: View {
    var body: some View {
        ZStack {
            arc(from: 14, to: 44)
            arc(from: 74, to: 164)
            arc(from: 196, to: 254)
            arc(from: 286, to: 346)
        }
        .frame(width: 13, height: 13)
    }
    
    private func arc(
        from startAngle: Double,
        to endAngle: Double
    ) -> some View {
        Circle()
            .trim(
                from: startAngle / 360,
                to: endAngle / 360
            )
            .stroke(
                Color.white,
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .rotationEffect(.degrees(-90))
    }
}

struct FiveBarsIcon: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Capsule()
                .frame(width: 2, height: 4)
            
            Capsule()
                .frame(width: 2, height: 8)
            
            Capsule()
                .frame(width: 2, height: 6.5)
            
            Capsule()
                .frame(width: 2, height: 11)
            
            Capsule()
                .frame(width: 2, height: 14)
        }
        .foregroundStyle(Color.white)
        .frame(width: 16,alignment: .bottom)
    }
}

#Preview {
    OperationDetailView(
        type: .spending,
        isExpanded: true,
        selectedMonthIndex: .constant(0),
        selectedWeekIndex: .constant(0),
        selectedYearIndex: .constant(0),
        selectedPeriod: .constant(.month),
        currentCategories: [
            CategoryEntry(name: "Супермаркеты", amount: 391, icon: "psneokaoierh", color: PresetCategory.expense.first(where: { $0.key == "psneokaoierh" })?.color ?? .orange)
        ],
        currentOtherCategories: [],
        transactions: [],
        customDateRange: nil,
        categoriesForMonth: { _ in [] },
        categoriesForWeek: { _ in [] },
        categoriesForYear: { _ in [] },
        onRingTap: {},
        onDeleteCategory: { _ in },
        onClearCustomRange: {},
        close: {},
        ringCollapse: 0,
        onScrollOffsetChange: { _ in }
    )
    .preferredColorScheme(.dark)
    .background(DS.background)
}
