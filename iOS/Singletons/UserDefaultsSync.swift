//
//  UserDefaultsSync.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-04.
//

import Foundation
import Zephyr

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

class UDSync {
    private static var debounceTimer: Timer?
    private static var pendingSync: Bool = false
    private static let syncInterval: TimeInterval = 30
    private static let staticBatchSize = 10
    private static let dynamicBatchSize = 5
    
    static func sync() {
        guard isUserLoggedInToiCloud() else { return }

        pendingSync = true
        debounceTimer?.invalidate()
        
        debounceTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: false) { _ in
            Task { @MainActor in
                if pendingSync {
                    syncStaticKeys()
                    syncDynamicKeys()
                }
            }
        }
    }
    
    private static func syncStaticKeys() {
        var keys: [String] = [STTKeys.OpenDefaultCollectionEnabled,
                              STTKeys.OpenDefaultCollection,
                              STTKeys.TileStyle,
                              STTKeys.LibraryGridSortKey,
                              STTKeys.LibraryGridSortOrder,
                              STTKeys.ChapterListSortKey,
                              STTKeys.ChapterListDescending,
                              STTKeys.ChapterListFilterDuplicates,
                              STTKeys.ChapterListShowOnlyDownloaded,
                              STTKeys.ForceTransition,
                              STTKeys.BackgroundColor,
                              STTKeys.UseSystemBG,
                              STTKeys.PagedNavigator,
                              STTKeys.VerticalNavigator,
                              STTKeys.LastFetchedUpdates,
                              STTKeys.LibraryAuth,
                              STTKeys.ShowOnlyDownloadedTitles,
                              STTKeys.LibraryShowBadges,
                              STTKeys.LibraryBadgeType,
                              STTKeys.LocalSortLibrary,
                              STTKeys.LocalOrderLibrary,
                              STTKeys.LocalThumnailOnly,
                              STTKeys.LocalHideInfo,
                              STTKeys.DownloadsSortLibrary,
                              STTKeys.LibrarySections,
                              STTKeys.SelectiveUpdates,
                              STTKeys.AppAccentColor,
                              STTKeys.UpdateInterval,
                              STTKeys.LastAutoBackup,
                              STTKeys.CheckLinkedOnUpdateCheck,
                              STTKeys.DefaultUserAgent,
                              STTKeys.UpdateContentData,
                              STTKeys.UpdateSkipConditions,
                              STTKeys.FilteredProviders,
                              STTKeys.FilteredLanguages,
                              STTKeys.AlwaysAskForLibraryConfig,
                              STTKeys.DefaultCollection,
                              STTKeys.DefaultReadingFlag,
                              STTKeys.DefaultPanelReadingMode,
                              STTKeys.ReaderScrollbarPosition,
                              STTKeys.ReaderBottomScrollbarDirection,
                              STTKeys.MoveDownloadToArchive,
                              STTKeys.OnlyCheckForUpdateInSpecificCollections,
                              STTKeys.UpdateApprovedCollections,
                              STTKeys.SourcesDisabledFromHistory,
                              STTKeys.SourcesDisabledFromGlobalSearch,
                              STTKeys.GlobalContentLanguages,
                              STTKeys.GlobalHideNSFW,
                              STTKeys.OverrideSourceRecommendedReadingMode]
        
        for batch in keys.chunked(into: staticBatchSize) {
            Zephyr.sync(keys: Array(batch))
        }
    }

    private static func syncDynamicKeys() {
        let dynamicKeyPrefixes = ["RUNNER.IRH",
                                  "RUNNER.PLR",
                                  "RUNNER.BLP",
                                  "RUNNER.SCPP",
                                  "RUNNER.THPO",
                                  "READER.type"]
        let dynamicKeys = UserDefaults.standard.dictionaryRepresentation().keys.filter { key in
            dynamicKeyPrefixes.first { key.hasPrefix($0) } != nil
        }
        
        for batch in dynamicKeys.chunked(into: dynamicBatchSize) {
            Zephyr.sync(keys: Array(batch))
        }
    }

    private static func isUserLoggedInToiCloud() -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }
}
