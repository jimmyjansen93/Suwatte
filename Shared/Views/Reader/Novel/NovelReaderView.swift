//
//  NovelReaderView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-23.
//

import SwiftUI

struct NovelReaderView: View {
    @StateObject var model: ViewModel
    @AppStorage(STTKeys.NovelFontColor) var fontColor: Color = .primary
    @AppStorage(STTKeys.NovelBGColor) var bgColor: Color = .primary
    @Preference(\.novelUseSystemColor) var useSystemColor

    var body: some View {
        LoadableView(loadMain, model.activeChapter.data) { _ in

            PagedViewer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .overlay {
            model.menuControl.menu ? MenuOverlay()
                .ignoresSafeArea() : nil
        }
        .background(useSystemColor ? .clear : bgColor)
        .gesture(model.ignore)
        .gesture(model.tap)

        .onChange(of: fontColor, perform: { _ in
            model.updatedPreferences()
        })
        .toast(isPresenting: $model.toast.show) {
            model.toast.toast
        }

        .animation(.default, value: model.menuControl.menu)
        .sheet(isPresented: $model.menuControl.settings, content: {
            SettingsView()
        })
        .sheet(isPresented: $model.menuControl.chapterList) {
            NavigationView {
                ChapterSheet()
                    .navigationTitle("Chapter List")
                    .navigationBarTitleDisplayMode(.inline)
                    .closeButton()
            }
        }
        .environmentObject(model)
    }

    func loadMain() {
        Task { @MainActor in
            await model.loadChapter(model.activeChapter.chapter, asNextChapter: true)
        }
    }
}

extension NovelReaderView.ViewModel {
    var tap: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { [unowned self] in
                if !activeChapter.data.LOADED { menuControl.toggleMenu() }
                else { handleNavigation($0.location) }
            }
    }

    var ignore: some Gesture {
        TapGesture(count: 2)
            .onEnded { _ in self.menuControl.hideMenu() }
    }
}