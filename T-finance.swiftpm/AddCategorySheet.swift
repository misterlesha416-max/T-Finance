import SwiftUI

struct AddCategorySheet: View {
    let isIncome: Bool
    let onAdd: (CategoryEntry) -> Void
    let onClose: () -> Void

    private var presetList: [PresetCategory] {
        isIncome ? PresetCategory.income : PresetCategory.expense
    }

    @State private var selected: PresetCategory
    @State private var amountText: String = ""
    @State private var searchText: String = ""

    init(isIncome: Bool = false, onAdd: @escaping (CategoryEntry) -> Void, onClose: @escaping () -> Void) {
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
            searchField
            ScrollView {
                categoryGrid
                    .padding(.bottom, 24)
            }
        }
        .background(Color(red: 0.105, green: 0.105, blue: 0.115))
        .preferredColorScheme(.dark)
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
                onAdd(
                    CategoryEntry(
                        name: selected.name,
                        amount: amount,
                        icon: selected.icon,
                        color: selected.color
                    )
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
