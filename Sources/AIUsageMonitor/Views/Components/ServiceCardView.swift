import SwiftUI

struct ServiceCardView: View {
    let service: ServiceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Service Header
            HStack {
                Image(systemName: service.iconName)
                    .font(.title2)
                    .foregroundStyle(service.brandColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.headline)

                    Text(service.tier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusIndicator(status: service.status)
            }

            // Usage Bar
            UsageBarView(
                current: service.tokensUsed,
                limit: service.tokensLimit,
                percentage: service.usagePercentage
            )

            // Usage Details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(service.formattedTokensUsed)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Limit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(service.formattedTokensLimit)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Cost View
            if let cost = service.currentCost {
                Divider()

                CostView(
                    current: cost,
                    projected: service.projectedCost,
                    currency: service.currency
                )
            }

            // Reset Date
            if let resetDate = service.resetDate {
                Text("Resets \(resetDate, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StatusIndicator: View {
    let status: ServiceStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
    }
}

struct CostView: View {
    let current: Decimal
    let projected: Decimal?
    let currency: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Cost")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(formatCurrency(current))
                    .font(.callout)
                    .fontWeight(.semibold)
            }

            Spacer()

            if let projected = projected {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Projected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(formatCurrency(projected))
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSNumber) ?? "$0.00"
    }
}

