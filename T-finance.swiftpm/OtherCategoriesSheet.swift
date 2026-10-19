import SwiftUI

/// Открывается по тапу на капсулу "Остальное" под кольцом (см.
/// OperationDetailView.categoryChips). Показывает те же CategoryEntry, что
/// groupedForDisplay() схлопнул в один сегмент — то есть "разворачивает"
/// капсулу обратно в исходный список категорий, отсортированный по убыванию
/// суммы, тем же CategoryChipCard/CategoryCapsuleFlowLayout, которыми
/// рисуются обычные капсулы, чтобы визуально шит не отличался от основного
/// экрана.
struct OtherCategoriesSheet: View {
    let categories: [CategoryEntry]
    let onClose: () -> Void

    private var total: Double {
        categories.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 16)
            
            ScrollView {
                GeometryReader { geometry in
                    let containerWidth = geometry.size.width
                    let maxCapsuleWidth = containerWidth * 0.49

                    CategoryCapsuleFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(categories) { category in
                            CategoryChipCard(
                                category: category,
                                maxWidth: maxCapsuleWidth,
                                showIcon: false,
                                forcedBackground: Color.white.opacity(0.08)
                            )
                        }
                    }
                    .frame(width: containerWidth, alignment: .leading)
                    .background(
                        GeometryReader { innerGeo in
                            Color.clear.preference(key: FlowHeightKey.self, value: innerGeo.size.height)
                        }
                    )
                }
                .frame(height: flowHeight)
                .onPreferenceChange(FlowHeightKey.self) { flowHeight = $0 }
                .padding(.horizontal, DS.margin)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color(red: 0.105, green: 0.105, blue: 0.115))
        .frame(maxWidth: .infinity)
        .preferredColorScheme(.dark)
        .presentationDetents([.height(420)])
        .presentationCompactAdaptation(.sheet)
        .presentationCornerRadius(12)
    }

    private var categoriesWord: String {
        // Простое русское склонение "категория/категории/категорий" по
        // последней цифре — этого достаточно, т.к. счёт тут всегда
        // небольшой (хвост после топ-5).
        let n = categories.count % 100
        let lastDigit = n % 10
        if (11...14).contains(n) { return "категорий" }
        switch lastDigit {
        case 1: return "категория"
        case 2, 3, 4: return "категории"
        default: return "категорий"
        }
    }

    // Высота флоу-раскладки капсул не известна заранее (зависит от того,
    // сколько их и как они переносятся по строкам) — меряем так же, как
    // categoryChips в OperationDetailView, и подставляем в .frame(height:).
    @State private var flowHeight: CGFloat = 44

    private struct FlowHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 44
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    private var header: some View {
        HStack {
            Button("Закрыть", action: onClose)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Color.blue)

            Spacer()

            Text("Остальное")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white)

            Spacer()

            // Пустая кнопка-заглушка той же ширины, что "Закрыть" — чтобы
            // заголовок остался по центру, как в AddCategorySheet.
            Text("Закрыть")
                .font(.system(size: 17, weight: .light))
                .opacity(0)
        }
        .padding(.horizontal, 12)
        .frame(height: 68)
    }
}
