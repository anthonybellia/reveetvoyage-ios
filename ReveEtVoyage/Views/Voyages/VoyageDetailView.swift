import SwiftUI

struct VoyageDetailView: View {
    @StateObject private var viewModel: VoyageDetailViewModel
    @State private var celebrate: Bool = false
    @State private var confettiBurst: Int = 0

    init(voyageId: Int) {
        _viewModel = StateObject(wrappedValue: VoyageDetailViewModel(voyageId: voyageId))
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if viewModel.isLoading && viewModel.voyage == nil {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.voyage == nil {
                ErrorView(message: error) { Task { await viewModel.load() } }
            } else if let voyage = viewModel.voyage {
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard(voyage: voyage)
                        progressCard(voyage: voyage)
                        timelineSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .refreshable { await viewModel.load() }
            }

            if celebrate {
                CelebrationOverlay(burst: confettiBurst)
                    .allowsHitTesting(false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let voyage = viewModel.voyage {
                    Text(voyage.reference)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.revBrown)
                }
            }
        }
        .task { await viewModel.load() }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.revYellow.opacity(0.10), Color.revBackground],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private func headerCard(voyage: Voyage) -> some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(voyage.titre)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 13))
                            Text(voyage.destination)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.revTextSecondary)
                    }
                    Spacer()
                    StatusBadge.voyageStatut(voyage.statut, label: voyage.statut_label)
                }

                if voyage.date_depart != nil || voyage.date_retour != nil {
                    HStack(spacing: 18) {
                        dateChip(label: "Départ", iso: voyage.date_depart, icon: "airplane.departure")
                        dateChip(label: "Retour", iso: voyage.date_retour, icon: "airplane.arrival")
                    }
                }

                if voyage.montant_total > 0 {
                    HStack(spacing: 10) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.revOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatPrice(voyage.montant_paye) + " / " + formatPrice(voyage.montant_total))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.revText)
                            Text("Acompte : \(formatPrice(voyage.montant_acompte))")
                                .font(.system(size: 11))
                                .foregroundColor(.revTextSecondary)
                        }
                    }
                }
            }
        }
    }

    private func dateChip(label: String, iso: String?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.revOrange)

            Text(iso?.toDate()?.formatted(style: .medium) ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.revText)
        }
    }

    private func formatPrice(_ amount: Double) -> String {
        String(format: "€%.0f", amount)
    }

    // MARK: - Progress

    private func progressCard(voyage: Voyage) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Progression du planning")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                    Spacer()
                    Text("\(viewModel.completedCount) / \(viewModel.totalCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.revOrange)
                }

                ProgressBar(value: viewModel.progressPercent)
                    .frame(height: 10)
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Étapes du voyage", systemImage: "list.bullet.rectangle")
                .padding(.horizontal, 4)

            if viewModel.etapes.isEmpty {
                GlassCard {
                    Text("Aucune étape n'a été ajoutée à ce voyage.")
                        .font(.system(size: 14))
                        .foregroundColor(.revTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            } else {
                ForEach(Array(viewModel.etapes.enumerated()), id: \.element.id) { index, etape in
                    EtapeRow(
                        etape: etape,
                        isFirst: index == 0,
                        isLast: index == viewModel.etapes.count - 1,
                        isToggling: viewModel.togglingEtapeIds.contains(etape.id),
                        onToggle: { handleToggle(etape) }
                    )
                }
            }
        }
    }

    private func handleToggle(_ etape: VoyageEtape) {
        let willComplete = !etape.is_completed
        Task { await viewModel.toggleEtape(etape) }

        if willComplete {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            confettiBurst += 1
            withAnimation { celebrate = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { celebrate = false }
            }
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

// MARK: - Étape row

struct EtapeRow: View {
    let etape: VoyageEtape
    let isFirst: Bool
    let isLast: Bool
    let isToggling: Bool
    let onToggle: () -> Void

    @State private var checkBounce: CGFloat = 1

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Color.revOrange.opacity(0.3))
                    .frame(width: 2, height: 14)

                checkBubble

                Rectangle()
                    .fill(isLast ? Color.clear : Color.revOrange.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 30)

            etapeContent
                .padding(.bottom, isLast ? 0 : 12)
        }
    }

    private var checkBubble: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                checkBounce = 1.4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    checkBounce = 1
                }
            }
            onToggle()
        }) {
            ZStack {
                Circle()
                    .fill(etape.is_completed
                          ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.revCardBackground))
                    .overlay(
                        Circle()
                            .strokeBorder(etape.is_completed ? Color.clear : Color.revOrange.opacity(0.5),
                                          lineWidth: 2)
                    )
                    .frame(width: 30, height: 30)

                if isToggling {
                    ProgressView()
                        .tint(etape.is_completed ? .white : .revOrange)
                        .scaleEffect(0.6)
                } else if etape.is_completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: stepIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.revOrange)
                }
            }
            .scaleEffect(checkBounce)
            .shadow(color: etape.is_completed ? Color.revOrange.opacity(0.4) : .clear,
                    radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
    }

    private var stepIcon: String {
        switch etape.type {
        case "vol", "vol_aller", "vol_retour": return "airplane"
        case "hotel": return "bed.double.fill"
        case "activite": return "figure.walk"
        case "transfert": return "car.fill"
        case "restaurant": return "fork.knife"
        case "note": return "note.text"
        case "document": return "doc.fill"
        default: return "circle.fill"
        }
    }

    private var etapeContent: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(etape.titre)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(etape.is_completed ? .revTextSecondary : .revText)
                            .strikethrough(etape.is_completed)

                        if let lieu = etape.lieu, !lieu.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 10))
                                Text(lieu)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.revTextSecondary)
                        }
                    }

                    Spacer()

                    if let date = etape.date?.toDate() {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_BE"))))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.revOrange)
                            if let heure = etape.heure {
                                Text(heure)
                                    .font(.system(size: 10))
                                    .foregroundColor(.revTextSecondary)
                            }
                        }
                    }
                }

                if let description = etape.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                        .lineLimit(3)
                }

                if let cout = etape.cout, cout > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "eurosign.circle.fill")
                            .font(.system(size: 11))
                        Text(String(format: "%.0f €", cout))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.revOrange)
                }
            }
        }
        .opacity(etape.is_completed ? 0.75 : 1)
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    let value: Double  // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.15))

                Capsule()
                    .fill(LinearGradient(colors: [.revYellow, .revOrange, .revRed],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geo.size.width * CGFloat(value)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
            }
        }
    }
}

// MARK: - Funny celebration overlay

struct CelebrationOverlay: View {
    let burst: Int
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
        var rotation: Double
        var scale: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Image(systemName: ["star.fill", "heart.fill", "sparkles", "airplane"].randomElement()!)
                    .font(.system(size: 22))
                    .foregroundColor(p.color)
                    .rotationEffect(.degrees(p.rotation))
                    .scaleEffect(p.scale)
                    .position(x: p.x, y: p.y)
            }
        }
        .ignoresSafeArea()
        .onChange(of: burst) { _ in spawn() }
        .onAppear { spawn() }
    }

    private func spawn() {
        let screen = UIScreen.main.bounds
        particles = (0..<18).map { _ in
            Particle(
                x: screen.width / 2 + CGFloat.random(in: -30...30),
                y: screen.height / 2,
                color: [.revYellow, .revOrange, .revRed].randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: 0.4
            )
        }

        for i in particles.indices {
            let dx = CGFloat.random(in: -180...180)
            let dy = CGFloat.random(in: -300 ... -80)
            withAnimation(.easeOut(duration: 1.1)) {
                particles[i].x += dx
                particles[i].y += dy
                particles[i].rotation += Double.random(in: 180...720)
                particles[i].scale = CGFloat.random(in: 0.8...1.4)
            }
        }
    }
}
