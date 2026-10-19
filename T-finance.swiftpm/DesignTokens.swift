import SwiftUI

/// Единая точка форматирования сумм — используется и в заголовке кольца,
/// и в карточке, и в чипах категорий, чтобы "113 706 Br" везде выглядело
/// одинаково и не дублировалось по три раза в разных файлах.
///
/// Копейки показываются только когда они есть ("115,98"), у целых сумм
/// ("2 038") дробной части нет — как в списке операций Т-Банка.
func formattedAmount(_ value: Double) -> String {
    let rounded = (value * 100).rounded() / 100
    let hasKopecks = rounded != rounded.rounded()
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    formatter.decimalSeparator = ","
    formatter.minimumFractionDigits = hasKopecks ? 2 : 0
    formatter.maximumFractionDigits = hasKopecks ? 2 : 0
    return formatter.string(from: NSNumber(value: rounded)) ?? "\(Int(rounded))"
}

/// Все значения сняты прямым пиксельным анализом присланных скриншотов
/// (iPhone 14/15 Pro, 3x, 393pt ширина экрана), а не подобраны на глаз.
enum DS {
    // MARK: Colors (exact RGB sampled from screenshots)

    static let background       = Color(red: 28/255,  green: 28/255,  blue: 30/255)   // #1C1C1E
    static let cardBackground   = Color(red: 44/255,  green: 44/255,  blue: 46/255)   // #2C2C2E
    static let chipBackground   = Color(red: 50/255, green: 50/255, blue: 52/255) // #323234
    static let amountBadgeBg = Color(red: 71/255, green: 71/255, blue: 73/255) // #474749
    static let chipActive       = Color(red: 66/255,  green: 139/255, blue: 249/255)  // #428BF9
    static let capsulePlaceholder = Color(red: 75/255, green: 75/255, blue: 77/255)   // #4B4B4D
    static let ringTrack        = Color(red: 62/255,  green: 62/255,  blue: 64/255)   // #3E3E40
    static let closeButtonBg    = Color(red: 51/255,  green: 51/255,  blue: 51/255)   // #333333
    static let closeButtonIcon  = Color(red: 146/255, green: 153/255, blue: 162/255)  // #929AA2
    static let textSecondary    = Color(red: 142/255, green: 142/255, blue: 147/255)  // systemGray
    static let periodPickerBackground = Color(
        red: 62.0 / 255.0,
        green: 62.0 / 255.0,
        blue: 64.0 / 255.0
    )
    
    static let periodPickerSelected = Color(
        red: 77.0 / 255.0,
        green: 77.0 / 255.0,
        blue: 77.0 / 255.0
    )

    // MARK: Metrics (points, derived from px/3 on the reference screenshots)

    static let margin: CGFloat = 16

    static let searchHeight: CGFloat = 36
    static let searchCornerRadius: CGFloat = 12

    static let chipHeight: CGFloat = 28
    static let chipSpacing: CGFloat = 10

    static let rowGap: CGFloat = 20 // chips -> cards / chips -> content

    static let cardHeight: CGFloat = 106
    static let cardCornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let cardTitleFont: CGFloat = 16

    static let capsuleBarHeight: CGFloat = 11

    static let detailTitleFont: CGFloat = 30
    static let closeButtonDiameter: CGFloat = 30

    /// Масштаб заголовка карточки относительно заголовка в открытой карточке.
    /// Обе Text-вьюхи используют один и тот же шрифт (detailTitleFont, bold);
    /// маленький размер на карточке достигается через scaleEffect, а не через
    /// отдельный .font(), потому что .font() не интерполирует размер плавно —
    /// он переключается мгновенно. Единственная видимая копия заголовка —
    /// hero-overlay в OperationsView, который сам анимирует этот scaleEffect
    /// между 1 и cardTitleScale внутри withAnimation.
    static let cardTitleScale: CGFloat = cardTitleFont / detailTitleFont

    /// Размер текста пустого состояния списка ("Тут будем показывать...") и
    /// пустого состояния детали ("Таких операций нет...") — это разные
    /// строки, поэтому между ними не hero-анимация, а обычный opacity-кросс-фейд.
    static let emptyStateFont: CGFloat = 15
    static let emptyStateCompactFont: CGFloat = 13

    static let ringDiameter: CGFloat = 120
    static let ringStroke: CGFloat = 23
    static let ringToTitleGap: CGFloat = 47
    static let ringToControlsGap: CGFloat = 30

    static let controlsHeight: CGFloat = 32
}
