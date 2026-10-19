import SwiftUI

// MARK: - Chip

struct ChevronXIcon: View {
    var isX: Bool
    
    var body: some View {
        ZStack {
            Text("▼")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(x: 0.65, y: 0.45)
                .opacity(isX ? 0 : 1)
                .scaleEffect(isX ? 0.4 : 1)
                .rotation3DEffect(.degrees(isX ? 90 : 0), axis: (x: 0, y: 1, z: 0))
            
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .opacity(isX ? 1 : 0)
                .scaleEffect(isX ? 1 : 0.4)
                .rotation3DEffect(.degrees(isX ? 0 : -90), axis: (x: 0, y: 1, z: 0))
                
        }
        .frame(width: 12, height: 12)
        .animation(.easeInOut(duration: 0.25), value: isX)
    }
}

struct Chip: View {
    let title: String
    
    var isActive: Bool = false
    var showChevron: Bool = false
    var showClose: Bool = false
    
    var onTap: () -> Void = {}
    var onClose: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 6) {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .contentTransition(.opacity)
                    
                    if showChevron {
                        ChevronXIcon(isX: false)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showClose {
                Button(action: onClose) {
                    ChevronXIcon(isX: true)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.leading, 10)
        .padding(.trailing, showClose ? 6 : 10)
        .frame(height: DS.chipHeight)
        .background(isActive ? DS.chipActive : DS.chipBackground)
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.25), value: title)
    }
}

// MARK: - Flow layout (перенос капсул на новую строку, как текст)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }
    
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Category capsule flow layout (упаковка капсул слева направо с переносом строк)

/// Только измеряет и расставляет — ничего не красит. Левая граница всех
/// строк одна и та же (bounds.minX), капсулы идут слева направо с
/// фиксированным spacing, и когда следующая не помещается по ширине —
/// целиком переносится на новую строку (никогда не сжимается под неё).
struct CategoryCapsuleFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8
    
    private func rows(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> [[(index: Int, size: CGSize)]] {
        let maxWidth = proposal.width ?? .infinity
        
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var rowWidth: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            let wouldExceed = rowWidth + size.width > maxWidth
            let rowHasItems = !(rows[rows.count - 1].isEmpty)
            
            if wouldExceed && rowHasItems {
                rows.append([])
                rowWidth = 0
            }
            
            rows[rows.count - 1].append((index, size))
            rowWidth += size.width + horizontalSpacing
        }
        
        return rows
    }
    
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let laidOutRows = rows(proposal: proposal, subviews: subviews)
        let maxWidth = proposal.width ?? .infinity
        
        var totalHeight: CGFloat = 0
        
        for row in laidOutRows {
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            totalHeight += rowHeight
        }
        
        totalHeight += CGFloat(max(0, laidOutRows.count - 1)) * verticalSpacing
        
        return CGSize(
            width: maxWidth.isFinite ? maxWidth : (laidOutRows.first?.reduce(0) { $0 + $1.size.width + horizontalSpacing } ?? 0),
            height: totalHeight
        )
    }
    
    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let laidOutRows = rows(proposal: proposal, subviews: subviews)
        
        var y: CGFloat = bounds.minY
        
        for row in laidOutRows {
            var x: CGFloat = bounds.minX
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            
            for item in row {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + horizontalSpacing
            }
            
            y += rowHeight + verticalSpacing
        }
    }
}


// MARK: - Category chip card (плашка-капсула: ширина по содержимому, ограничена maxWidth)

struct CategoryChipCard: View {
    let category: CategoryEntry
    let maxWidth: CGFloat
    var showIcon: Bool = true
    var forcedBackground: Color? = nil
    // MARK: Регулировки визуала (не геометрии раскладки)
    
    private let iconCircleSize: CGFloat = 24
    private let iconSize: CGFloat = 24
    private let leadingInset: CGFloat = 3
    private let iconToNameSpacing: CGFloat = 4
    private let nameToAmountSpacing: CGFloat = 5
    private let trailingInset: CGFloat = 10
    private let capsuleHeight: CGFloat = 30
    
    
    /// Сколько места физически остаётся под название, если капсулу
    /// целиком ограничить maxWidth: maxWidth минус вся "неизбежная"
    /// часть (иконка, паддинги, spacing, сумма — сумма меряется через
    /// fixedSize, поэтому её ширина точна и не подлежит сжатию).
    private func availableNameWidth(amountWidth: CGFloat) -> CGFloat {
        let iconChrome = showIcon ? (iconCircleSize + iconToNameSpacing) : 8
        let chrome = leadingInset + iconChrome
        + nameToAmountSpacing + amountWidth + trailingInset
        return max(0, maxWidth - chrome)
    }
    
    var body: some View {
        let amountString = "\(formattedAmount(category.amount)) \(currencySymbol)"
        let amountWidth = textWidth(amountString, size: 14, weight: .medium)
        let nameNaturalWidth = textWidth(category.name, size: 14, weight: .medium)
        let allocatedNameWidth = availableNameWidth(amountWidth: amountWidth)
        let isTruncated = nameNaturalWidth > allocatedNameWidth
        let nameWidth = min(nameNaturalWidth, allocatedNameWidth)
        
        HStack(spacing: 0) {
            if showIcon {
                ZStack {
                    Circle()
                        .fill(category.color)
                    
                    CategoryIconImage(icon: category.icon)
                        .frame(width: iconSize, height: iconSize)
                }
                .frame(width: iconCircleSize, height: iconCircleSize)
                
                Spacer().frame(width: iconToNameSpacing)
            } else {
                Spacer().frame(width: 8)
            }
            
            Text(category.name)
                .font(.system(size: 13, weight: .semibold))
            .scaleEffect(x: 1, y: 1)
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: nameWidth, alignment: .leading)
                .clipped()
                .mask {
                    if isTruncated {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.70),
                                .init(color: .black.opacity(0.7), location: 0.82),
                                .init(color: .black.opacity(0.25), location: 0.93),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.black
                    }
                }
            
            Spacer().frame(width: nameToAmountSpacing)
            
            Text(amountString)
                .font(.system(size: 13, weight: .semibold))
             .scaleEffect(x: 1, y: 1)
                  .foregroundColor(.white.opacity(0.75))
                .fixedSize()
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .frame(height: capsuleHeight)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .clipped()
        .background(
            Capsule()
                .fill(forcedBackground ?? category.color.opacity(0.13))
        )
    }
    
    private func textWidth(_ string: String, size: CGFloat, weight: UIFont.Weight) -> CGFloat {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        return (string as NSString).size(withAttributes: [.font: font]).width
    }
}




// MARK: - Shared header ("Закрыть" / title / chart icon)

struct OperationsHeader: View {
    var showClose: Bool
    var onClose: () -> Void = {}
    
    var body: some View {
        HStack {
            if showClose {
                Button("Закрыть", action: onClose)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(DS.chipActive)
            } else {
                Color.clear.frame(width: 60)
            }
            
            Spacer()
            
            Text("Операции")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .offset(x: -25)
            
            Spacer()
            
            Image("IMG_2519")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipped()
                .fixedSize()
        }
        .frame(height: 44)
        .padding(.horizontal, DS.margin)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Shared search field

struct SearchField: View {
    @Binding var text: String

    /// Высота плашки. По умолчанию — полная; OperationsView уменьшает её
    /// до нуля, пока список прокручивают (плашка "сворачивается").
    var height: CGFloat = DS.searchHeight
    /// Прозрачность иконки и текста внутри плашки (сама плашка не гаснет —
    /// сначала пропадает содержимое, потом плашка сужается).
    var contentOpacity: Double = 1
    /// Отступ под плашкой — тоже схлопывается вместе с ней.
    var bottomPadding: CGFloat = 16

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(DS.textSecondary)
                .offset(x: -8)
            TextField(
                "",
                text: $text,
                prompt: Text("Поиск")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(DS.textSecondary)
            )
            .offset(x: -10, y: 1)
        }
        .padding(.horizontal, 14)
        .frame(height: DS.searchHeight)
        .opacity(contentOpacity)
        // Содержимое всегда полной высоты и прижато к верху, а сжимается
        // только внешняя рамка — так плашка "уезжает" вверх, а не
        // пережимает текст.
        .frame(height: height, alignment: .top)
        .background(DS.chipBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.searchCornerRadius))
        .allowsHitTesting(height > 20)
        .padding(.horizontal, DS.margin)
        .padding(.bottom, bottomPadding)
    }
}

// MARK: - Hero frame measurement
//
// Replaces matchedGeometryEffect, which doesn't reliably interpolate in this
// nested Swift Playgrounds preview context (confirmed: instant pop instead of
// a smooth transition). Instead, an invisible placeholder publishes its own
// on-screen frame (in a shared "hero" coordinate space); a single persistent
// overlay view elsewhere in the tree reads that frame directly and is
// positioned/scaled from it inside a withAnimation block. Because it's the
// same view the whole time — just animated via state — SwiftUI interpolates
// it reliably, unlike a transition tied to mounting/unmounting a view.

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Публикует фрейм этой view (в именованном координатном пространстве
    /// "hero") под ключом `id`. Чисто наблюдательно — не влияет на layout
    /// или внешний вид.
    func measureFrame(id: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: FramePreferenceKey.self,
                    value: [id: geo.frame(in: .named("hero"))]
                )
            }
        )
    }
}

// MARK: - Ring carousel (used for months, weeks, years — any index-ordered list)

/// Горизонтальная карусель колец. Каждая "страница" — отдельное кольцо;
/// соседние элементы видны частично по краям, как во время свайпа.
/// Прокрутка синхронизирована с selectedIndex, который также управляет
/// заголовком чипа периода наверху экрана — так что свайп по кольцу меняет
/// подпись фильтра и наоборот. Универсальна по смыслу элементов (месяцы,
/// недели, годы) — принимает только их количество плюс данные категорий
/// для конкретного индекса; кольца, кроме текущего выбранного, рисуются
/// пустым треком (у них нет видимых данных, пока страница не открыта).
struct RingCarousel: View {
    let itemCount: Int
    @Binding var selectedIndex: Int
    var categoriesForIndex: (Int) -> [CategoryEntry] = { _ in [] }
    var onRingTap: () -> Void = {}
    @State private var scrollPosition: Int?
    
    /// Ширина "слота" одной страницы — шире самого кольца, чтобы соседние
    /// кольца оставались видны частично по краям экрана.
    private let itemWidth: CGFloat = 220
    
    /// Есть ли у кольца с этим индексом хоть одна категория с ненулевой
    /// суммой — то же условие, что CategoryDonut использует внутри себя
    /// для построения сегментов (см. orderedCategories/segments), чтобы
    /// затемнение точно совпадало с тем, действительно ли кольцо заполнено.
    private func hasData(at index: Int) -> Bool {
        categoriesForIndex(index).contains { $0.amount > 0 }
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<itemCount, id: \.self) { index in
                        ZStack {
                            Circle()
                                .stroke(
                                    DS.ringTrack,
                                    style: StrokeStyle(
                                        lineWidth: DS.ringStroke,
                                        lineCap: .round
                                    )
                                )
                                .frame(
                                    width: DS.ringDiameter,
                                    height: DS.ringDiameter
                                )
                            
                            // Раньше сегменты рисовались только у
                            // выбранного кольца — соседние показывали
                            // пустой серый трек, пока до них не долистаешь.
                            // Теперь дуги видны всегда (кольцо "торчит" по
                            // краю экрана уже заполненным), а иконки и
                            // проценты — только у выбранного (showDetails).
                            CategoryDonut(
                                categories: categoriesForIndex(index),
                                showDetails: index == selectedIndex
                            )
                        }
                        .frame(width: itemWidth)
                        .contentShape(Rectangle())
                        .id(index)
                        // Кольцо симметрично, поэтому зеркалирование
                        // layoutDirection снаружи на нём не сказывается —
                        // возвращаем обычное (LTR) поведение на всякий
                        // случай, если внутрь когда-нибудь добавят текст.
                        .environment(\.layoutDirection, .leftToRight)
                        // Темнеет только то кольцо, которое "уходит" —
                        // то есть уже заполнено категориями, но перестало
                        // быть выбранным. Пустые кольца (только серый
                        // трек) не темним — там нечего подсвечивать.
                        //
                        // Раньше здесь были .brightness()/.opacity() —
                        // они фильтруют уже готовую картинку, а кольцо
                        // само по себе состоит из нескольких наложенных
                        // полупрозрачных слоёв (glow, тени-капы на конце
                        // каждого сегмента, сама дуга). Фильтр поверх
                        // всего этого стека обнажал швы между слоями —
                        // они начинали читаться как отдельные "блины".
                        // Вместо фильтра просто кладём один плоский
                        // полупрозрачный чёрный слой той же формы поверх
                        // готового кольца — затемнение выходит ровным,
                        // без просвечивания внутренних стыков.
                        .overlay {
                            if index != selectedIndex && hasData(at: index) {
                                Circle()
                                    .stroke(
                                        Color.black.opacity(0.35),
                                        style: StrokeStyle(
                                            lineWidth: DS.ringStroke,
                                            lineCap: .round
                                        )
                                    )
                                    .frame(
                                        width: DS.ringDiameter,
                                        height: DS.ringDiameter
                                    )
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: selectedIndex)
                        .onTapGesture {
                            if index == selectedIndex {
                                onRingTap()
                            } else {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedIndex = index
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, DS.ringStroke / 2)
                .scrollTargetLayout()
                .padding(.horizontal, max(0, (geo.size.width - itemWidth) / 2))
            }
            // Зеркалим направление ленты: следующие (более старые) элементы
            // теперь раскладываются влево от центра, а не вправо, как раньше.
            .environment(\.layoutDirection, .rightToLeft)
            .scrollClipDisabled() 
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition)
            .onAppear {
                // Стартуем со страницы, уже выбранной в чипе периода сверху.
                scrollPosition = selectedIndex
            }
            .onChange(of: scrollPosition) { _, newValue in
                
                guard let newValue else { return }
                
                guard selectedIndex != newValue else { return }
                
                withAnimation(.easeInOut(duration: 0.25)) {
                    
                    selectedIndex = newValue
                    
                }
                
            }
            
            .onChange(of: selectedIndex) { _, newValue in
                
                guard scrollPosition != newValue else { return }
                
                withAnimation(.easeInOut(duration: 0.03)) {
                    
                    scrollPosition = newValue
                    
                }
                
            }
        }
        .frame(height: DS.ringDiameter + DS.ringStroke)
    }
}

// MARK: - Category icon (обычная картинка из справочника, либо системный SF Symbol для "Остальное")

/// Единая точка рендера иконки категории — используется и в бейдже на
/// кольце (CategoryDonut), и в чипах под ним (categoryChips), чтобы
/// синтетическая категория "Остальное" (см. CategoryEntry.otherIconKey)
/// везде рисовалась одинаково: системным symbol'ом "ellipsis" вместо
/// картинки из Assets.xcassets, которой для неё не существует.
// MARK: - Category icon
struct CategoryIconImage: View {
    
    let icon: String
    
    
    
    var body: some View {
        
        if icon == CategoryEntry.otherIconKey {
            Image("other_icon")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .padding(2)
            
            
        } else if icon == "neoevmdh" {
            // Переводы — картинка в справочнике мельче остальных на вид,
            // увеличиваем именно её, не трогая размер самого кружка-фона
            // (он задаётся снаружи, через .frame на CategoryIconImage).
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(1.4)
            
        } else {
            
            Image(icon)
            
                .resizable()
            
                .aspectRatio(contentMode: .fit)
            
        }
    }
}



struct CategoryDonut: View {
    let categories: [CategoryEntry]
    
    /// Когда false — рисуются только цветные дуги, без иконок категорий и
    /// подписей процентов. Нужно для соседних (невыбранных) колец в
    /// RingCarousel: они теперь всегда показывают свои настоящие сегменты
    /// (а не пустой серый трек), но без деталей, которые имеют смысл
    /// только для открытого/выбранного кольца.
    var showDetails: Bool = true
    
    /// Минимальная визуальная ширина маленькой категории — раньше была
    /// захардкожена как 22°, что при DS.ringStroke = 23 и
    /// DS.ringDiameter = 120 даёт дугу примерно ТОЙ ЖЕ длины, что и
    /// диаметр её собственной круглой капы на конце. Из-за этого
    /// маленькая категория превращалась не в дугу, а фактически в один
    /// кружок, и несколько таких сегментов подряд сливались в кучку
    /// точек вместо чётких раздельных дуг. Считаем минимум от реальной
    /// геометрии кольца — арка должна быть заметно длиннее собственной
    /// капы, чтобы дуга читалась как дуга, а не терялась под скруглённым
    /// концом. Множитель 1.7 (не 2.4) — раньше при 4-5 мелких категориях
    /// сразу их суммарный принудительный минимум "съедал" почти весь
    /// круг, оставляя доминантному сегменту только жалкий остаток вместо
    /// честной доли, даже после того как ужесточили компенсацию именно у
    /// него (см. segments ниже). 1.7 — компромисс: сегмент всё ещё
    /// заметно шире своей капы, но при типичном числе мелких категорий
    /// (3-5) в сумме не отъедает больше половины круга.
    private var minimumVisualSweep: Double {
        let minimumArcLength = DS.ringStroke * 1.1
        let circumference = Double.pi * DS.ringDiameter
        return (minimumArcLength / circumference) * 360
    }
    
    /// Минимальный угол основной категории.
    private let minimumDominantSweep: Double = 90
    
    /// Небольшой зазор между окончаниями дуг.
    private let gapDegrees: Double = 0
    
    private let iconSize: CGFloat = 22
    private let labelDistance: CGFloat = 18
    
    /// Настройки тени закруглённых концов.
    private let capShadowDistance: CGFloat = 6
    private let capShadowRadius: CGFloat = 8
    
    /// Насколько раньше настоящей границы (segment.visualEnd) обрываем
    /// фон topSegment — в градусах, а не в доле круга. Это важно: доля
    /// круга была бы одинаковой независимо от того, сколько именно
    /// составляет topSegment (1%, 3%, 8%...), и при другом проценте
    /// кружок-капа либо не доставал бы до соседа, либо налезал на него.
    /// Отсчёт в градусах от реальной границы всегда даёт одинаковый
    /// зазор под капу, вне зависимости от размера сегмента.
    private let topSegmentGapDegrees: Double = 0
    
    private struct Segment {
        let category: CategoryEntry
        let actualFraction: Double
        let visualStart: Double
        let visualEnd: Double
        
        var visualMid: Double {
            (visualStart + visualEnd) / 2
        }
        
        var percent: Int {
            let rounded = Int((actualFraction * 100).rounded())
            // Категория с ненулевой суммой не должна отображаться как 0% —
            // после округления даём минимум 1%, чтобы на кольце не было
            // сегментов с подписью "0%".
            return actualFraction > 0 ? max(rounded, 1) : rounded
        }
    }
    /// Самая большая категория остаётся первой.
    /// Самая маленькая переносится в конец и становится участком,
    /// расположенным около 12 часов.
    private var orderedCategories: [CategoryEntry] {
        var result = categories
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
        
        guard result.count > 1 else {
            return result
        }
        
        let topIndex: Int
        
        if let otherIndex = result.firstIndex(
            where: { $0.icon == CategoryEntry.otherIconKey }
        ) {
            topIndex = otherIndex
        } else {
            topIndex = result.indices.min {
                result[$0].amount < result[$1].amount
            } ?? result.index(before: result.endIndex)
        }
        
        let topCategory = result.remove(at: topIndex)
        result.append(topCategory)
        
        return result
    }
    
    private var segments: [Segment] {
        let items = orderedCategories
        
        let total = items.reduce(0.0) {
            $0 + $1.amount
        }
        
        guard total > 0, !items.isEmpty else {
            return []
        }
        
        let realSweeps = items.map {
            ($0.amount / total) * 360
        }
        
        guard realSweeps.count > 1 else {
            return [
                Segment(
                    category: items[0],
                    actualFraction: 1,
                    visualStart: 0,
                    visualEnd: 360
                )
            ]
        }
        
        let dominantReal = realSweeps[0]
        let secondaryReal = Array(realSweeps.dropFirst())
        
        // Поднимаем маленькие категории до минимума. Раньше "стоимость"
        // этого подъёма проверялась только против общего потолка
        // (360 - minimumDominantSweep = 270°) — если сумма минимумов
        // укладывалась в 270°, доминантный сегмент ужимался до жалкого
        // остатка НЕЗАВИСИМО от того, сколько градусов реально было
        // "занято" у него мелкими категориями (85%|10%|6%|2%|2%|1% на
        // 5 мелких сегментах при минимуме ~53° давали сумму 265° — под
        // потолком, поэтому доминантный получал 360-265=95° вместо
        // честных ~288°). Теперь у доминантного забирается ТОЛЬКО
        // реальный излишек — разница между тем, что мелкой категории
        // выдали (minimum) и что ей причиталось по факту (real).
        let secondaryBumped = secondaryReal.map {
            max($0, minimumVisualSweep)
        }
        
        let extraGiven = zip(secondaryBumped, secondaryReal)
            .reduce(0.0) { $0 + max(0, $1.0 - $1.1) }
        
        let dominantSweep = max(
            minimumDominantSweep,
            dominantReal - extraGiven
        )
        
        // Если вычесть extraGiven целиком не удалось (упёрлись в
        // minimumDominantSweep), сумма секундарных всё ещё может
        // превышать оставшийся бюджет — тогда, и только тогда,
        // пропорционально ужимаем их все, чтобы сумма сошлась ровно
        // в 360° без переполнения.
        let secondaryBudget = 360 - dominantSweep
        let secondaryTotal = secondaryBumped.reduce(0, +)
        
        let secondarySweeps: [Double]
        
        if secondaryTotal > secondaryBudget, secondaryTotal > 0 {
            let scale = secondaryBudget / secondaryTotal
            secondarySweeps = secondaryBumped.map { $0 * scale }
        } else {
            secondarySweeps = secondaryBumped
        }
        
        var cursor: Double = 0
        var result: [Segment] = []
        
        for index in items.indices {
            let sweep: Double
            
            if index == 0 {
                sweep = dominantSweep
            } else {
                sweep = secondarySweeps[index - 1]
            }
            
            result.append(
                Segment(
                    category: items[index],
                    actualFraction: items[index].amount / total,
                    visualStart: cursor,
                    visualEnd: cursor + sweep
                )
            )
            
            cursor += sweep
        }
        
        return result
    }
    
    private func offset(
        angleDegrees: Double,
        radius: CGFloat
    ) -> CGSize {
        let radians = angleDegrees * .pi / 180
        
        return CGSize(
            width: radius * CGFloat(sin(radians)),
            height: -radius * CGFloat(cos(radians))
        )
    }
    
    /// Тень направляется по касательной к кольцу.
    private func capShadowOffset(
        angleDegrees: Double
    ) -> CGSize {
        let radians = angleDegrees * .pi / 180
        
        return CGSize(
            width: capShadowDistance * CGFloat(cos(radians)),
            height: capShadowDistance * CGFloat(sin(radians))
        )
    }
    
    /// Тень направляется радиально наружу от центра кольца —
    /// используется для капы dominant, где обычная касательная тень
    /// затекает на соседний сегмент.
    private func capShadowOffsetRadial(
        angleDegrees: Double
    ) -> CGSize {
        let radians = angleDegrees * .pi / 180
        
        return CGSize(
            width: capShadowDistance * CGFloat(sin(radians)),
            height: -capShadowDistance * CGFloat(cos(radians))
        )
    }
    
    private func visualRange(
        for segment: Segment,
        startInsetDegrees: Double = 0,
        endOverlapDegrees: Double = 0
    ) -> (start: CGFloat, end: CGFloat) {
        let gapFraction =
        CGFloat(gapDegrees / 360)
        
        let overlapFraction: CGFloat = 0.0015 // ≈0.5° нахлёст на старте
        
        let start = max(
            0,
            CGFloat((segment.visualStart + startInsetDegrees) / 360) - overlapFraction
        )
        
        let originalEnd =
        CGFloat(segment.visualEnd / 360)
        
        // endOverlapDegrees позволяет для конкретных вызовов
        // (например, topSegment) убрать/уменьшить обычный gap на конце.
        let effectiveGapFraction = max(
            0,
            gapFraction - CGFloat(endOverlapDegrees / 360)
        )
        
        let end = max(
            start + 0.0001,
            originalEnd - effectiveGapFraction
        )
        
        return (
            max(0, start),
            min(1, end)
        )
    }
    
    /// Доля круга (0...1), до которой рисуется фон topSegment: обрывается
    /// на `topSegmentGapDegrees` раньше его настоящей границы
    /// (`segment.visualEnd`), а не на произвольной доле всего круга.
    /// Именно в этот зазор садится кружок-капа в цикле иконок — так он
    /// всегда попадает точно перед реальным концом topSegment, независимо
    /// от того, какой у него процент.
    private func topSegmentClosureFraction(for segment: Segment) -> Double {
        max(0, (segment.visualEnd - topSegmentGapDegrees) / 360)
    }
    
    /// Короткий участок около конца дуги.
    /// Его цвет перекрывается основной дугой, снаружи остаётся тень.
    private func shadowRange(
        for segment: Segment,
        extraStubDegrees: Double = 0
    ) -> (start: CGFloat, end: CGFloat) {
        let range = visualRange(for: segment)
        
        let availableLength =
        range.end - range.start
        
        let baseStubFraction = min(
            (DS.ringStroke * 1.3) /
            (CGFloat.pi * DS.ringDiameter),
            availableLength
        )
        
        let extraFraction =
        CGFloat(extraStubDegrees / 360)
        
        let stubFraction = min(
            baseStubFraction + extraFraction,
            availableLength
        )
        
        return (
            max(
                range.start,
                range.end - stubFraction
            ),
            range.end
        )
    }
    
    var body: some View {
        
        let currentSegments: [Segment] = segments
        
        let topSegment: Segment? = currentSegments.last
        
        let isSingleSegment = currentSegments.count == 1
        
        let nonTopSegments = Array(currentSegments.dropLast())
        let dominantSegment = nonTopSegments.first
        let restReversed = Array(nonTopSegments.dropFirst().reversed())
        
        let visibleSegments: [Segment] = isSingleSegment
        ? []
        : (dominantSegment.map { [$0] } ?? [])
        + (topSegment.map { [$0] } ?? [])
        + restReversed
        
        let indexedVisibleSegments =
        Array(visibleSegments.enumerated())
        
        // ВАЖНО: вся отрисовка CategoryDonut — glow включительно — должна
        // находиться внутри ОДНОГО фиксированного ZStack 120x120. Раньше
        // "Glow" и "Glow одиночного сегмента" были самостоятельными
        // top-level элементами body ДО открытия этого ZStack — то есть не
        // его детьми, а его соседями по неявному TupleView. Голый Circle()
        // без своего .frame() в такой позиции получает предложенный размер
        // от ЛЮБОГО внешнего контейнера, который в итоге приютит
        // CategoryDonut (например, ZStack{Circle(120x120); CategoryDonut()}
        // в кастомном кольце календарного диапазона) — а не от финального
        // .frame(width: DS.ringDiameter, height: DS.ringDiameter), который
        // привязан только ко ВТОРОМУ ZStack ниже. Из-за этого glow-круги
        // раздувались на весь доступный контейнеру простор и утягивали за
        // собой реальную высоту всего кольца (сегмент "распирал" layout
        // ScrollView, отталкивая период-пикер вниз, иногда за пределы
        // экрана). Теперь ZStack открывается ЗДЕСЬ, до glow, и закрывается
        // один раз в самом конце — единственный .frame() в самом низу
        // ограничивает всё целиком.
        
        ZStack {
            
            // MARK: - Glow
            
            ForEach(
                indexedVisibleSegments,
                id: \.offset
            ) { item in
                
                let segment = item.element
                
                let isDominant = segment.visualStart == 0
                
                let isTopSegment =
                item.offset == visibleSegments.count - 1
                
                let startInset: Double =
                isDominant
                ? 0
                : (isTopSegment ? -5.0 : 10.0)
                
                let range = visualRange(
                    for: segment,
                    startInsetDegrees: isDominant ? 0 : startInset,
                    endOverlapDegrees: isDominant ? -6.0 : 0
                )
                
                Circle()
                    .trim(
                        from: range.start,
                        to: range.end
                    )
                    .stroke(
                        segment.category.color,
                        style: StrokeStyle(
                            lineWidth: DS.ringStroke,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 12)
                    .opacity(0.35)
            }
            
            // MARK: - Glow одиночного сегмента
            
            if isSingleSegment, let segment = currentSegments.first {
                
                let range = visualRange(
                    for: segment,
                    startInsetDegrees: 0
                )
                
                Circle()
                    .trim(
                        from: range.start,
                        to: range.end
                    )
                    .stroke(
                        segment.category.color,
                        style: StrokeStyle(
                            lineWidth: DS.ringStroke,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 12)
                    .opacity(0.35)
            }
            
            let indexedCurrentSegments =
            Array(currentSegments.enumerated())
            
            
            // 1. Все дуги снизу (включая начало следующей дуги)
            
            ForEach(indexedCurrentSegments, id: \.offset) { item in
                
                let segment = item.element
                
                let isTop = item.offset == currentSegments.count - 1
                
                if isTop && !isSingleSegment {
                    // topSegment в мульти-сегментном случае рисуется
                    // только в секции "Остальные дуги" ниже — здесь
                    // его дублировать не нужно, иначе он сольётся
                    // с соседним сегментом.
                    EmptyView()
                } else {
                    let range = visualRange(
                        for: segment,
                        startInsetDegrees: isTop ? 0 : 2
                    )
                    
                    Circle()
                        .trim(from: range.start, to: range.end)
                        .stroke(
                            segment.category.color,
                            style: StrokeStyle(
                                lineWidth: DS.ringStroke,
                                lineCap: .butt
                            )
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
            
            // 2. КАПА — поверх начала следующей дуги
            
            if isSingleSegment, let topSegment {
                
                let angle = topSegmentClosureFraction(for: topSegment) * 360
                
                Circle()
                    .fill(topSegment.category.color)
                    .frame(width: DS.ringStroke, height: DS.ringStroke)
                    .shadow(color: .black.opacity(0.34), radius: capShadowRadius, x: 0, y: -2)
                    .offset(offset(angleDegrees: angle, radius: DS.ringDiameter / 2))
            }
            
            
            // 3. Конец текущей дуги — поверх капы
            
            if isSingleSegment, let topSegment {
                
                let shadow =
                
                shadowRange(
                    
                    for: topSegment
                    
                )
                
                Circle()
                
                    .trim(
                        
                        from: shadow.start,
                        
                        to: shadow.end
                        
                    )
                
                    .stroke(
                        
                        topSegment.category.color,
                        
                        style: StrokeStyle(
                            
                            lineWidth: DS.ringStroke,
                            
                            lineCap: .round
                            
                        )
                        
                    )
                
                    .rotationEffect(
                        
                        .degrees(-90)
                    )
            }
            
            
            
            
            // MARK: - Остальные дуги
            
            ForEach(
                indexedVisibleSegments,
                id: \.offset
            ) { item in
                
                let segment = item.element
                
                let isDominant =
                segment.visualStart == 0
                
                let isTopSegmentInLoop =
                item.offset == visibleSegments.count - 1
                
                let startInset: Double =
                isDominant ? 0 : (isTopSegmentInLoop ? -5.0 : 2.0)
                
                let range =
                visualRange(
                    for: segment,
                    startInsetDegrees: isDominant ? 0 : startInset,
                    endOverlapDegrees: isDominant ? -6.0 : 0
                )
                
                let shadow =
                shadowRange(
                    for: segment,
                    extraStubDegrees: 0
                )
                
                
                // Тень конца сегмента
                
                Circle()
                    .trim(
                        from: shadow.start,
                        to: shadow.end
                    )
                    .stroke(
                        segment.category.color,
                        style: StrokeStyle(
                            lineWidth: DS.ringStroke,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(
                        .degrees(-90)
                    )
                    .shadow(
                        color: .black.opacity(0.6),
                        radius: capShadowRadius,
                        x: 2,
                        y: 2
                    )
                
                
                // Основная дуга
                
                Circle()
                    .trim(
                        from: range.start,
                        to: range.end
                    )
                    .stroke(
                        segment.category.color,
                        style: StrokeStyle(
                            lineWidth: DS.ringStroke,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(
                        .degrees(-90)
                    )
            }
            
            
            // MARK: - Иконки + капа верхнего сегмента
            //
            // Капа topSegment рисуется здесь и только здесь — это
            // единственное место в теле view, где создаётся этот
            // кружок. Он рисуется последним в ZStack (после всех дуг),
            // поэтому лежит поверх них, и одновременно садится ровно в
            // зазор, оставленный фоном topSegment выше — без наложения
            // на соседний сегмент и без отдельной тени, которая раньше
            // создавала шов.
            //
            // Сам кружок-капа рисуется всегда (в том числе на
            // невыбранных кольцах) — пропадает только иконка внутри
            // него (showDetails), чтобы кольцо не выглядело "обрубленным"
            // при пролистывании.
            
            ForEach(
                indexedCurrentSegments,
                id: \.offset
            ) { item in
                
                let segment =
                item.element
                
                let index =
                item.offset
                
                let isTopSegment =
                index == currentSegments.count - 1
                
                let isDominant =
                segment.visualStart == 0
                
                // Иконку доминантного сегмента (в мульти-случае)
                // рисуем отдельно, вместе с его капой — здесь пропускаем
                if isDominant && !isSingleSegment {
                    EmptyView()
                } else {
                    
                    let range =
                    visualRange(for: segment)
                    
                    let iconAngle: Double =
                    (isTopSegment && isSingleSegment)
                    ? topSegmentClosureFraction(for: segment) * 360
                    : Double(range.end) * 360
                    
                    
                    ZStack {
                        if isTopSegment && isSingleSegment {
                            
                            Circle()
                                .fill(segment.category.color)
                                .frame(
                                    width: DS.ringStroke,
                                    height: DS.ringStroke
                                )
                        }
                        
                        
                        
                        if showDetails {
                            CategoryIconImage(
                                icon: segment.category.icon
                            )
                            .frame(
                                width: iconSize,
                                height: iconSize
                            )
                        }
                    }
                    .offset(
                        offset(
                            angleDegrees: iconAngle,
                            radius: DS.ringDiameter / 2
                        )
                    )
                }
            }
            
            // MARK: - Капа доминантного сегмента (стык dominant -> seg1)
            
            if !isSingleSegment, let dominantSegment {
                
                let dominantCapInsetDegrees: Double = 10.5
                let angle = dominantSegment.visualEnd - dominantCapInsetDegrees
                
                // Насколько тень выступает из-под капы — настраивайте это значение,
                // чтобы подобрать нужный выступ. 0 = тень полностью под капой (не видна),
                // больше значение = тень выглядывает сильнее.
                let dominantCapShadowDistance: CGFloat = 3
                
                // Угол смещения тени по касательной. Если тень выглядывает не с той
                // стороны — поменяйте знак (например, на -1) или прибавьте 180 к angle.
                let shadowRadians = angle * .pi / 180
                let shadowOffset = CGSize(
                    width: dominantCapShadowDistance * CGFloat(cos(shadowRadians)),
                    height: dominantCapShadowDistance * CGFloat(sin(shadowRadians))
                )
                
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.07))
                        .frame(width: DS.ringStroke, height: DS.ringStroke)
                        .blur(radius: capShadowRadius / 12) 
                        .offset(shadowOffset)
                    
                    Circle()
                        .fill(dominantSegment.category.color)
                        .frame(width: DS.ringStroke, height: DS.ringStroke)
                    
                    if showDetails {
                        CategoryIconImage(icon: dominantSegment.category.icon)
                            .frame(width: iconSize, height: iconSize)
                    }
                }
                .offset(offset(angleDegrees: angle, radius: DS.ringDiameter / 2))
            }
            
            // MARK: - Проценты
            
            if showDetails {
                ForEach(
                    indexedCurrentSegments,
                    id: \.offset
                ) { item in
                    
                    let segment =
                    item.element
                    
                    let radius =
                    DS.ringDiameter / 2
                    + DS.ringStroke / 2
                    + labelDistance
                    
                    
                    Text("\(segment.percent)%")
                        .font(
                            .system(
                                size: 11,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            DS.textSecondary
                        )

                        .offset(
                            offset(
                                angleDegrees: segment.visualMid,
                                radius: radius
                            )
                        )
                }
            }
        }
        .frame(
            width: DS.ringDiameter,
            height: DS.ringDiameter
        )
    }
}

// MARK: - Category donut (colored segments drawn over a ring)

/// Рисует кольцо реальными цветными сегментами по категориям (пропорционально
/// сумме каждой). Верхний сегмент (topSegment, см. ниже) рисуется как дуга,
/// намеренно обрываемая чуть раньше своей настоящей границы
/// (topSegmentGapDegrees) — оставшийся зазор перекрывается кружком-капой,
/// который рисуется в цикле иконок вместе с иконкой категории. Остальные
/// сегменты рисуются как обрезанные (`trim`) дуги со своими тенями-бейджами
/// на конце дуги. Ничего не рисует, если категорий ещё нет (виден только
/// пустой серый трек под ним).


// MARK: - Operation type (used to drive the detail overlay)

enum OperationType: String, Codable, Identifiable {
    case spending
    case income
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .spending: "Нет трат"
        case .income: "Нет доходов"
        }
    }
    
    /// Короткая подпись под суммой на главном экране ("Траты"/"Доходы") —
    /// отдельно от title, который используется как замена суммы, когда
    /// операций ещё нет ("Нет трат"/"Нет доходов").
    var shortTitle: String {
        switch self {
        case .spending: "Траты"
        case .income: "Доходы"
        }
    }
}

