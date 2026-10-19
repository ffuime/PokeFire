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

struct TabCollection: UIViewRepresentable {
    let items: [TabItem]
    let active: Int
    let model: AppModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
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
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "tab")
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
        guard !coordinator.dragging else { return }
        let activeChanged = coordinator.active != active
        guard coordinator.items != items || activeChanged else { return }
        coordinator.items = items
        coordinator.active = active
        view.reloadData()
        if activeChanged, items.indices.contains(active) {
            DispatchQueue.main.async {
                view.scrollToItem(at: IndexPath(item: active, section: 0), at: .centeredHorizontally, animated: true)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
        var items: [TabItem] = []
        var active = 0
        var model: AppModel
        var dragging = false

        init(model: AppModel) {
            self.model = model
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            items.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tab", for: indexPath)
            let index = indexPath.item
            if items.indices.contains(index) {
                let item = items[index]
                let isActive = index == active
                cell.contentConfiguration = UIHostingConfiguration {
                    TabChipLabel(item: item, index: index, active: isActive)
                }
                .margins(.all, 0)
            }
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: false)
            model.activate(indexPath.item)
        }

        private func capsulePath(_ cell: UICollectionViewCell) -> UIBezierPath {
            let rect = cell.contentView.bounds
            return UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        }

        func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
            guard let index = indexPaths.first?.item, items.indices.contains(index) else { return nil }
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
            guard items.indices.contains(indexPath.item) else { return [] }
            dragging = true
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
            dragging = false
            collectionView.reloadData()
        }

        func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
            session.localDragSession != nil
        }

        func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
            guard session.localDragSession != nil else { return UICollectionViewDropProposal(operation: .forbidden) }
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
            guard let dropItem = coordinator.items.first, let source = dropItem.sourceIndexPath, !items.isEmpty else { return }
            let target = min(items.count - 1, max(0, coordinator.destinationIndexPath?.item ?? items.count - 1))
            let destination = IndexPath(item: target, section: 0)
            collectionView.performBatchUpdates({
                let moved = items.remove(at: source.item)
                items.insert(moved, at: target)
                collectionView.moveItem(at: source, to: destination)
            }, completion: nil)
            coordinator.drop(dropItem.dragItem, toItemAt: destination)
            dragging = false
            model.reorderTab(from: source.item, to: target)
            active = model.active
            collectionView.reloadData()
        }
    }
}
