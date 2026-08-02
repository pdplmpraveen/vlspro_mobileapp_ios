import SwiftUI

struct PropertiesView: View {
    @EnvironmentObject var data: DataService

    var body: some View {
        Group {
            if data.propertiesLoading && data.properties.isEmpty {
                ProgressView("Loading properties…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if data.properties.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.2").font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No properties found").foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        // Summary strip
                        HStack(spacing: 0) {
                            PropertySummaryPill(
                                value: "\(data.properties.count)",
                                label: "Properties",
                                color: Color(hex: "2E6DB4")
                            )
                            Divider().frame(height: 40)
                            PropertySummaryPill(
                                value: "\(data.properties.reduce(0) { $0 + $1.total_units })",
                                label: "Total Units",
                                color: Color(hex: "1A3A6B")
                            )
                            Divider().frame(height: 40)
                            PropertySummaryPill(
                                value: "\(data.properties.reduce(0) { $0 + $1.occupied_units })",
                                label: "Occupied",
                                color: Color(hex: "27AE60")
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                        .padding(.horizontal)
                        .padding(.top, 8)

                        ForEach(data.properties) { property in
                            PropertyCard(property: property)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Properties")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { data.loadProperties() }
        .refreshable { data.loadProperties() }
    }
}

struct PropertyCard: View {
    let property: Property

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "2E6DB4").opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: property.typeIcon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "2E6DB4"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(property.name)
                        .font(.subheadline.weight(.semibold))
                    if !property.locationLabel.isEmpty {
                        Label(property.locationLabel, systemImage: "mappin.circle")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(property.property_type.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color(hex: "2E6DB4"))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(hex: "2E6DB4").opacity(0.1))
                    .cornerRadius(8)
            }

            Divider()

            // Stats row
            HStack(spacing: 0) {
                PropertyStatCell(value: "\(property.total_units)", label: "Units", color: .primary)
                Divider().frame(height: 36)
                PropertyStatCell(value: "\(property.occupied_units)", label: "Occupied", color: Color(hex: "27AE60"))
                Divider().frame(height: 36)
                PropertyStatCell(value: "\(property.vacant_units)", label: "Vacant",
                                 color: property.vacant_units > 0 ? Color(hex: "E67E22") : Color(hex: "27AE60"))
                Divider().frame(height: 36)
                // Occupancy bar
                VStack(spacing: 4) {
                    Text("\(Int(property.occupancyRate * 100))%")
                        .font(.subheadline.bold())
                    Text("Occupancy").font(.caption2).foregroundColor(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color(.systemGray5)).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(occupancyColor(property.occupancyRate))
                                .frame(width: geo.size.width * CGFloat(property.occupancyRate), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    func occupancyColor(_ rate: Double) -> Color {
        if rate >= 0.9 { return Color(hex: "27AE60") }
        if rate >= 0.7 { return Color(hex: "E67E22") }
        return Color(hex: "E74C3C")
    }
}

struct PropertyStatCell: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.bold()).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PropertySummaryPill: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
    }
}

#Preview {
    NavigationStack { PropertiesView().environmentObject(DataService.shared) }
}
