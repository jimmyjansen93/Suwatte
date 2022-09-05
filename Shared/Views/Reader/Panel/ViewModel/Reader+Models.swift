//
//  Reader+Protocols.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-29.
//

import Kingfisher
import Nuke
import SwiftUI

// MARK: Protocols

protocol ReaderTransitionManager {
    func didMove(toPage page: ReaderView.Page)
    func onChapterCompleted(chapter: ReaderView.ReaderChapter)
}

protocol ReaderSliderManager {
    var slider: ReaderView.SliderControl { get set }

    func updateSliderOffsets(min: CGFloat, max: CGFloat)
}

protocol ReaderMenuManager {
    var menu: ReaderView.MenuControl { get set }

    func toggleMenu()
    func toggleComments()
    func toggleChaperList()
    func toggleSettings()
    func toggleTransitionOptions()
}

protocol SliderPublisher {
    func getScrubbableRange()
}

protocol ReaderChapterLoader {
    func loadChapterData(for chapter: ReaderView.ReaderChapter, setMarker: Bool)
}

// MARK: Structs

extension ReaderView {
    // MARK: Slider Control

    struct SliderControl {
        var min: CGFloat = 0.0
        var current: CGFloat = 0.0
        var max: CGFloat = 1000.0

        var isScrubbing = false

        mutating func setCurrent(_ val: CGFloat) {
            current = val
        }

        mutating func setRange(_ min: CGFloat, _ max: CGFloat) {
            self.min = min
            self.max = max
        }
    }

    struct MenuControl {
        var menu = false
        var chapterList = false
        var comments = false
        var settings = false
        var transitionOption = false

        mutating func toggleMenu() {
            menu.toggle()
        }

        mutating func hideMenu() {
            menu = false
        }

        mutating func toggleChapterList() {
            chapterList.toggle()
        }

        mutating func toggleSettings() {
            settings.toggle()
        }

        mutating func toggleComments() {
            comments.toggle()
        }
    }

    // MARK: Reader Chapter

    class ReaderChapter: Equatable, ObservableObject {
        var chapter: StoredChapter
        @Published var data = Loadable<StoredChapterData>.idle {
            didSet {
                guard let chapterData = data.value else {
                    pages = nil
                    return
                }

                let chapterId = chapter._id

                // Archive
                if !chapterData.archivePaths.isEmpty {
                    let paths = chapterData.archivePaths
                    let arr = zip(paths.indices, paths)
                    let file = chapter.contentId
                    pages = arr.map {
                        Page(chapterId: chapterId, index: $0, archivePath: $1, archiveFile: file)
                    }
                }
                // Downloaded
                else if !chapterData.urls.isEmpty {
                    let urls = chapterData.urls
                    let arr = zip(urls.indices, urls)
                    pages = arr.map {
                        Page(chapterId: chapterId, index: $0, downloadURL: $1)
                    }
                }

                // Raws
                else if !chapterData.rawDatas.isEmpty {
                    let raws = chapterData.rawDatas
                    let arr = zip(raws.indices, raws)
                    pages = arr.map {
                        Page(chapterId: chapterId, index: $0, rawData: $1)
                    }
                }
                // URL
                else {
                    let images = chapterData.imageURLs
                    let arr = zip(images.indices, images)

                    pages = arr.map {
                        Page(chapterId: chapterId, index: $0, hostedURL: $1)
                    }
                }
            }
        }

        var requestedPageIndex = 0 // Current Page
        var requestedPageOffset: CGFloat? // offset for current page
        init(chapter: StoredChapter) {
            self.chapter = chapter
        }

        static func == (lhs: ReaderChapter, rhs: ReaderChapter) -> Bool {
            return lhs.chapter.chapterId == rhs.chapter.chapterId
        }

        var pages: [Page]?

        enum ChapterType {
            case EXTERNAL, LOCAL, OPDS
        }
    }

    // MARK: Reader Page

    struct Page: Hashable {
        var index: Int
        var isLocal: Bool {
            archivePath != nil || downloadURL != nil
        }

        var downloadURL: URL?
        var hostedURL: String?
        var rawData: String?
        var archivePath: String?
        var archiveFile: String?
        var number: Int {
            index + 1
        }

        var chapterId: String

        init(chapterId: String, index: Int, hostedURL: String? = nil, downloadURL: URL? = nil, rawData: String? = nil, archivePath: String? = nil, archiveFile: String? = nil) {
            self.chapterId = chapterId
            self.index = index
            self.downloadURL = downloadURL
            self.hostedURL = hostedURL
            self.rawData = rawData
            self.archivePath = archivePath
            self.archiveFile = archiveFile
        }

        static func == (lhs: Page, rhs: Page) -> Bool {
            return lhs.chapterId == rhs.chapterId && lhs.index == rhs.index
        }

        var CELL_KEY: String {
            "\(chapterId)||\(index)"
        }
    }

    // MARK: ReaderTransition

    struct Transition: Hashable {
        var from: StoredChapter
        var to: StoredChapter?
        var type: TransitionType

        enum TransitionType {
            case NEXT, PREV
        }

        init(from: StoredChapter, to: StoredChapter?, type: TransitionType) {
            self.from = from
            self.to = to
            self.type = type
        }

        static func == (lhs: Transition, rhs: Transition) -> Bool {
            if lhs.from == rhs.from, lhs.to == rhs.to { return true }
            if lhs.to == rhs.from, lhs.from == rhs.to { return true }
            return false
        }
    }
}

extension StoredChapter {
    static func == (lhs: StoredChapter, rhs: StoredChapter) -> Bool {
        lhs._id == rhs._id
    }
}

extension ReaderView.Page {
    func toKFSource() -> Kingfisher.Source? {
        // Hosted Image
        if let hostedURL = hostedURL, let url = URL(string: hostedURL) {
            return url.convertToSource(overrideCacheKey: CELL_KEY)
        }

        // Downloaded
        else if let url = downloadURL {
            return url.convertToSource(overrideCacheKey: CELL_KEY)
        }

        // Archive
        else if let archivePath = archivePath, let file = archiveFile {
            let provider = LocalContentImageProvider(cacheKey: CELL_KEY, fileId: file, pagePath: archivePath)
            return .provider(provider)
        }

        // Raw Data
        else if let rawData = rawData {
            let provider = Base64ImageDataProvider(base64String: rawData, cacheKey: CELL_KEY)
            return .provider(provider)
        }

        return nil
    }
}