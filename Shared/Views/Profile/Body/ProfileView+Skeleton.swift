//
//  CPV+Body.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import BetterSafariView
import RealmSwift
import SwiftUI
extension ProfileView {
    struct Skeleton: View {
        @EnvironmentObject var viewModel: ProfileView.ViewModel
        @Environment(\.colorScheme) var colorScheme

        var safariHex: Color {
            colorScheme == .dark ? .init(hex: "6A5ACD") : .init(hex: "473C8A")
        }

        @EnvironmentObject var entry: StoredContent
        var body: some View {
            Main
                .sheet(isPresented: $viewModel.presentCollectionsSheet, content: {
                    ProfileView.Sheets.LibrarySheet()
                })
                .sheet(isPresented: $viewModel.presentTrackersSheet, content: {
                    ProfileView.Sheets.TrackersSheet()
                })
                .sheet(isPresented: $viewModel.presentBookmarksSheet, content: {
                    BookmarksView()
                })
                .safariView(isPresented: $viewModel.presentSafariView) {
                    SafariView(
                        url: URL(string: entry.url) ?? STTHost.notFound,
                        configuration: SafariView.Configuration(
                            entersReaderIfAvailable: false,
                            barCollapsingEnabled: true
                        )
                    )
                    .preferredControlAccentColor(safariHex)
                    .dismissButtonStyle(.close)
                }
                .transition(.opacity)
                .onDisappear {
                    self.viewModel.notificationToken?.invalidate()
                }
        }
    }
}

private extension ProfileView.Skeleton {
    var Main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Header()

                VStack(spacing: 5.5) {
                    Summary()
                    Divider()
                    CorePropertySection
                    Divider()
                }
                .padding(.horizontal)

                ChapterView.PreviewView()
                    .padding(.horizontal)

                AdditionalInfoView()
                AdditionalCoversView()
                    .padding(.horizontal)
                if let collections = viewModel.threadSafeContent?.includedCollections, !collections.isEmpty {
                    RelatedContentView(collections: collections)
                }
            }
            .padding(.vertical)
            .padding(.bottom, 70)
        }
        .overlay(alignment: .bottom) {
            BottomBar()
                .background(Color.systemBackground)
        }
    }
}