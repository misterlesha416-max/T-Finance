import SwiftUI

// MARK: - Models

private struct PaymentCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
}

private struct QuickContact: Identifiable {
    let id = UUID()
    let initials: String
    let name: String
    let color: Color
}

private struct PaymentTemplate: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
}

// MARK: - PaymentsView

struct PaymentsView: View {
    
    @State private var searchText = ""
    
    private let categories: [PaymentCategory] = [
        PaymentCategory(title: "Телефон", icon: "phone.fill", tint: .blue),
        PaymentCategory(title: "ЖКХ и дом", icon: "house.fill", tint: .orange),
        PaymentCategory(title: "Интернет и ТВ", icon: "wifi", tint: .purple),
        PaymentCategory(title: "Транспорт", icon: "car.fill", tint: .green),
        PaymentCategory(title: "Госуслуги", icon: "building.columns.fill", tint: .red),
        PaymentCategory(title: "Одежда", icon: "tshirt.fill", tint: .pink),
        PaymentCategory(title: "Развлечения", icon: "gamecontroller.fill", tint: .yellow),
        PaymentCategory(title: "Ещё", icon: "square.grid.2x2.fill", tint: .gray)
    ]
    
    private let contacts: [QuickContact] = [
        QuickContact(initials: "МК", name: "Мама", color: .pink),
        QuickContact(initials: "ДС", name: "Денис", color: .blue),
        QuickContact(initials: "ОП", name: "Оля", color: .green),
        QuickContact(initials: "ИТ", name: "Игорь", color: .orange),
        QuickContact(initials: "+", name: "Ещё", color: Color.white.opacity(0.12))
    ]
    
    private let templates: [PaymentTemplate] = [
        PaymentTemplate(icon: "bolt.fill", tint: .yellow, title: "Мосэнергосбыт", subtitle: "Электроэнергия"),
        PaymentTemplate(icon: "drop.fill", tint: .blue, title: "Мосводоканал", subtitle: "Вода"),
        PaymentTemplate(icon: "wifi", tint: .purple, title: "Ростелеком", subtitle: "Интернет и ТВ")
    ]
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        
        ScrollView(showsIndicators: false) {
            
            VStack(spacing: 0) {
                
                header
                    .padding(.top, 22)
                
                searchField
                    .padding(.top, 16)
                
                quickContacts
                    .padding(.top, 22)
                
                sectionLabel("Платежи и переводы")
                    .padding(.top, 26)
                
                categoriesGrid
                    .padding(.top, 12)
                
                sectionLabel("Шаблоны")
                    .padding(.top, 26)
                
                templatesGroup
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                
                Spacer()
                    .frame(height: 104)
            }
        }
    }
    
    // MARK: Header
    
    private var header: some View {
        
        HStack {
            
            Text("Платежи")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white)
            
            Spacer()
            
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 34, height: 34)
                .overlay {
                    
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: Search
    
    private var searchField: some View {
        
        HStack(spacing: 9) {
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color.white.opacity(0.50))
            
            ZStack(alignment: .leading) {
                
                if searchText.isEmpty {
                    
                    Text("Поиск по услугам и организациям")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.50))
                }
                
                TextField("", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color(red: 0.105, green: 0.105, blue: 0.115))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    // MARK: Quick contacts
    
    private var quickContacts: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            
            HStack(spacing: 16) {
                
                ForEach(contacts) { contact in
                    
                    VStack(spacing: 6) {
                        
                        Circle()
                            .fill(contact.color)
                            .frame(width: 52, height: 52)
                            .overlay {
                                
                                Text(contact.initials)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        
                        Text(contact.name)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .frame(width: 60)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: Categories grid
    
    private var categoriesGrid: some View {
        
        LazyVGrid(columns: columns, spacing: 14) {
            
            ForEach(categories) { category in
                
                VStack(spacing: 8) {
                    
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(category.tint.opacity(0.18))
                        .frame(width: 52, height: 52)
                        .overlay {
                            
                            Image(systemName: category.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(category.tint)
                        }
                    
                    Text(category.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 28)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: Templates
    
    private var templatesGroup: some View {
        
        VStack(spacing: 0) {
            
            ForEach(templates) { template in
                
                templateRow(template)
                
                if template.id != templates.last?.id {
                    
                    Divider()
                        .background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func templateRow(_ template: PaymentTemplate) -> some View {
        
        HStack(spacing: 10) {
            
            Image(systemName: template.icon)
                .font(.system(size: 16))
                .foregroundStyle(template.tint)
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                
                Text(template.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                
                Text(template.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
    
    // MARK: Section label
    
    private func sectionLabel(_ text: String) -> some View {
        
        HStack {
            
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PaymentsView()
    }
    .preferredColorScheme(.dark)
}
