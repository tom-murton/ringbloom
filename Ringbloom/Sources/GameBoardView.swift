import SwiftUI

struct BindweedSpreadPreview: Equatable {
    let source: Int
    let destination: Int
}

/// Converts a drag around the flower into the ring and direction a player
/// intended. Direction follows the local tangent, so clockwise feels correct
/// at the top, sides, and bottom of the board.
enum BoardGestureInterpreter {
    static func ring(at point: CGPoint, center: CGPoint, side: CGFloat) -> Ring {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < side * 0.23 {
            return .inner
        }
        if distance < side * 0.35 {
            return .middle
        }
        return .outer
    }

    static func direction(
        from start: CGPoint,
        to end: CGPoint,
        around center: CGPoint,
        minimumTangentialDistance: CGFloat = 18
    ) -> RotationDirection? {
        let radialX = start.x - center.x
        let radialY = start.y - center.y
        let radius = sqrt(radialX * radialX + radialY * radialY)
        guard radius > 1 else { return nil }

        let translationX = end.x - start.x
        let translationY = end.y - start.y
        let normalizedX = radialX / radius
        let normalizedY = radialY / radius

        // In screen coordinates positive y points down. Rotating the radial
        // vector 90° this way gives the local clockwise tangent.
        let clockwiseTangentX = -normalizedY
        let clockwiseTangentY = normalizedX
        let tangentialDistance = translationX * clockwiseTangentX
            + translationY * clockwiseTangentY
        let radialDistance = translationX * normalizedX
            + translationY * normalizedY

        guard abs(tangentialDistance) >= minimumTangentialDistance else { return nil }
        guard abs(tangentialDistance) >= abs(radialDistance) * 0.65 else { return nil }
        return tangentialDistance > 0 ? .clockwise : .counterClockwise
    }
}

struct GameBoardView: View {
    let board: GameBoard
    let selectedRing: Ring
    let bloomSpokes: [Int]
    let bloomToken: Int
    let rotatingRing: Ring?
    let rotationDegrees: Double
    let hintMove: GameMove?
    let infectedSpokes: Set<Int>
    let bindweedSpreadPreview: BindweedSpreadPreview?
    let interactionEnabled: Bool
    let onSelect: (Ring) -> Void
    let onRotate: (RotationDirection) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Circle()
                    .fill(RingbloomTheme.ink.opacity(0.46))
                    .frame(width: side * 0.94, height: side * 0.94)
                    .overlay {
                        Circle()
                            .stroke(RingbloomTheme.ivory.opacity(0.08), lineWidth: 1)
                    }

                ForEach(infectedSpokes.sorted(), id: \.self) { spoke in
                    bindweedStem(spoke: spoke, side: side)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.25).combined(with: .opacity)
                        )
                }

                if let bindweedSpreadPreview {
                    spreadPreview(bindweedSpreadPreview, center: center, side: side)
                }

                ForEach(Ring.allCases) { ring in
                    ringLayer(
                        for: ring,
                        size: proxy.size,
                        center: center,
                        side: side
                    )
                }

                centerBloom(side: side)

                if !bloomSpokes.isEmpty {
                    BloomBurst(spokes: bloomSpokes, side: side)
                        .id(bloomToken)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Circle())
            .gesture(boardSwipe(side: side, center: center))
            .animation(
                reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.62),
                value: infectedSpokes
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(interactionEnabled)
        .accessibilityRepresentation {
            VStack {
                Text(boardAccessibilitySummary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(0 ..< GameBoard.slotsPerRing, id: \.self) { slot in
                    Text(accessibilitySpokeDescription(slot))
                        .accessibilityIdentifier("boardSpoke\(slot)")
                }
            }
            .accessibilityHint("Use the ring and turn controls after the board to make a move.")
        }
        .accessibilityIdentifier("gameBoard")
    }

    private func spreadPreview(
        _ preview: BindweedSpreadPreview,
        center: CGPoint,
        side: CGFloat
    ) -> some View {
        let radius = side * 0.405
        let sourceAngle = slotAngle(preview.source)
        let destinationAngle = slotAngle(preview.destination)
        let source = CGPoint(
            x: center.x + cos(sourceAngle) * radius,
            y: center.y + sin(sourceAngle) * radius
        )
        let destination = CGPoint(
            x: center.x + cos(destinationAngle) * radius,
            y: center.y + sin(destinationAngle) * radius
        )
        return Path { path in
            path.move(to: source)
            path.addQuadCurve(to: destination, control: center)
        }
        .stroke(
            RingbloomTheme.mint.opacity(0.78),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 7])
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ringLayer(
        for ring: Ring,
        size: CGSize,
        center: CGPoint,
        side: CGFloat
    ) -> some View {
        ZStack {
            guideRing(
                for: ring,
                side: side,
                isHinted: hintMove?.ring == ring
            )

            ForEach(0 ..< GameBoard.slotsPerRing, id: \.self) { slot in
                petal(
                    kind: board[ring, slot],
                    ring: ring,
                    slot: slot,
                    center: center,
                    side: side
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(
            .degrees(rotatingRing == ring && !reduceMotion ? rotationDegrees : 0)
        )
    }

    private func guideRing(for ring: Ring, side: CGFloat, isHinted: Bool) -> some View {
        let radius = ringRadius(ring, side: side)
        let isSelected = ring == selectedRing
        let strokeColor = isHinted
            ? RingbloomTheme.saffron.opacity(0.9)
            : (isSelected ? RingbloomTheme.ivory.opacity(0.42) : RingbloomTheme.ivory.opacity(0.09))

        return Circle()
            .stroke(
                strokeColor,
                style: StrokeStyle(
                    lineWidth: isHinted ? 4 : (isSelected ? 3 : 1),
                    dash: isHinted || isSelected ? [] : [2, 7]
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .shadow(
                color: isHinted
                    ? RingbloomTheme.saffron.opacity(0.52)
                    : (isSelected ? RingbloomTheme.saffron.opacity(0.2) : .clear),
                radius: isHinted ? 12 : 8
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selectedRing)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isHinted)
    }

    private func petal(
        kind: PetalKind,
        ring: Ring,
        slot: Int,
        center: CGPoint,
        side: CGFloat
    ) -> some View {
        let angle = slotAngle(slot)
        let radius = ringRadius(ring, side: side)
        let dimensions = petalDimensions(ring, side: side)
        let position = CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
        let degrees = Angle.radians(angle).degrees + 90
        let isSelected = ring == selectedRing
        let isBlooming = bloomSpokes.contains(slot)

        return ZStack {
            PetalShape()
                .fill(
                    LinearGradient(
                        colors: [kind.color.opacity(0.98), kind.color.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    PetalShape()
                        .stroke(
                            isBlooming
                                ? RingbloomTheme.ivory
                                : RingbloomTheme.ivory.opacity(isSelected ? 0.5 : 0.2),
                            lineWidth: isBlooming ? 3 : (isSelected ? 1.5 : 1)
                        )
                }
                .rotationEffect(.degrees(degrees))

            Text(kind.glyph)
                .font(.system(size: dimensions.width * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(RingbloomTheme.ink.opacity(0.82))
        }
        .frame(width: dimensions.width, height: dimensions.height)
        .position(position)
        .scaleEffect(isBlooming && !reduceMotion ? 1.18 : 1)
        .brightness(isBlooming ? 0.12 : 0)
        .shadow(
            color: isBlooming
                ? RingbloomTheme.ivory.opacity(0.8)
                : kind.color.opacity(isSelected ? 0.42 : 0.18),
            radius: isBlooming ? 16 : (isSelected ? 8 : 3)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect(ring) }
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.26, dampingFraction: 0.58),
            value: bloomToken
        )
        .accessibilityHidden(true)
    }

    private func centerBloom(side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RingbloomTheme.ivory.opacity(hintMove == nil ? 0.08 : 0.16))
                .frame(width: side * 0.13, height: side * 0.13)

            Image(
                systemName: hintMove.map {
                    $0.direction == .clockwise ? "arrow.clockwise" : "arrow.counterclockwise"
                } ?? "sparkles"
            )
            .font(.system(size: side * 0.05, weight: .semibold))
            .foregroundStyle(hintMove == nil ? RingbloomTheme.ivory : RingbloomTheme.saffron)
        }
        .shadow(
            color: hintMove == nil
                ? RingbloomTheme.saffron.opacity(0.34)
                : RingbloomTheme.saffron.opacity(0.7),
            radius: hintMove == nil ? 12 : 18
        )
        .accessibilityHidden(true)
    }

    private func bindweedStem(spoke: Int, side: CGFloat) -> some View {
        let angle = Double(spoke) * 45 - 90
        let length = side * 0.43

        return ZStack {
            Capsule()
                .fill(RingbloomTheme.ink.opacity(0.84))
                .frame(width: length, height: 13)
                .overlay {
                    Capsule()
                        .stroke(
                            RingbloomTheme.mint.opacity(0.94),
                            style: StrokeStyle(lineWidth: 3, dash: [5, 4])
                        )
                }
                .offset(x: length / 2)

            Image(systemName: "leaf.fill")
                .font(.system(size: side * 0.045, weight: .bold))
                .foregroundStyle(RingbloomTheme.ivory)
                .padding(5)
                .background(Circle().fill(RingbloomTheme.ink))
                .offset(x: length)
        }
        .rotationEffect(.degrees(angle))
        .shadow(color: RingbloomTheme.mint.opacity(0.65), radius: 7)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func boardSwipe(side: CGFloat, center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                guard interactionEnabled else { return }
                guard let direction = BoardGestureInterpreter.direction(
                    from: value.startLocation,
                    to: value.location,
                    around: center
                ) else { return }

                let ring = BoardGestureInterpreter.ring(
                    at: value.startLocation,
                    center: center,
                    side: side
                )
                onSelect(ring)
                onRotate(direction)
            }
    }

    private func ringRadius(_ ring: Ring, side: CGFloat) -> CGFloat {
        switch ring {
        case .inner: side * 0.165
        case .middle: side * 0.285
        case .outer: side * 0.405
        }
    }

    private func petalDimensions(_ ring: Ring, side: CGFloat) -> CGSize {
        switch ring {
        case .inner: CGSize(width: side * 0.078, height: side * 0.125)
        case .middle: CGSize(width: side * 0.09, height: side * 0.14)
        case .outer: CGSize(width: side * 0.102, height: side * 0.155)
        }
    }

    private func slotAngle(_ slot: Int) -> CGFloat {
        -.pi / 2 + CGFloat(slot) * (2 * .pi / CGFloat(GameBoard.slotsPerRing))
    }

    private func accessibilitySpokeDescription(_ slot: Int) -> String {
        let positions = [
            "12 o'clock", "1:30", "3 o'clock", "4:30",
            "6 o'clock", "7:30", "9 o'clock", "10:30",
        ]
        let petals = Ring.allCases.map { ring in
            "\(ring.displayName.lowercased()) \(board[ring, slot].accessibilityDescription)"
        }
        let bindweed = infectedSpokes.contains(slot) ? ", tangled with bindweed" : ""
        return "\(positions[slot]): \(petals.joined(separator: ", "))\(bindweed)"
    }

    private var boardAccessibilitySummary: String {
        var summary = "Three ring flower board. \(selectedRing.displayName) ring selected."
        if let preview = bindweedSpreadPreview {
            let positions = [
                "12 o'clock", "1:30", "3 o'clock", "4:30",
                "6 o'clock", "7:30", "9 o'clock", "10:30",
            ]
            summary += " Bindweed will spread to \(positions[preview.destination]) after 1 more turn."
        }
        return summary
    }
}

private struct BloomBurst: View {
    let spokes: [Int]
    let side: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        ZStack {
            ForEach(spokes, id: \.self) { slot in
                let angle = -CGFloat.pi / 2
                    + CGFloat(slot) * (2 * CGFloat.pi / CGFloat(GameBoard.slotsPerRing))
                let length = side * 0.43

                Capsule()
                    .fill(RingbloomTheme.ivory)
                    .frame(width: length, height: 3)
                    .offset(x: length / 2)
                    .rotationEffect(.radians(Double(angle)))

                Circle()
                    .fill(RingbloomTheme.saffron)
                    .frame(width: side * 0.04, height: side * 0.04)
                    .offset(x: cos(angle) * length, y: sin(angle) * length)
                    .shadow(color: RingbloomTheme.saffron, radius: 12)
            }
        }
        .scaleEffect(reduceMotion ? 1 : (expanded ? 1.08 : 0.58))
        .opacity(expanded ? 0 : 0.94)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.18 : 0.68)) {
                expanded = true
            }
        }
    }
}
