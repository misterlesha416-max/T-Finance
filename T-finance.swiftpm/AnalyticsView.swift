import SwiftUI
import Charts

// MARK: - Models

private struct SpendingCategory: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let color: Color
    let icon: String
}

private struct MonthSpending: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
}

// MARK: - AnalyticsView

struct AnalyticsView: View {
    
    @State private var selectedMonthIndex = 3
    
    private let months = ["Май", "Июнь", "Июль", "Август"]
    
    private let categories: [SpendingCategory] = [
        SpendingCategory(title: "Продукты", amount: 12400, color: .green, icon: "cart.fill"),
        SpendingCategory(title: "Кафе и рестораны", amount: 8600, color: .orange, icon: "fork.knife"),
        SpendingCategory(title: "Транспорт", amount: 4200, color: .blue, icon: "car.fill"),
        SpendingCategory(title: "Развлечения", amount: 3100, color: .purple, icon: "gamecontroller.fill"),
        SpendingCategory(title: "Связь", amount: 1200, color: .pink, icon: "phone.fill")
    ]
    
    private let history: [MonthSpending] = [
        MonthSpending(month: "Апр", amount: 24100),
        MonthSpending(month: "Май", amount: 27300),
        MonthSpending(month: "Июн", amount: 21800),
        MonthSpending(month: "Июл", amount: 25600),
        MonthSpending(month: "Авг", amount: 29500)
    ]
    
    private var totalSpent: Double {
        categories.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        
        ScrollView(showsIndicators: false) {
            
            VStack(spacing: 0) {
                
                header
                    .padding(.top, 22)
                
                monthSelector
                    .padding(.top, 18)
                
                totalCard
                    .padding(.top, 18)
                
                donutSection
                    .padding(.top, 26)
                
                sectionLabel("По категориям")
                    .padding(.top, 26)
                
                categoriesList
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                
                sectionLabel("Динамика трат")
                    .padding(.top, 26)
                
                historyChart
                    .padding(.top, 14)
                    .padding(.horizontal, 16)
                
                Spacer()
                    .frame(height: 104)
            }
        }
    }
    
    // MARK: Header
    
    private var header: some View {
        
        HStack {
            
            Text("Аналитика")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: Month selector
    
    private var monthSelector: some View {
        
        HStack {
            
            Button {
                
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedMonthIndex = max(0, selectedMonthIndex - 1)
                }
                
            } label: {
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(selectedMonthIndex == 0)
            
            Spacer()
            
            Text("\(months[selectedMonthIndex]) 2026")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedMonthIndex = min(months.count - 1, selectedMonthIndex + 1)
                }
                
            } label: {
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(selectedMonthIndex == months.count - 1)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: Total card
    
    private var totalCard: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            Text("Расходы за месяц")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                
                Text(formatted(totalSpent))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 3) {
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                    
                    Text("12% к июлю")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Color(red: 0.110, green: 0.110, blue: 0.118))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    // MARK: Donut chart
    
    private var donutSection: some View {
        
        Chart(categories) { category in
            
            SectorMark(
                angle: .value("Сумма", category.amount),
                innerRadius: .ratio(0.68),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(category.color)
        }
        .frame(height: 200)
        .overlay {
            
            VStack(spacing: 4) {
                
                Text("Всего")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text(formatted(totalSpent))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: Categories list
    
    private var categoriesList: some View {
        
        VStack(spacing: 0) {
            
            ForEach(categories) { category in
                
                categoryRow(category)
                
                if category.id != categories.last?.id {
                    
                    Divider()
                        .background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func categoryRow(_ category: SpendingCategory) -> some View {
        
        let percent = totalSpent > 0 ? category.amount / totalSpent : 0
        
        return HStack(spacing: 12) {
            
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(category.color.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay {
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(category.color)
                }
            
            VStack(alignment: .leading, spacing: 6) {
                
                HStack {
                    
                    Text(category.title)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(formatted(category.amount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                GeometryReader { geometry in
                    
                    ZStack(alignment: .leading) {
                        
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        
                        Capsule()
                            .fill(category.color)
                            .frame(width: geometry.size.width * percent)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
    }
    
    // MARK: History chart
    
    private var historyChart: some View {
        
        Chart(history) { item in
            
            BarMark(
                x: .value("Месяц", item.month),
                y: .value("Сумма", item.amount)
            )
            .foregroundStyle(
                item.id == history.last?.id
                ? Color.blue
                : Color.white.opacity(0.16)
            )
            .cornerRadius(6)
        }
        .frame(height: 140)
        .chartYAxis(.hidden)
        .chartXAxis {
            
            AxisMarks { _ in
                
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: Formatting
    
    private func formatted(_ value: Double) -> String {
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        
        return "\(number) \(currencySymbol)"
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
        AnalyticsView()
    }
    .preferredColorScheme(.dark)
}
