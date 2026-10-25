import SwiftUI
import UIKit

// MARK: - Магазины и организации
//
// Пользователь сам вписывает название магазина/организации и (по желанию)
// загружает для него иконку. Приложение запоминает пару «название → иконка +
// последняя выбранная категория». В следующий раз достаточно написать то же
// название — иконка и категория подставятся сами.
//
// Метаданные лежат в UserDefaults (маленький JSON), сами картинки — файлами
// в Documents/Merchants, чтобы не раздувать UserDefaults.

struct Merchant: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    /// Ключ иконки последней выбранной для этого магазина категории.
    var categoryIcon: String
    var hasLogo: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        categoryIcon: String,
        hasLogo: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categoryIcon = categoryIcon
        self.hasLogo = hasLogo
    }
}

enum MerchantLogoAction {
    case keep
    case set(UIImage)
    case remove
}

enum MerchantStore {
    private static let storageKey = "merchants"
    private static var cache: [Merchant]?
    private static let imageCache = NSCache<NSString, UIImage>()
    
    // MARK: Нормализация названия
    
    /// Сравнение «без регистра, ё/е, знаков препинания и лишних пробелов»:
    /// «САНТА», «Санта» и «санта!» — один и тот же магазин.
    static func normalize(_ name: String) -> String {
        let folded = name
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "ru_RU")
            )
        let characters: [Character] = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(characters)
            .split(separator: " ")
            .joined(separator: " ")
    }
    
    // MARK: Чтение
    
    static func all() -> [Merchant] {
        if let cache { return cache }
        
        let loaded: [Merchant]
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Merchant].self, from: data) {
            loaded = decoded
        } else {
            loaded = []
        }
        cache = loaded
        return loaded
    }
    
    private static func save(_ list: [Merchant]) {
        cache = list
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    /// Точное совпадение по нормализованному названию.
    static func find(_ name: String) -> Merchant? {
        let key = normalize(name)
        guard !key.isEmpty else { return nil }
        return all().first { normalize($0.name) == key }
    }
    
    /// Подсказки при вводе: сначала те, что начинаются с введённого, потом
    /// содержащие его. Точное совпадение исключено (оно и так подставится).
    /// Пустой ввод — последние добавленные магазины.
    static func suggestions(for text: String, limit: Int = 8) -> [Merchant] {
        let key = normalize(text)
        let list = all()
        
        guard !key.isEmpty else {
            return Array(list.reversed().prefix(limit))
        }
        
        let prefixMatches = list.filter {
            let n = normalize($0.name)
            return n != key && n.hasPrefix(key)
        }
        let containsMatches = list.filter {
            let n = normalize($0.name)
            return n != key && !n.hasPrefix(key) && n.contains(key)
        }
        return Array((prefixMatches + containsMatches).prefix(limit))
    }
    
    // MARK: Запись
    
    /// Создаёт или обновляет магазин. Название существующего не меняется
    /// (чтобы «санта» не затёрло красивое «Санта»), обновляются категория
    /// и — если нужно — иконка.
    @discardableResult
    static func remember(
        name: String,
        categoryIcon: String,
        logo: MerchantLogoAction
    ) -> Merchant {
        var list = all()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalize(trimmed)
        
        var merchant: Merchant
        let index = list.firstIndex { normalize($0.name) == key }
        
        if let index {
            merchant = list[index]
            merchant.categoryIcon = categoryIcon
        } else {
            merchant = Merchant(name: trimmed, categoryIcon: categoryIcon)
        }
        
        switch logo {
        case .keep:
            break
        case .set(let image):
            if writeLogo(image, for: merchant.id) {
                merchant.hasLogo = true
            }
        case .remove:
            removeLogoFile(for: merchant.id)
            merchant.hasLogo = false
        }
        imageCache.removeObject(forKey: merchant.id.uuidString as NSString)
        
        if let index {
            list[index] = merchant
        } else {
            list.append(merchant)
        }
        save(list)
        return merchant
    }
    
    // MARK: Иконки
    
    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Merchants", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private static func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).png")
    }
    
    private static func writeLogo(_ image: UIImage, for id: UUID) -> Bool {
        guard let data = image.pngData() else { return false }
        return (try? data.write(to: fileURL(for: id), options: .atomic)) != nil
    }
    
    private static func removeLogoFile(for id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }
    
    static func logo(for merchant: Merchant) -> UIImage? {
        guard merchant.hasLogo else { return nil }
        let cacheKey = merchant.id.uuidString as NSString
        
        if let cached = imageCache.object(forKey: cacheKey) { return cached }
        guard let image = UIImage(contentsOfFile: fileURL(for: merchant.id).path) else { return nil }
        
        imageCache.setObject(image, forKey: cacheKey)
        return image
    }
    
    /// Иконка по названию, записанному в операции (для строки истории).
    static func logo(forName name: String) -> UIImage? {
        guard let merchant = find(name) else { return nil }
        return logo(for: merchant)
    }
}

extension UIImage {
    /// Квадратная обрезка по центру и уменьшение — иконки хранятся маленькими.
    func squareLogo(side: CGFloat = 160) -> UIImage {
        let shortest = min(size.width, size.height)
        guard shortest > 0 else { return self }
        
        let scale = side / shortest
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(
            x: (side - drawSize.width) / 2,
            y: (side - drawSize.height) / 2
        )
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        )
        return renderer.image { _ in
            draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
