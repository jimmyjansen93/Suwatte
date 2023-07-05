//
//  BackupManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift
class BackupManager: ObservableObject {
    private var observer: DispatchSourceFileSystemObject?
    static let shared = BackupManager()
    let directory = FileManager.default.documentDirectory.appendingPathComponent("Backups", isDirectory: true)
    @Published var urls: [URL]
    
    init() {
        if !directory.exists {
            directory.createDirectory()
        }
        urls = directory.contents.sorted(by: \.lastModified, descending: true)
    }
    
    func refresh() {
        let urls = directory
            .contents
            .sorted(by: \.lastModified, descending: true)
            .filter { $0.pathExtension == "json" }
        Task { @MainActor in
            self.urls = urls
        }
    }
    
    func save(name: String? = nil) throws {
        let backup = create()
        let json = try backup.encoded()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm:ss"
        let name = name ?? .random(length: 5)
        let path = directory.appendingPathComponent("STT_BACKUP_\(name)_\(dateFormatter.string(from: backup.date)).json")
        try json.write(to: path)
        refresh()
    }
    
    func create() -> Backup {
        let manager = DataManager.shared
        return manager.getAllLibraryObjects()
    }
    
    func remove(url: URL) {
        try? FileManager.default.removeItem(at: url)
        refresh()
    }
    
    func `import`(from url: URL) throws {
        let location = directory.appendingPathComponent(url.lastPathComponent)
        if location.exists {
            throw BackUpError.FileExists
        }
        try FileManager.default.copyItem(at: url, to: location)
        refresh()
    }
    
    private func restoreDB(backup: Backup) {
        let realm = try! Realm()
        try! realm.safeWrite {
            // Delete old objects
            realm.objects(LibraryEntry.self).setValue(true, forKey: "isDeleted")
            realm.objects(LibraryCollection.self).setValue(true, forKey: "isDeleted")
            realm.objects(Bookmark.self).setValue(true, forKey: "isDeleted")
            realm.objects(ReadLater.self).setValue(true, forKey: "isDeleted")
            realm.objects(ProgressMarker.self).setValue(true, forKey: "isDeleted")
            realm.objects(StoredRunnerList.self).setValue(true, forKey: "isDeleted")
            realm.objects(StoredRunnerObject.self).setValue(true, forKey: "isDeleted")
            realm.objects(CustomThumbnail.self).setValue(true, forKey: "isDeleted")
            realm.objects(ChapterReference.self).setValue(true, forKey: "isDeleted")
            realm.objects(StreamableOPDSContent.self).setValue(true, forKey: "isDeleted")
            realm.objects(InteractorStoreObject.self).setValue(true, forKey: "isDeleted")
            realm.objects(TrackerLink.self).setValue(true, forKey: "isDeleted")
            realm.objects(ContentLink.self).setValue(true, forKey: "isDeleted")
            realm.objects(ArchivedContent.self).setValue(true, forKey: "isDeleted")
            realm.objects(LibraryCollectionFilter.self).setValue(true, forKey: "isDeleted")
            realm.objects(UpdatedSearchHistory.self).setValue(true, forKey: "isDeleted")
            realm.objects(StoredOPDSServer.self).setValue(true, forKey: "isDeleted")
            realm.delete(realm.objects(StoredChapterData.self))
            
            let downloadedChapters = realm
                .objects(ICDMDownloadObject.self)
                .where { $0.status == .completed }
                .compactMap { $0.chapter }
            
            let idSet = Array(Set(downloadedChapters.map { $0.contentIdentifier.id }))
            let chapterIdSet = Array(downloadedChapters.map({ $0.id }))
            
            realm.objects(StoredContent.self).where { !$0.id.in(idSet) }.setValue(true, forKey: "isDeleted")
            realm.objects(StoredChapter.self).where { !$0.id.in(chapterIdSet) }.setValue(true, forKey: "isDeleted")
            
            if let libraryEntries = backup.library {
                let contents = libraryEntries.compactMap { $0.content }
                realm.add(contents, update: .all)
                realm.add(libraryEntries, update: .all)
            }
            
            if let collections = backup.collections {
                realm.add(collections, update: .all)
            }
            
            if let readLater = backup.readLater {
                realm.add(readLater, update: .all)
            }
            
            if let runnerLists = backup.runnerLists {
                realm.add(runnerLists, update: .all)
            }
            
            if let markers = backup.progressMarkers {
                realm.add(markers, update: .all)
            }
        }
    }
    
    func restore(from url: URL) async throws {
        // Load
        var backup: Backup?
        do {
            backup = try Backup.load(from: url)
        } catch {
            Logger.shared.error("[Backups] \(error.localizedDescription)")
            throw error
        }
        
        guard let backup = backup else {
            throw BackUpError.InvalidBackup
        }
        
        let runners = backup.runners?.map { ($0.id, $0.listURL) } ?? []
        
        // Install
        restoreDB(backup: backup)
        
        guard !runners.isEmpty else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for runner in runners {
                guard let url = URL(string: runner.1) else { return }
                group.addTask {
                    do {
                        try await SourceManager.shared.importRunner(from: url, with: runner.0)
                    } catch {
                        Logger.shared.error("Failed to install runner of \(runner.0). \(error)")
                    }
                }
            }
        }
    }
    
    enum BackUpError: Error {
        case FailedToImport, InvalidBackup, EmptyBackup, FileExists
    }
}

extension DataManager {
    func getAllLibraryObjects() -> Backup {
        let realm = try! Realm()
        
        let libraryEntries = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil && !$0.isDeleted }
        
        let collections = realm
            .objects(LibraryCollection.self)
            .where({ !$0.isDeleted })
        
        let readLater = realm
            .objects(ReadLater.self)
            .where { $0.content != nil && !$0.isDeleted }
        
        let progressMarkers = realm
            .objects(ProgressMarker.self)
            .where({ $0.currentChapter != nil && $0.currentChapter.content != nil && !$0.isDeleted })
        
        let lists = realm
            .objects(StoredRunnerList.self)
            .where({ !$0.isDeleted })
        
        let runners = realm
            .objects(StoredRunnerObject.self)
            .where({ !$0.isDeleted })
        
        var backup = Backup()
        backup.readLater = readLater.toArray()
        backup.progressMarkers = progressMarkers.toArray()
        backup.library = libraryEntries.toArray()
        backup.collections = collections.toArray()
        backup.runnerLists = lists.toArray()
        backup.runners = runners.toArray()
        
        return backup
    }
}
