//
//  PagedCoordinator+Data.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-07.
//

import Foundation

fileprivate typealias Coordinator = PagedImageViewer.Coordinator

extension Coordinator {
    
    func didChangePage(_ page: PanelViewerItem) {
        print("page change")
        
    }
    
    func didChapterChange(from: ThreadSafeChapter, to: ThreadSafeChapter) {
        // Update Scrub Range
        currentChapterRange = getScrollRange()
    }
    
    @MainActor
    func loadPrevChapter() async {
        guard let current = collectionView.currentPath, // Current Index
              let chapter = dataSource.itemIdentifier(for: current)?.chapter, // Current Chapter
              let currentReadingIndex = await dataCache.chapters.firstIndex(of: chapter), // Index Relative to ChapterList
              currentReadingIndex != 0, // Is not the first chapter
              let next = await dataCache.chapters.getOrNil(currentReadingIndex - 1), // Next Chapter in List
              model.loadState[next] == nil else { return } // is not already loading/loaded
        
        await loadAtHead(next)
        print("Loaded Prev")
    }
    
    func updateReaderState(with chapter: ThreadSafeChapter, page: Int, count: Int) async {
        
        let hasNext = await dataCache.getChapter(after: chapter) != nil
        let hasPrev = await dataCache.getChapter(before: chapter) != nil
        let state: CurrentViewerState = .init(chapter: chapter, page: page, pageCount: count, hasPreviousChapter: hasPrev, hasNextChapter: hasNext)
        
        await model.setViewerState(state)
    }
}
