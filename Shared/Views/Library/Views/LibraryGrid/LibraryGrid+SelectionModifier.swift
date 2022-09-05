//
//  LibraryGrid+SelectionModifier.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import RealmSwift
import SwiftUI
extension LibraryView.LibraryGrid {
    struct SelectionModifier: ViewModifier {
        enum SelectionOption: Identifiable {
            var id: Int {
                return hashValue
            }

            case move, migrate
        }

        var entries: Results<LibraryEntry>
        @State var selectionOption: SelectionOption?
        @State var confirmRemoval = false
        @EnvironmentObject var model: ViewModel
        func body(content: Content) -> some View {
            content
                .sheet(item: $selectionOption, onDismiss: { model.selectedIndexes.removeAll() }) { option in
                    switch option {
                    case .move: MoveView(entries: entries)
                    case .migrate: Text("Migrate")
                    }
                }
                .alert("Remove From Library", isPresented: $confirmRemoval, actions: {
                    Button("Proceed", role: .destructive) {
                        removeFromLibrary()
                    }
                }, message: {
                    Text("Are you sure you want to remove these \(model.selectedIndexes.count) titles from your library?")

                })
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        if model.isSelecting {
                            Menu("Select") {
                                Button("Invert") { withAnimation { invert() }}
                                Button("Fill range") { withAnimation { fillRange() } }
                                Button("Deselect All") { withAnimation { deselectAll() } }
                                Button("Select All") { withAnimation { selectAll() } }
                            }

                            .padding()
                            Spacer()
                            if !model.selectedIndexes.isEmpty {
                                Menu("Options") {
                                    Button("Remove From Library") {
                                        confirmRemoval.toggle()
                                    }

                                    Button("Move to Collection(s)") {
                                        selectionOption = .move
                                    }
                                }
                                .padding()

//                                Spacer()
//                                Button("Migrate") {
//                                    selectionOption = .migrate
//                                }
//                                .padding()
                            }
                        }
                    }
                }
        }

        func selectAll() {
            model.selectedIndexes = Set(entries.indices.map { $0 })
        }

        func deselectAll() {
            model.selectedIndexes.removeAll()
        }

        func invert() {
            let all = Set(entries.indices)
            model.selectedIndexes = all.symmetricDifference(all)
        }

        func fillRange() {
            if model.selectedIndexes.isEmpty { return }

            let indexes = model.selectedIndexes.sorted()

            let start = indexes.first!
            let end = indexes.last!

            model.selectedIndexes = Set(entries.indices[start ... end])
        }

        func removeFromLibrary() {
            let targets = zip(entries.indices, entries)
                .filter { model.selectedIndexes.contains($0.0) }
                .map { $0.1._id }

            DataManager.shared.batchRemoveFromLibrary(with: Set(targets))

            DispatchQueue.main.async {
                model.selectedIndexes.removeAll()
            }
        }
    }
}