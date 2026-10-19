import SwiftUI
import UIKit

struct TabItem: Equatable {
    let id: Int
    let kind: TabKind
    let title: String
}

struct TabChipLabel: View {
    let item: TabItem
    let index: Int
    let active: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text("\(index + 1)")
                .font(.caption.weight(.heavy))
                .monospacedDigit()
            Icon(name: item.kind.icon, size: 14)
                .foregroundStyle(active ? Color.white : Palette.tab(item.kind))
            Text(item.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: 110)
        }
        .foregroundStyle(active ? Color.white : Palette.ink)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .glassEffect(active ? .regular.tint(Palette.tab(item.kind)) : .regular, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index + 1)番目 \(item.kind.menuLabel) \(item.title)")
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }
}

struct ResetChipLabel: View {
    var body: some View {
        Image(systemName: "arrow.counterclockwise")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.boosted)
            .frame(width: 34, height: 34)
            .glassEffect(.regular, in: Circle())
            .accessibilityLabel("すべてリセット")
            .accessibilityAddTraits(.isButton)
    }
}

final class TabCell: UICollectionViewCell {
    var tabID: Int?
}

struct TabCollection: UIViewRepresentable {
    let items: [TabItem]
    let active: Int
    let model: AppModel
    let onReset: () -> Void

    static let tabSection = 1

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model, onReset: onReset)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumLineSpacing = 6
        layout.minimumInteritemSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.clipsToBounds = false
        view.register(TabCell.self, forCellWithReuseIdentifier: "tab")
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "reset")
        view.dataSource = context.coordinator
        view.delegate = context.coordinator
        view.dragDelegate = context.coordinator
        view.dropDelegate = context.coordinator
        view.dragInteractionEnabled = true
        view.reorderingCadence = .immediate
        context.coordinator.items = items
        context.coordinator.active = active
        return view
    }

    func updateUIView(_ view: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.onReset = onReset
        guard !view.hasActiveDrag else { return }
        let activeChanged = coordinator.active != active
        guard coordinator.items != items || activeChanged else { return }
        let old = coordinator.items
        coordinator.items = items
        coordinator.active = active
        coordinator.apply(view, from: old, to: items)
        if activeChanged, items.indices.contains(active) {
            DispatchQueue.main.async {
                view.scrollToItem(at: IndexPath(item: active, section: TabCollection.tabSection), at: .centeredHorizontally, animated: true)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
        var items: [TabItem] = []
        var active = 0
        var model: AppModel
        var onReset: () -> Void
        private var previewKey: String?

        init(model: AppModel, onReset: @escaping () -> Void) {
            self.model = model
            self.onReset = onReset
        }

        private func path(_ item: Int) -> IndexPath {
            IndexPath(item: item, section: TabCollection.tabSection)
        }

        private func configure(_ cell: UICollectionViewCell, item: TabItem, number: Int, active isActive: Bool) {
            (cell as? TabCell)?.tabID = item.id
            cell.contentConfiguration = UIHostingConfiguration {
                TabChipLabel(item: item, index: number, active: isActive)
            }
            .margins(.all, 0)
        }

        func apply(_ collectionView: UICollectionView, from old: [TabItem], to new: [TabItem]) {
            let oldIDs = old.map(\.id)
            let newIDs = new.map(\.id)
            if oldIDs == newIDs {
                relabel(collectionView, order: new)
                return
            }
            if oldIDs.count == newIDs.count + 1, let removed = oldIDs.firstIndex(where: { !newIDs.contains($0) }),
               oldIDs.filter({ newIDs.contains($0) }) == newIDs {
                collectionView.performBatchUpdates({
                    collectionView.deleteItems(at: [path(removed)])
                }, completion: { _ in
                    self.relabel(collectionView, order: self.items)
                })
                relabel(collectionView, order: new)
                return
            }
            if newIDs.count == oldIDs.count + 1, let inserted = newIDs.firstIndex(where: { !oldIDs.contains($0) }),
               newIDs.filter({ oldIDs.contains($0) }) == oldIDs {
                collectionView.performBatchUpdates({
                    collectionView.insertItems(at: [path(inserted)])
                }, completion: { _ in
                    self.relabel(collectionView, order: self.items)
                })
                relabel(collectionView, order: new)
                return
            }
            if Set(oldIDs) == Set(newIDs) {
                collectionView.performBatchUpdates({
                    for (from, id) in oldIDs.enumerated() {
                        if let to = newIDs.firstIndex(of: id), to != from {
                            collectionView.moveItem(at: path(from), to: path(to))
                        }
                    }
                }, completion: { _ in
                    self.relabel(collectionView, order: self.items)
                })
                relabel(collectionView, order: new)
                return
            }
            collectionView.reloadSections(IndexSet(integer: TabCollection.tabSection))
        }

        private func relabel(_ collectionView: UICollectionView, order: [TabItem]) {
            let activeID = items.indices.contains(active) ? items[active].id : nil
            for case let cell as TabCell in collectionView.visibleCells {
                guard let id = cell.tabID, let position = order.firstIndex(where: { $0.id == id }) else { continue }
                configure(cell, item: order[position], number: position, active: id == activeID)
            }
        }

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            2
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            section == TabCollection.tabSection ? items.count : 1
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            if indexPath.section != TabCollection.tabSection {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "reset", for: indexPath)
                cell.contentConfiguration = UIHostingConfiguration {
                    ResetChipLabel()
                }
                .margins(.all, 0)
                return cell
            }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tab", for: indexPath)
            let index = indexPath.item
            if items.indices.contains(index) {
                configure(cell, item: items[index], number: index, active: index == active)
            }
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: false)
            if indexPath.section != TabCollection.tabSection {
                Haptics.play(.light)
                onReset()
                return
            }
            model.activate(indexPath.item)
        }

        private func capsulePath(_ cell: UICollectionViewCell) -> UIBezierPath {
            let rect = cell.contentView.bounds
            return UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        }

        func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
            guard let indexPath = indexPaths.first, indexPath.section == TabCollection.tabSection,
                  items.indices.contains(indexPath.item) else { return nil }
            let index = indexPath.item
            let kind = items[index].kind
            let tint = UIColor(Palette.tab(kind))
            let count = items.count
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                let left = UIAction(title: "左へ移動", image: UIImage(named: "move_left")?.withTintColor(tint, renderingMode: .alwaysOriginal), attributes: index == 0 ? .disabled : []) { _ in
                    self?.model.moveTab(index, by: -1)
                }
                let right = UIAction(title: "右へ移動", image: UIImage(named: "move_right")?.withTintColor(tint, renderingMode: .alwaysOriginal), attributes: index >= count - 1 ? .disabled : []) { _ in
                    self?.model.moveTab(index, by: 1)
                }
                let remove = UIAction(title: "削除", image: UIImage(named: "close_circle")?.withTintColor(.systemRed, renderingMode: .alwaysOriginal), attributes: count <= 1 ? [.destructive, .disabled] : .destructive) { _ in
                    self?.model.removeTab(index)
                }
                return UIMenu(children: [UIMenu(options: .displayInline, children: [left, right]), remove])
            }
        }

        func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
            guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
            let parameters = UIPreviewParameters()
            parameters.visiblePath = capsulePath(cell)
            parameters.backgroundColor = .clear
            return UITargetedPreview(view: cell.contentView, parameters: parameters)
        }

        func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
            guard indexPath.section == TabCollection.tabSection, items.indices.contains(indexPath.item) else { return [] }
            let provider = NSItemProvider(object: String(items[indexPath.item].id) as NSString)
            let item = UIDragItem(itemProvider: provider)
            item.localObject = items[indexPath.item].id
            return [item]
        }

        func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
            guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
            let parameters = UIDragPreviewParameters()
            parameters.visiblePath = capsulePath(cell)
            parameters.backgroundColor = .clear
            return parameters
        }

        func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
            previewKey = nil
            relabel(collectionView, order: items)
        }

        func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
            previewKey = nil
            relabel(collectionView, order: items)
        }

        func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
            session.localDragSession != nil
        }

        private func target(_ destination: IndexPath?) -> Int? {
            guard !items.isEmpty, let destination else { return nil }
            if destination.section != TabCollection.tabSection { return 0 }
            return min(items.count - 1, max(0, destination.item))
        }

        func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
            guard let local = session.localDragSession else { return UICollectionViewDropProposal(operation: .forbidden) }
            guard let destinationIndexPath, destinationIndexPath.section == TabCollection.tabSection else {
                return UICollectionViewDropProposal(operation: .move, intent: .unspecified)
            }
            if let id = local.items.first?.localObject as? Int,
               let from = items.firstIndex(where: { $0.id == id }),
               let to = target(destinationIndexPath) {
                let key = "\(id)>\(to)"
                if key != previewKey {
                    previewKey = key
                    var order = items
                    let moved = order.remove(at: from)
                    order.insert(moved, at: to)
                    relabel(collectionView, order: order)
                    if to != from { Haptics.play(.selection) }
                }
            }
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
            guard let dropItem = coordinator.items.first, let source = dropItem.sourceIndexPath,
                  source.section == TabCollection.tabSection,
                  let to = target(coordinator.destinationIndexPath ?? path(items.count - 1)) else { return }
            let destination = path(to)
            collectionView.performBatchUpdates({
                let moved = items.remove(at: source.item)
                items.insert(moved, at: to)
                collectionView.moveItem(at: source, to: destination)
            }, completion: nil)
            coordinator.drop(dropItem.dragItem, toItemAt: destination)
            previewKey = nil
            model.reorderTab(from: source.item, to: to)
            active = model.active
            relabel(collectionView, order: items)
        }
    }
}
