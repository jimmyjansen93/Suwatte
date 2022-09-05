//
//  Paged+Controller.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-20.
//

import Combine
import UIKit
extension UICollectionView {
    var currentPoint: CGPoint {
        .init(x: contentOffset.x + frame.midX, y: contentOffset.y + frame.midY)
    }
}

extension PagedViewer {
    final class PagedController: UICollectionViewController {
        var model: ReaderView.ViewModel!
        var subscriptions = Set<AnyCancellable>()
        var currentPath: IndexPath? {
            collectionView.indexPathForItem(at: collectionView.currentPoint)
        }

        var isScrolling: Bool = false
        var enableInteractions: Bool = Preferences.standard.imageInteractions

        deinit {
            print("Paged Controller Deallocated")
        }
    }
}

private typealias PagedController = PagedViewer.PagedController

// MARK: View Setup

private typealias ImageCell = PagedViewer.ImageCell

extension PagedController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setCollectionView()
        registerCells()
        addModelSubscribers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        transformView()
        guard let rChapter = model.readerChapterList.first else {
            return
        }
        let requestedIndex = rChapter.requestedPageIndex
        rChapter.requestedPageOffset = nil
        let openingIndex = model.sections[0].firstIndex(where: { ($0 as? ReaderView.Page)?.index == requestedIndex }) ?? requestedIndex
        let path: IndexPath = .init(item: openingIndex, section: 0)
        collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: false)
        let point = collectionView.layoutAttributesForItem(at: path)?.frame.midX ?? 0
        model.slider.setCurrent(point)
        DispatchQueue.main.async {
            self.calculateCurrentChapterScrollRange()
        }
        collectionView.isHidden = false
    }

    func registerCells() {
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.identifier)
        collectionView.register(ReaderView.TransitionCell.self, forCellWithReuseIdentifier: ReaderView.TransitionCell.identifier)
    }

    func setCollectionView() {
        collectionView.setCollectionViewLayout(getLayout(), animated: false)
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        collectionView.isPagingEnabled = true
        collectionView.scrollsToTop = false
        collectionView.isHidden = true
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGR.numberOfTapsRequired = 2
        tapGR.require(toFail: doubleTapGR)
        collectionView.addGestureRecognizer(doubleTapGR)
        collectionView.addGestureRecognizer(tapGR)
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        guard let sender = sender else {
            return
        }

        let location = sender.location(in: view)
        model.handleNavigation(location)
    }

    @objc func handleDoubleTap(_: UITapGestureRecognizer? = nil) {
        // Do Nothing
    }

    func getLayout() -> UICollectionViewLayout {
        let layout = HorizontalContentSizePreservingFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets.zero
        layout.estimatedItemSize = .zero
        return layout
    }
}

// MARK: Subscriptions

extension PagedController {
    func addModelSubscribers() {
        // MARK: Reload

        model.reloadPublisher.sink { [unowned self] in
            DispatchQueue.main.async {
                collectionView.reloadData()
                collectionView.scrollToItem(at: .init(item: 0, section: 0), at: .centeredHorizontally, animated: false)
            }

        }.store(in: &subscriptions)

        // MARK: Insert

        model.insertPublisher.sink { [unowned self] section in

            Task { @MainActor in

                // Next Chapter Logic
                let data = model.sections[section]
                let paths = data.indices.map { IndexPath(item: $0, section: section) }

                let layout = collectionView.collectionViewLayout as? HorizontalContentSizePreservingFlowLayout
                layout?.isInsertingCellsToTop = section == 0 && model.sections.count != 0

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                collectionView.performBatchUpdates({
                    let set = IndexSet(integer: section)
                    collectionView.insertSections(set)
                    collectionView.insertItems(at: paths)
                }) { finished in
                    if finished {
                        CATransaction.commit()
                    }
                }
            }

        }.store(in: &subscriptions)

        // MARK: Slider

        model.$slider.sink { [unowned self] slider in
            if slider.isScrubbing {
                let position = CGPoint(x: slider.current, y: 0)

                if let path = collectionView.indexPathForItem(at: position), let item = model.sections[path.section][path.item] as? ReaderView.Page {
                    model.scrubbingPageNumber = item.index + 1
                }

                collectionView.setContentOffset(position, animated: false)
            }
        }
        .store(in: &subscriptions)

        // MARK: Navigation Publisher

        model.navigationPublisher.sink { [unowned self] action in
            let rtl = Preferences.standard.readingLeftToRight

            var isPreviousTap = action == .LEFT
            if !rtl { isPreviousTap.toggle() }

            let width = collectionView.frame.width
            let offset = isPreviousTap ? collectionView.currentPoint.x - width : collectionView.currentPoint.x + width

            let path = collectionView.indexPathForItem(at: .init(x: offset, y: 0))

            if let path = path {
                collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: true)
            }
        }
        .store(in: &subscriptions)

        // MARK: Did End Scrubbing

        model.scrubEndPublisher.sink { [weak self] in
            guard let currentPath = self?.currentPath else {
                return
            }
            self?.collectionView.scrollToItem(at: currentPath, at: .centeredHorizontally, animated: true)
        }
        .store(in: &subscriptions)

        // MARK: Preference Publisher

        Preferences.standard.preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.forceTransitions ||
                    changedKeyPath == \Preferences.imageInteractions
            }
            .sink { [unowned self] _ in
                DispatchQueue.main.async {
                    collectionView.reloadData()
                }
            }
            .store(in: &subscriptions)
//
//        // MARK: LTR & RTL Publisher
//
        Preferences.standard.preferencesChangedSubject
            .filter { \Preferences.readingLeftToRight == $0 }
            .sink { [unowned self] _ in
                transformView()
                DispatchQueue.main.async {
                    collectionView.collectionViewLayout.invalidateLayout()
                    calculateCurrentChapterScrollRange()
                }
            }
            .store(in: &subscriptions)
//

//
//        // MARK: User Default
        Preferences.standard.preferencesChangedSubject
            .filter { \Preferences.imageInteractions == $0 }
            .sink { [unowned self] _ in
                enableInteractions = Preferences.standard.imageInteractions
            }
            .store(in: &subscriptions)
    }

    func transformView() {
        if Preferences.standard.readingLeftToRight {
            collectionView.transform = .identity
        } else {
            collectionView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
    }
}

// MARK: CollectionView Sections

extension PagedController {
    override func numberOfSections(in _: UICollectionView) -> Int {
        model.sections.count
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        model.sections[section].count
    }
}

// MARK: Cell For Item At

extension PagedController {
    override func viewDidLayoutSubviews() {
        if !isScrolling {
            super.viewDidLayoutSubviews()
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Cell Logic
        let data = model.getObject(atPath: indexPath)

        if let data = data as? ReaderView.Page {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.identifier, for: indexPath) as! ImageCell
            cell.initializePage(page: data)
            cell.backgroundColor = .clear
//            // Enable Interactions
            if enableInteractions {
                cell.pageView?.imageView.addInteraction(UIContextMenuInteraction(delegate: self))
            }
//
            cell.pageView?.setImage()
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReaderView.TransitionCell.identifier, for: indexPath) as! ReaderView.TransitionCell
        cell.configure(data as! ReaderView.Transition)
        cell.backgroundColor = .clear
        return cell
    }
}

// MARK: CollectionView Will & Did

extension PagedController {
    override func collectionView(_: UICollectionView, willDisplay _: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        handleChapterPreload(at: indexPath)
    }

    override func collectionView(_: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt _: IndexPath) {
        guard let cell = cell as? ImageCell else {
            return
        }
        cell.pageView?.imageView.kf.cancelDownloadTask()
        cell.pageView?.downloadTask?.cancel()
    }
}

// MARK: Chapter Preloading

extension PagedController {
    func handleChapterPreload(at path: IndexPath) {
        guard let currentPath = currentPath, currentPath.section == path.section else {
            return
        }

        if currentPath.item < path.item {
            let preloadNext = model.sections[path.section].count - path.item + 1 < 5
            if preloadNext, model.readerChapterList.get(index: path.section + 1) == nil {
                model.loadNextChapter()
            }
        }
    }
}

// MARK: Cell Sizing

extension PagedController: UICollectionViewDelegateFlowLayout {
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return UIScreen.main.bounds.size
    }
}

// MARK: DID Scroll

import SwiftUI
extension PagedController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset.x)
        isScrolling = true
    }

    func onUserDidScroll(to _: CGFloat) {
        // Update Offset
        if !model.slider.isScrubbing {
            model.slider.setCurrent(collectionView.contentOffset.x)
            model.menuControl.hideMenu()
        }
    }

    func calculateCurrentChapterScrollRange() {
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.indexPathForItem(at: collectionView.currentPoint) else {
            return
        }

        let section = model.sections[path.section]

        // Get Min
        if let minIndex = section.firstIndex(where: { $0 is ReaderView.Page }) {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minX
            }
        }

        // Get Max
        if let maxIndex = section.lastIndex(where: { $0 is ReaderView.Page }) {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
            if let attributes = attributes {
                sectionMaxOffset = attributes.frame.maxX - collectionView.frame.width
            }
        }

        withAnimation {
            model.slider.setRange(sectionMinOffset, sectionMaxOffset)
        }
    }
}

// MARK: Did Stop Scrolling

extension PagedController {
    override func scrollViewDidEndDecelerating(_: UIScrollView) {
        onScrollStop()
    }

    override func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            return
        }
        onScrollStop()
    }

    override func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        onScrollStop()
    }

    func onScrollStop() {
        isScrolling = false

        // Handle Load Prev
        if collectionView.contentOffset.x <= 0 {
            model.loadPreviousChapter()
        }
        // Recalculate Scrollable Range
        calculateCurrentChapterScrollRange()

        // Do Scroll To
        guard let path = currentPath else {
            return
        }
        model.activeChapter.requestedPageOffset = nil
        model.didScrollTo(path: path)
        model.scrubbingPageNumber = nil
    }
}

// MARK: Context Menu Delegate

extension PagedController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration?
    {
        let point = interaction.location(in: collectionView)
        let indexPath = collectionView.indexPathForItem(at: point)

        // Validate Is Image
        guard let indexPath = indexPath, model.sections[indexPath.section][indexPath.item] is ReaderView.Page else {
            return nil
        }

        // Get Image
        guard let image = (interaction.view as? UIImageView)?.image else {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in

            // Image Actiosn menu
            // Save to Photos
            let saveToAlbum = UIAction(title: "Save Panel", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                STTPhotoAlbum.shared.save(image)
            }

            // Share Photo
            let sharePhotoAction = UIAction(title: "Share Panel", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let objectsToShare = [image]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                self.present(activityVC, animated: true, completion: nil)
            }

            let photoMenu = UIMenu(title: "Image", options: .displayInline, children: [saveToAlbum, sharePhotoAction])

            // Toggle Bookmark
            let chapter = self.model.activeChapter.chapter
            let page = indexPath.item + 1

            var menu = UIMenu(title: "", children: [photoMenu])

            if chapter.chapterType != .EXTERNAL {
                return menu
            }
            // Bookmark Actions
            let isBookmarked = DataManager.shared.isBookmarked(chapter: chapter, page: page)
            let bkTitle = isBookmarked ? "Remove Bookmark" : "Bookmark Panel"
            let bkSysImage = isBookmarked ? "bookmark.slash" : "bookmark"

            let bookmarkAction = UIAction(title: bkTitle, image: UIImage(systemName: bkSysImage), attributes: isBookmarked ? [.destructive] : []) { _ in
                DataManager.shared.toggleBookmark(chapter: chapter, page: page)
            }

            menu = menu.replacingChildren([photoMenu, bookmarkAction])
            return menu
        })
    }
}

// MARK: CollectionVeiw Prefetching

import Kingfisher
extension PagedController: UICollectionViewDataSourcePrefetching {
    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { path -> URL? in
            guard let page = self.model.sections[path.section][path.item] as? ReaderView.Page, let url = page.hostedURL, !page.isLocal else {
                return nil
            }

            return URL(string: url)
        }
        ImagePrefetcher(urls: urls).start()
    }

    func prefetch(pages: [ReaderView.Page]) {
        let urls = pages.compactMap { page -> URL? in
            guard let url = page.hostedURL else {
                return nil
            }
            return URL(string: url)
        }
        ImagePrefetcher(urls: urls).start()
    }
}

extension PagedController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let lastPath = currentPath

//
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.layoutIfNeeded()
        }, completion: { _ in
            guard let lastPath = lastPath, let attributes = self.collectionView.layoutAttributesForItem(at: lastPath) else {
                return
            }
            DispatchQueue.main.async {
                self.collectionView.setContentOffset(.init(x: attributes.frame.origin.x, y: 0), animated: true)
            }
        })
        super.viewWillTransition(to: size, with: coordinator)
    }
}