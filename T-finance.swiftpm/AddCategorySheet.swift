import SwiftUI
import PhotosUI

struct AddCategorySheet: View {
    let isIncome: Bool
    /// Второй параметр — название магазина/организации (nil, если не вписано).
    let onAdd: (CategoryEntry, String?) -> Void
    let onClose: () -> Void

    private var presetList: [PresetCategory] {
        isIncome ? PresetCategory.income : PresetCategory.expense
    }

    @State private var selected: PresetCategory
    @State private var amountText: String = ""
    @State private var searchText: String = ""

    // Магазин / организация
    @State private var merchantName: String = ""
    @State private var logoImage: UIImage?
    @State private var logoAction: MerchantLogoAction = .keep
    @State private var matchedMerchantID: UUID?
    @State private var photoItem: PhotosPickerItem?

    init(isIncome: Bool = false, onAdd: @escaping (CategoryEntry, String?) -> Void, onClose: @escaping () -> Void) {
        self.isIncome = isIncome
        self.onAdd = onAdd
        self.onClose = onClose
        let list = isIncome ? PresetCategory.income : PresetCategory.expense
        _selected = State(initialValue: list.first!)
    }

    private var filteredCategories: [PresetCategory] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return presetList }
        return presetList.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var parsedAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            amountField
            merchantField
            searchField
            ScrollView {
                categoryGrid
                    .padding(.bottom, 24)
            }
        }
        .background(Color(red: 0.105, green: 0.105, blue: 0.115))
        .preferredColorScheme(.dark)
        .onChange(of: merchantName) { _, _ in
            applyMatchedMerchant()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let square = image.squareLogo()
                    await MainActor.run {
                        logoImage = square
                        logoAction = .set(square)
                    }
                }
                await MainActor.run { photoItem = nil }
            }
        }
    }

    // MARK: - Магазин / организация

    /// Если введённое название совпало с сохранённым магазином — подставляем
    /// его иконку и последнюю выбранную для него категорию. Иконку, которую
    /// пользователь только что выбрал сам, не трогаем.
    private func applyMatchedMerchant() {
        if let match = MerchantStore.find(merchantName) {
            guard matchedMerchantID != match.id else { return }
            matchedMerchantID = match.id

            if let preset = presetList.first(where: { $0.icon == match.categoryIcon }) {
                selected = preset
            }
            if case .keep = logoAction {
                logoImage = MerchantStore.logo(for: match)
            }
        } else if matchedMerchantID != nil {
            matchedMerchantID = nil
            if case .keep = logoAction {
                logoImage = nil
            }
        }
    }

    private var merchantSuggestions: [Merchant] {
        MerchantStore.suggestions(for: merchantName)
    }

    private var logoPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let logoImage {
                    Image(uiImage: logoImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(selected.color)
                            .frame(width: 44, height: 44)

                        Image(selected.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                    }
                }
            }

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.blue)
                .offset(x: 4, y: 4)
        }
        .frame(width: 48, height: 48)
    }

    private var merchantField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    logoPreview
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Магазин или организация")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.secondary)

                    TextField("Например, Санта", text: $merchantName)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                }

                if logoImage != nil {
                    Button {
                        logoImage = nil
                        logoAction = .remove
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !merchantSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(merchantSuggestions) { merchant in
                            suggestionChip(merchant)
                        }
                    }
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    private func suggestionChip(_ merchant: Merchant) -> some View {
        Button {
            // Сбрасываем «ручной» выбор иконки: берём сохранённую.
            logoAction = .keep
            matchedMerchantID = nil
            merchantName = merchant.name
        } label: {
            HStack(spacing: 6) {
                if let logo = MerchantStore.logo(for: merchant) {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                }

                Text(merchant.name)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Сохраняет магазин (если название вписано) и возвращает каноничное
    /// название — для уже известного магазина это написание, которое
    /// было сохранено в первый раз.
    private func commitMerchant() -> String? {
        let trimmed = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return MerchantStore.remember(
            name: trimmed,
            categoryIcon: selected.icon,
            logo: logoAction
        ).name
    }

    private var header: some View {
        HStack {
            Button("Закрыть", action: onClose)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Color.blue)

            Spacer()

            Text("Добавить категорию")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white)

            Spacer()

            Button("Готово") {
                guard let amount = parsedAmount else { return }
                let merchant = commitMerchant()
                onAdd(
                    CategoryEntry(
                        name: selected.name,
                        amount: amount,
                        icon: selected.icon,
                        color: selected.color
                    ),
                    merchant
                )
            }
            .font(.system(size: 17, weight: .light))
            .foregroundStyle(Color.blue)
            .disabled(parsedAmount == nil)
        }
        .padding(.horizontal, 12)
        .frame(height: 68)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Сумма")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(.secondary)

            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
                .padding(.top, 8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)

            TextField("Поиск категории", text: $searchText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }

    private var categoryGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 84), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredCategories) { category in
                categoryButton(category)
            }
        }
        .padding(.horizontal, 12)
    }

    private func categoryButton(_ category: PresetCategory) -> some View {
        let isSelected = selected == category

        return Button {
            selected = category
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(isSelected ? 1 : 0.35))
                        .frame(width: 44, height: 44)

                    Image(category.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                }

                Text(category.name)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 84, height: 84)
            .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
