//
//  WebtoonController+Setup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-19.
//

import UIKit

private typealias Controller = WebtoonController

extension Controller {
    internal func updateReaderState(with chapter: ThreadSafeChapter, indexPath: IndexPath, offset: CGFloat?) async {
        let hasNext = await dataCache.getChapter(after: chapter) != nil
        let hasPrev = await dataCache.getChapter(before: chapter) != nil
        let pages = await dataCache.cache[chapter.id]?.count
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let pages, case .page(let page) = item else {
            Logger.shared.warn("invalid reader state", "updateReaderState")
            return
        }
        
        let state: CurrentViewerState = .init(chapter: chapter,
                                              page: page.page.number,
                                              pageCount: pages,
                                              hasPreviousChapter: hasPrev,
                                              hasNextChapter: hasNext)
        
        model.setViewerState(state)
    }
    
    internal func startup() {
        Task { [weak self] in
            guard let self else { return }
            let state = await self.initialLoad()
            guard let state else { return }
            let (chapter, path, offset) = state
            await self.updateReaderState(with: chapter, indexPath: path, offset: offset)
            await MainActor.run { [weak self] in
                self?.didFinishInitialLoad(chapter, path, offset)
            }
        }
    }
    
    internal func initialLoad() async -> (ThreadSafeChapter, IndexPath, CGFloat?)? {
        guard let pendingState = model.pendingState else {
            Logger.shared.warn("calling initialLoad() without any pending state")
            return nil
        }
        let chapter = pendingState.chapter
        let isLoaded = model.loadState[chapter] != nil
        
        if !isLoaded {
            // Load Chapter Data
            _ = await load(chapter)
        } else {
            // Data has already been loaded, just apply instead
            await apply(chapter)

        }
                        
        // Retrieve chapter data
        guard let chapterIndex = await dataCache.chapters.firstIndex(of: chapter) else {
            Logger.shared.warn("load complete but page list is empty", "ImageViewer")
            return nil
        }
        
        let isFirstChapter = chapterIndex == 0
        let requestedPageIndex = (pendingState.pageIndex ?? 0) + (isFirstChapter ? 1 : 0)
        let indexPath = IndexPath(item: requestedPageIndex, section: 0)
        
        model.pendingState = nil // Consume Pending State
        
        return (chapter, indexPath, pendingState.pageOffset.flatMap(CGFloat.init))
    }

    /// Called after the first requested chapter has loaded.
    func didFinishInitialLoad(_ chapter: ThreadSafeChapter, _ path: IndexPath, _ offset: CGFloat?) {
        lastIndexPath = path
        collectionNode.scrollToItem(at: path, at: .top, animated: false)
        updateChapterScrollRange()
        setScrollPCT()
        presentNode()
    }
}


extension Controller {
    func load(_ chapter: ThreadSafeChapter) async {
        do {
            model.updateChapterState(for: chapter, state: .loading)
            try await dataCache.load(for: chapter)
            await apply(chapter)
        } catch {
            Logger.shared.error(error)
            model.updateChapterState(for: chapter, state: .failed(error))
            return
        }
    }
    
    func apply(_ chapter: ThreadSafeChapter) async {
        let pages = await build(for: chapter)

        let id = chapter.id
        dataSource.appendSections([id])
        dataSource.appendItems(pages, to: id)
        let section = dataSource.sections.count - 1
        let paths = pages.indices.map { IndexPath(item: $0, section: section) }
        let set = IndexSet(integer: section)
        await collectionNode.performBatch(animated: false) { [weak self] in
            self?.collectionNode.insertSections(set)
            self?.collectionNode.insertItems(at: paths)
        }
    }
    
    func build(for chapter: ThreadSafeChapter) async -> [PanelViewerItem] {
        await dataCache.prepare(chapter.id) ?? []

    }
}
