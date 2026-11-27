import AppKit
import SwiftUI
import WebodropKit

/// Interface flottante d'une étagère Webodrop (100 % natif macOS 26/27, adaptatif Clair/Sombre).
struct ShelfView: View {
    let shelf: Shelf
    let engine: WebodropEngine

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if shelf.items.isEmpty {
                emptyDropZone
            } else if shelf.isExpanded {
                expandedListView
            } else {
                collapsedStackView
            }

            if !shelf.items.isEmpty {
                Divider()
                    .opacity(0.4)
                actionBar
            }
        }
        .background {
            shelfBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    shelf.isDropTargeted ? Palette.accent : Color.primary.opacity(0.14),
                    lineWidth: shelf.isDropTargeted ? 2.5 : 1
                )
        }
        .overlay {
            if shelf.isDockedCollapsed, let edge = shelf.dockedEdge {
                dockedTabOverlay(edge: edge)
            }
        }
        .overlay {
            ShelfDropTargetView(shelf: shelf, engine: engine)
        }
        .onHover { hovering in
            engine.panels[shelf.id]?.setEdgePeeked(hovering)
        }
        .scaleEffect(shelf.isDropTargeted ? 1.03 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: shelf.isDropTargeted)
        .animation(.spring(response: 0.25, dampingFraction: 0.84), value: shelf.items.count)
    }

    // MARK: - Languette discrète quand l'étagère est rangée sur le bord gauche/droit

    private func dockedTabOverlay(edge: DockEdge) -> some View {
        HStack {
            if edge == .left { Spacer() }
            VStack(spacing: Space.xs) {
                Image(systemName: edge == .left ? "chevron.right" : "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                if !shelf.items.isEmpty {
                    Text("\(shelf.items.count)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Palette.accent))
                } else {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 30)
            .frame(maxHeight: .infinity)
            if edge == .right { Spacer() }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
        .allowsHitTesting(false)
    }

    // MARK: - Fond natif Liquid Glass / HUD

    @ViewBuilder
    private var shelfBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - En-tête

    private var headerBar: some View {
        ZStack {
            WindowDragHandle()

            HStack(spacing: Space.xs) {
                Button {
                    shelf.isPinned.toggle()
                } label: {
                    Image(systemName: shelf.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(shelf.isPinned ? Palette.accent : .secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(shelf.isPinned ? "Désépingler (l'étagère pourra se fermer après dépôt)" : "Épingler (garder ouverte après dépôt)")

                Spacer(minLength: 4)

                if let message = shelf.statusMessage {
                    Text(message)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                } else {
                    Capsule()
                        .fill(Color.primary.opacity(0.22))
                        .frame(width: 32, height: 4)
                        .allowsHitTesting(false)
                }

                Spacer(minLength: 4)

                Button {
                    engine.closeShelf(shelf)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Fermer l'étagère")
            }
            .padding(.horizontal, Space.sm)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xs)
        }
        .frame(height: 36)
    }

    // MARK: - État vide

    private var emptyDropZone: some View {
        ZStack {
            WindowDragHandle()

            VStack(spacing: Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            shelf.isDropTargeted ? Palette.accent : Color.secondary.opacity(0.32),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(shelf.isDropTargeted ? Palette.accent.opacity(0.12) : Color.primary.opacity(0.03))
                        )

                    VStack(spacing: Space.xs) {
                        Image(systemName: shelf.isDropTargeted ? "plus.circle.fill" : "tray.and.arrow.down")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(shelf.isDropTargeted ? Palette.accent : .secondary)
                            .symbolEffect(.bounce, value: shelf.isDropTargeted)

                        Text(shelf.isDropTargeted ? "Relâchez ici" : "Déposez ici")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Fichiers, images, liens…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(Space.sm)
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.md)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - État rempli : Mode Pile (Stack)

    private var collapsedStackView: some View {
        VStack(spacing: Space.sm) {
            ZStack {
                thumbnailStack
                ShelfDragSourceView(
                    items: shelf.items,
                    onDragCompleted: { op in
                        engine.handleDragOutCompleted(for: shelf, operation: op)
                    },
                    onSingleClick: {
                        engine.openQuickLook(for: shelf, startingAt: 0)
                    }
                )
            }
            .frame(height: 88)
            .help("Glissez pour déposer tous les éléments • Cliquez ou Espace pour Quick Look")

            ZStack {
                WindowDragHandle()
                VStack(spacing: 2) {
                    Text(shelf.summaryTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(shelf.summarySubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, Space.sm)
                .allowsHitTesting(false)
            }
            .frame(height: 36)
        }
        .padding(.horizontal, Space.sm)
        .padding(.bottom, Space.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var thumbnailStack: some View {
        let previewItems = Array(shelf.items.prefix(3).reversed())
        return ZStack(alignment: .topTrailing) {
            ZStack {
                ForEach(Array(previewItems.enumerated()), id: \.element.id) { idx, item in
                    let reverseIdx = previewItems.count - 1 - idx
                    let angle: Double = reverseIdx == 0 ? 0 : (reverseIdx == 1 ? -7 : 7)
                    let offsetX: CGFloat = reverseIdx == 0 ? 0 : (reverseIdx == 1 ? -7 : 7)
                    let offsetY: CGFloat = CGFloat(reverseIdx) * -2

                    thumbnailCard(for: item)
                        .rotationEffect(.degrees(angle))
                        .offset(x: offsetX, y: offsetY)
                }
            }
            .frame(width: 78, height: 78)

            if shelf.items.count > 1 {
                Text("\(shelf.items.count)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.accent))
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    .offset(x: 6, y: -4)
            }
        }
    }

    private func thumbnailCard(for item: ShelfItem) -> some View {
        Group {
            if let nsImage = item.thumbnail {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: item.kind.symbolName)
                    .font(.system(size: 32))
                    .foregroundStyle(Palette.accent)
            }
        }
        .frame(width: 64, height: 64)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - État rempli : Mode Liste étendue

    private var expandedListView: some View {
        ScrollView {
            LazyVStack(spacing: Space.xs) {
                ForEach(Array(shelf.items.enumerated()), id: \.element.id) { index, item in
                    expandedRow(item: item, index: index)
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func expandedRow(item: ShelfItem, index: Int) -> some View {
        HStack(spacing: Space.sm) {
            ZStack {
                HStack(spacing: Space.sm) {
                    Group {
                        if let thumb = item.thumbnail {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: item.kind.symbolName)
                                .foregroundStyle(Palette.accent)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(item.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }

                ShelfDragSourceView(
                    items: [item],
                    onDragCompleted: { _ in },
                    onSingleClick: {
                        engine.openQuickLook(for: shelf, startingAt: index)
                    }
                )
            }

            Button {
                engine.removeItem(item, from: shelf)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Retirer de l'étagère")
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Barre d'actions rapides

    private var actionBar: some View {
        HStack(spacing: Space.xs) {
            iconAction("eye", help: "Aperçu Quick Look (Espace)") {
                engine.openQuickLook(for: shelf)
            }

            SharePickerButton(
                urls: shelf.items.map(\.fileURL),
                disabled: shelf.items.isEmpty
            )
            .frame(width: 28, height: 28)

            iconAction("doc.zipper", help: "Compresser en archive ZIP") {
                engine.zipShelf(shelf)
            }
            .disabled(shelf.isBusy)

            iconAction(
                shelf.isExpanded ? "rectangle.stack" : "list.bullet",
                help: shelf.isExpanded ? "Afficher en pile" : "Déployer la liste"
            ) {
                engine.toggleExpanded(shelf)
            }

            Spacer(minLength: 0)

            Menu {
                Button("Copier les fichiers", systemImage: "doc.on.doc") {
                    engine.copyItems(in: shelf)
                }
                Button("Révéler dans le Finder", systemImage: "folder") {
                    engine.revealInFinder(shelf)
                }
                Divider()
                Button("Vider l'étagère", systemImage: "trash", role: .destructive) {
                    for item in shelf.items {
                        engine.removeItem(item, from: shelf)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Plus d'actions")
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xs)
    }

    private func iconAction(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
