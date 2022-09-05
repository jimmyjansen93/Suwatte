//
//  ProfileView+Header.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Kingfisher
import RealmSwift
import SwiftUI

private typealias Skeleton = ProfileView.Skeleton
extension Skeleton {
    struct Header: View {
        @EnvironmentObject var entry: StoredContent
        @EnvironmentObject var model: ProfileView.ViewModel
        @State var presentThumbnails = false

        var ImageWidth = 150.0
        var body: some View {
            HStack {
                CoverImage

                VStack(alignment: .leading, spacing: 10) {
                    if entry.creators.count > 0 {
                        Text("By: \(entry.creators.joined(separator: ", "))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                    }

                    Status
                    Text(model.source.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()
                    ActionButtons()
                }
                .padding(.vertical, 5)
                Spacer()
            }
            .frame(height: ImageWidth * 1.5)
            .padding(.horizontal)
        }
    }
}

// MARK: Thumbnail

extension Skeleton.Header {
    var cover: URL {
        let str = entry.covers.first ?? DEFAULT_THUMB

        return URL(string: str)!
    }

    var CoverImage: some View {
        STTImageView(url: URL(string: entry.cover), identifier: entry.ContentIdentifier)
            .frame(width: ImageWidth, height: ImageWidth * 1.5)
            .cornerRadius(7)
            .shadow(radius: 3)
            .onTapGesture {
                presentThumbnails.toggle()
            }
            .fullScreenCover(isPresented: $presentThumbnails) {
                ProfileView.CoversSheet(covers: entry.covers.toArray())
            }
    }
}

// MARK: Status

extension Skeleton.Header {
    var Status: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
            Text("\(entry.status.description)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundColor(entry.status.color)
    }
}

// MARK: Actions

private extension Skeleton {
    struct ActionButtons: View {
        @State var currentAction: Option?
        @EnvironmentObject var entry: StoredContent
        @ObservedResults(LibraryEntry.self) var libraryEntries
        @State var presentSafariView = false
        @EnvironmentObject var model: ProfileView.ViewModel

        var body: some View {
            HStack(alignment: .center, spacing: 30) {
                ForEach(actions, id: \.option) { action in

                    Button {
                        switch action.option {
                        case .COLLECTIONS:
                            if !EntryInLibrary {
                                DataManager.shared.toggleLibraryState(for: entry)
                            }
                            model.presentCollectionsSheet.toggle()
                        case .TRACKERS: model.presentTrackersSheet.toggle()
                        case .WEBVIEW: model.presentSafariView.toggle()
                        case .BOOKMARKS: model.presentBookmarksSheet.toggle()
                        }
                    } label: {
                        Image(systemName: action.imageName)
                    }
                }
            }

            .font(.title2.weight(.light))
        }

        var EntryInLibrary: Bool {
            libraryEntries
                .where { $0._id == model.sttIdentifier().id }
                .count >= 1
        }
    }
}

private extension Skeleton.ActionButtons {
    var actions: [Action] {
        [.init(imageName: EntryInLibrary ? "folder.fill" : "folder.badge.plus", option: .COLLECTIONS),
         .init(imageName: "checklist", option: .TRACKERS),
         .init(imageName: "bookmark", option: .BOOKMARKS),
         .init(imageName: "globe", option: .WEBVIEW)]
    }

    enum Option: Identifiable {
        case COLLECTIONS, BOOKMARKS, TRACKERS, WEBVIEW

        var id: Int {
            hashValue
        }
    }

    struct Action {
        var imageName: String
        var option: Option
    }
}