import SwiftUI

struct CategoryEntry: Identifiable, Equatable {
    let id: UUID
    var name: String
    var amount: Double
    var icon: String
    var color: Color

    init(id: UUID = UUID(), name: String, amount: Double, icon: String, color: Color) {
        self.id = id
        self.name = name
        self.amount = amount
        self.icon = icon
        self.color = color
    }

    static func == (lhs: CategoryEntry, rhs: CategoryEntry) -> Bool {
        lhs.id == rhs.id
        && lhs.amount == rhs.amount
        && lhs.name == rhs.name
        && lhs.icon == rhs.icon
    }

    /// Иконка-сентинел для синтетической категории "Остальное" — не привязана
    /// ни к одному asset'у из справочника, вместо неё в UI рисуется системный
    /// SF Symbol "ellipsis" (см. CategoryIconImage в Components.swift).
    static let otherIconKey = "__other__"
}

extension Array where Element == CategoryEntry {
    /// Порядок и состав сегментов ровно как в Т-Банке: сортировка по убыванию
    /// суммы; если категорий больше 6 — топ-5 остаются отдельными сегментами,
    /// а всё, что за ними, схлопывается в один сегмент "Остальное" в конце
    /// (независимо от того, что по сумме он может быть крупнее какой-то
    /// категории из топ-5 — важен именно факт "это хвост списка", а не её
    /// величина). Если категорий 6 или меньше — группировка не нужна,
    /// показываются все как есть.
    func groupedForDisplay() -> [CategoryEntry] {
        let sorted = sorted { $0.amount > $1.amount }
        guard sorted.count > 6 else { return sorted }

        let top = Array(sorted.prefix(5))
        let restTotal = sorted.dropFirst(5).reduce(0) { $0 + $1.amount }
        let other = CategoryEntry(
            name: "Остальное",
            amount: restTotal,
            icon: CategoryEntry.otherIconKey,
            color: Color(hex: "#b4ccdc")
        )
        return top + [other]
    }

    /// Категории, схлопнутые в сегмент "Остальное" — тот же хвост списка
    /// (после топ-5, по убыванию суммы), что groupedForDisplay() сворачивает
    /// в один синтетический CategoryEntry. Нужен отдельно, чтобы было что
    /// показать в шите по тапу на капсулу "Остальное". Пустой массив, если
    /// группировка не применяется (категорий 6 или меньше).
    func otherCategoriesForDisplay() -> [CategoryEntry] {
        let sorted = sorted { $0.amount > $1.amount }
        guard sorted.count > 6 else { return [] }
        return Array(sorted.dropFirst(5))
    }
}

/// Пресет категории: имя, ключ иконки (имя image asset в Assets.xcassets/Categories)
/// и цвет. Список полностью импортирован из личного справочника категорий
/// пользователя (названия, цвета и иконки — 77 категорий расходов и 13
/// категорий доходов).
struct PresetCategory: Identifiable, Hashable {
    let key: String
    var name: String
    var icon: String
    var hex: String

    var id: String { key }

    var color: Color { Color(hex: hex) }
}

extension PresetCategory {
    static let expense: [PresetCategory] = [
        PresetCategory(key: "avrmpajmlh", name: "Автосалоны", icon: "avrmpajmlh", hex: "#66abdd"),
        PresetCategory(key: "naoimvih", name: "Парковки", icon: "naoimvih", hex: "#197fc8"),
        PresetCategory(key: "duty_free", name: "Duty Free", icon: "duty_free", hex: "#1094A8"),
        PresetCategory(key: "avhabhjerh", name: "Авиабилеты", icon: "avhabhjerh", hex: "#6ADFF1"),
        PresetCategory(key: "avrmkmzih", name: "Автомойки", icon: "avrmkmzih", hex: "#6db7ed"),
        PresetCategory(key: "avrmspjsgh", name: "Автоуслуги", icon: "avrmspjsgh", hex: "#52ACED"),
        PresetCategory(key: "pakmiarh", name: "Самокаты", icon: "pakmiarh", hex: "#FED667"),
        PresetCategory(key: "anreih", name: "Аптеки", icon: "anreih", hex: "#66D693"),
        PresetCategory(key: "roelhomvih", name: "Тренировки", icon: "roelhomvih", hex: "#4867FE"),
        PresetCategory(key: "lajmgh", name: "Налоги", icon: "lajmgh", hex: "#16c2b8"),
        PresetCategory(key: "aoelda_avrm", name: "Аренда авто", icon: "aoelda_avrm", hex: "#2C9BEB"),
        PresetCategory(key: "gmpspjsgh", name: "Госуслуги", icon: "gmpspjsgh", hex: "#76CDB9"),
        PresetCategory(key: "oekmlr_h_kebejs", name: "Ремонт и мебель", icon: "oekmlr_h_kebejs", hex: "#2AA276"),
        PresetCategory(key: "o_d_bhjerh", name: "Ж/д билеты", icon: "o_d_bhjerh", hex: "#13B4CD"),
        PresetCategory(key: "ohvmrlhe", name: "Животные", icon: "ohvmrlhe", hex: "#9CCC9A"),
        PresetCategory(key: "oiu", name: "ЖКХ", icon: "oiu", hex: "#6CB67B"),
        PresetCategory(key: "hlreoler", name: "Интернет", icon: "hlreoler", hex: "#7289FE"),
        PresetCategory(key: "hpispprvm", name: "Искусство", icon: "hpispprvm", hex: "#E1626B"),
        PresetCategory(key: "ihlm", name: "Кино", icon: "ihlm", hex: "#CB2AB6"),
        PresetCategory(key: "ilhgh_h_ialfrmvaoh", name: "Книги и канцтовары", icon: "ilhgh_h_ialfrmvaoh", hex: "#FF754A"),
        PresetCategory(key: "ioapmra", name: "Красота", icon: "ioapmra", hex: "#E58BB5"),
        PresetCategory(key: "kedhfhla", name: "Медицина", icon: "kedhfhla", hex: "#5DD5A9"),
        PresetCategory(key: "kmbhjslay_pvyzs", name: "Мобильная связь", icon: "kmbhjslay_pvyzs", hex: "#4D70E2"),
        PresetCategory(key: "kszhia", name: "Музыка", icon: "kszhia", hex: "#E5576D"),
        PresetCategory(key: "mboazmvalhe", name: "Образование", icon: "mboazmvalhe", hex: "#E67976"),
        PresetCategory(key: "mdeoda_h_mbsvs", name: "Одежда и обувь", icon: "mdeoda_h_mbsvs", hex: "#C28AF9"),
        PresetCategory(key: "mrejh", name: "Отели", icon: "mrejh", hex: "#32D3EC"),
        PresetCategory(key: "neoevmdh", name: "Переводы", icon: "neoevmdh", hex: "#4FC5DF"),
        PresetCategory(key: "oazvjehelhy", name: "Развлечения", icon: "oazvjehelhy", hex: "#F369CC"),
        PresetCategory(key: "oazjhhlhe_rmvaoh", name: "Различные товары", icon: "oazjhhlhe_rmvaoh", hex: "#9167E9"),
        PresetCategory(key: "oeprmoalh", name: "Рестораны", icon: "oeprmoalh", hex: "#FE9797"),
        PresetCategory(key: "pvyzs", name: "Связь", icon: "pvyzs", hex: "#5E63F2"),
        PresetCategory(key: "peovhp", name: "Сервис", icon: "peovhp", hex: "#BAA2EC"),
        PresetCategory(key: "pnmorrmvaoh", name: "Спорттовары", icon: "pnmorrmvaoh", hex: "#7289FE"),
        PresetCategory(key: "nmdaoih_h_rvmoheprvm", name: "Подарки и творчество", icon: "nmdaoih_h_rvmoheprvm", hex: "#D0A6FB"),
        PresetCategory(key: "psneokaoierh", name: "Супермаркеты", icon: "psneokaoierh", hex: "#FD9575"),
        PresetCategory(key: "rejevhdelhe", name: "Телевидение", icon: "rejevhdelhe", hex: "#465DCF"),
        PresetCategory(key: "rejetmlhy", name: "Телефония", icon: "rejetmlhy", hex: "#9AABFE"),
        PresetCategory(key: "zanoavih", name: "Заправки", icon: "zanoavih", hex: "#197FC8"),
        PresetCategory(key: "roalpnmor", name: "Транспорт", icon: "roalpnmor", hex: "#6489F1"),
        PresetCategory(key: "rsoagelrprva", name: "Турагентства", icon: "rsoagelrprva", hex: "#15C5E0"),
        PresetCategory(key: "thlalph", name: "Финансы", icon: "thlalph", hex: "#89DCDC"),
        PresetCategory(key: "tmrm_h_imnhfelroh", name: "Фото и копицентры", icon: "tmrm_h_imnhfelroh", hex: "#86D2DC"),
        PresetCategory(key: "fverh", name: "Цветы", icon: "fverh", hex: "#DFAAD9"),
        PresetCategory(key: "oazjhhlhe_spjsgh", name: "Различные услуги", icon: "oazjhhlhe_spjsgh", hex: "#BAA2EC"),
        PresetCategory(key: "cj_imcejsih_h_neoevmdh", name: "Эл. кошельки и переводы", icon: "cj_imcejsih_h_neoevmdh", hex: "#48A4AA"),
        PresetCategory(key: "taprtsd", name: "Фастфуд", icon: "taprtsd", hex: "#FF902A"),
        PresetCategory(key: "dosgme", name: "Другое", icon: "dosgme", hex: "#9ED3DE"),
        PresetCategory(key: "iaoceohlg", name: "Каршеринг", icon: "iaoceohlg", hex: "#F6B760"),
        PresetCategory(key: "raiph", name: "Такси", icon: "raiph", hex: "#FFC62B"),
        PresetCategory(key: "mljazl_psneokaoierh", name: "Онлайн-супермаркеты", icon: "mljazl_psneokaoierh", hex: "#F6667B"),
        PresetCategory(key: "bjagmrvmohrejslmprs", name: "Благотворительность", icon: "bjagmrvmohrejslmprs", hex: "#65CDDB"),
        PresetCategory(key: "mdeoda_h_mbsvs_mljazl", name: "Одежда и обувь онлайн", icon: "mdeoda_h_mbsvs_mljazl", hex: "#AA73F1"),
        PresetCategory(key: "derpihe_rmvaoh", name: "Детские товары", icon: "derpihe_rmvaoh", hex: "#D270FF"),
        PresetCategory(key: "mljazl_ihlmrearoh", name: "Онлайн-кинотеатры", icon: "mljazl_ihlmrearoh", hex: "#CB2AB6"),
        PresetCategory(key: "gadoerh_h_reulhia", name: "Гаджеты и техника", icon: "gadoerh_h_reulhia", hex: "#D885FF"),
        PresetCategory(key: "ialfrmvaoh", name: "Канцтовары", icon: "ialfrmvaoh", hex: "#CDA6FF"),
        PresetCategory(key: "impkerhia", name: "Косметика", icon: "impkerhia", hex: "#DD699F"),
        PresetCategory(key: "keprlhz_roalpnmor", name: "Местный транспорт", icon: "keprlhz_roalpnmor", hex: "#FFAE17"),
        PresetCategory(key: "njarlhe_dmomgh", name: "Платные дороги", icon: "njarlhe_dmomgh", hex: "#49A6E9"),
        PresetCategory(key: "nmdaoih", name: "Подарки", icon: "nmdaoih", hex: "#FAB619"),
        PresetCategory(key: "hvejholhe_hzdejhy_h_haph", name: "Ювелирные изделия и часы", icon: "hvejholhe_hzdejhy_h_haph", hex: "#9571C9"),
        PresetCategory(key: "imkhpphy", name: "Комиссия", icon: "imkhpphy", hex: "#16C2B8"),
        PresetCategory(key: "ioedhrh", name: "Кредиты", icon: "ioedhrh", hex: "#3DC4CD"),
        PresetCategory(key: "croath", name: "Штрафы", icon: "croath", hex: "#2BA9A2"),
        PresetCategory(key: "fhtomvhe_rmvaoh", name: "Цифровые товары", icon: "fhtomvhe_rmvaoh", hex: "#F395E6"),
        PresetCategory(key: "bsjmhlhe", name: "Булочные", icon: "bsjmhlhe", hex: "#EEB764"),
        PresetCategory(key: "lmraohajslhe_spjsgh", name: "Нотариальные услуги", icon: "lmraohajslhe_spjsgh", hex: "#53C099"),
        PresetCategory(key: "zaoydia_cjeiromkmbhjez", name: "Зарядка электромобилей", icon: "zaoydia_cjeiromkmbhjez", hex: "#6DB7ED"),
        PresetCategory(key: "jmreoeh", name: "Лотереи", icon: "jmreoeh", hex: "#EF7DEA"),
        PresetCategory(key: "kaoiernjezph", name: "Маркетплейсы", icon: "kaoiernjezph", hex: "#C547FF"),
        PresetCategory(key: "cimphpreka_yldeip", name: "Экосистема Яндекс", icon: "cimphpreka_yldeip", hex: "#FC3F1D"),
        PresetCategory(key: "cimphpreka_pbeo", name: "Экосистема Сбер", icon: "cimphpreka_pbeo", hex: "#21A038"),
        PresetCategory(key: "perevmz_kaoierhlg", name: "Сетевой маркетинг", icon: "perevmz_kaoierhlg", hex: "#86D2DC"),
        PresetCategory(key: "pmfperh", name: "Соцсети", icon: "pmfperh", hex: "#8796D9"),
        PresetCategory(key: "hlreoler_kagazhlh", name: "Интернет-магазины", icon: "hlreoler_kagazhlh", hex: "#993DF5"),
        PresetCategory(key: "muoala", name: "Охрана", icon: "muoala", hex: "#258E67"),
    ]

    static let income: [PresetCategory] = [
        PresetCategory(key: "pmfvhnjarh_h_nelphh", name: "Соцвыплаты и пенсии", icon: "pmfvhnjarh_h_nelphh", hex: "#3B83A4"),
        PresetCategory(key: "hlveprhfhh", name: "Инвестиции", icon: "hlveprhfhh", hex: "#48A4AA"),
        PresetCategory(key: "lajhhlhe", name: "Наличные", icon: "lajhhlhe", hex: "#4DACB2"),
        PresetCategory(key: "lim", name: "НКО", icon: "lim", hex: "#16C2B8"),
        PresetCategory(key: "spjsgh_balia", name: "Услуги банка", icon: "spjsgh_balia", hex: "#21B0B9"),
        PresetCategory(key: "nmnmjlelhy", name: "Пополнения", icon: "nmnmjlelhy", hex: "#5BD1CA"),
        PresetCategory(key: "bmlsph", name: "Бонусы", icon: "bmlsph", hex: "#87E3CE"),
        PresetCategory(key: "zaonjara", name: "Зарплата", icon: "zaonjara", hex: "#298389"),
        PresetCategory(key: "dhvhdeldh_h_isnmlh", name: "Дивиденды и купоны", icon: "dhvhdeldh_h_isnmlh", hex: "#70BCC2"),
        PresetCategory(key: "vijadh", name: "Вклады", icon: "vijadh", hex: "#3DAACD"),
        PresetCategory(key: "kerajjh", name: "Металлы", icon: "kerajjh", hex: "#987C49"),
        PresetCategory(key: "nomfelrh", name: "Проценты", icon: "nomfelrh", hex: "#5AD8BB"),
        PresetCategory(key: "kerajjh_v_pjhriau", name: "Металлы в слитках", icon: "kerajjh_v_pjhriau", hex: "#987C49"),
    ]

    static let all: [PresetCategory] = expense + income
}

extension Color {
    /// Инициализатор из hex-строки вида "#RRGGBB" (как в справочнике категорий).
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
// MARK: - Persistence

extension CategoryEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, amount, icon
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let amount = try container.decode(Double.self, forKey: .amount)
        let icon = try container.decode(String.self, forKey: .icon)
        // Цвет не храним отдельно — он однозначно определяется иконкой
        // через справочник категорий, восстанавливаем его при загрузке.
        let color = PresetCategory.all.first(where: { $0.icon == icon })?.color ?? DS.textSecondary
        self.init(id: id, name: name, amount: amount, icon: icon, color: color)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(amount, forKey: .amount)
        try container.encode(icon, forKey: .icon)
    }
}
