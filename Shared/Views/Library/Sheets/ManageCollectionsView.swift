//
//  ManageCollectionsView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-08.
//

import RealmSwift
import SwiftUI

extension LibraryView {
    struct ManageCollectionsView: View {
        @Environment(\.presentationMode) var presentationMode
        @ObservedResults(LibraryCollection.self, sortDescriptor: SortDescriptor(keyPath: "order", ascending: true)) var collections

        var body: some View {
            NavigationView {
                List {
                    AdditionSection
                    EditorSection
                }
                .navigationTitle("Collections")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: {
                    EditButton()
                })
                .closeButton()
            }
        }
    }
}

private typealias MCV = LibraryView.ManageCollectionsView
extension MCV {
    var AdditionSection: some View {
        AddCollectionView()
    }
}

extension MCV {
    var EditorSection: some View {
        Section {
            ForEach(collections) { collection in
                NavigationLink {
                    CollectionManagementView(collection: collection, collectionName: collection.name)
                } label: {
                    Text(collection.name)
                }
            }
            .onDelete(perform: $collections.remove)
            .onMove(perform: move)
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        var arr = Array(collections)
        arr.move(fromOffsets: source, toOffset: destination)
        DataManager.shared.reorderCollections(arr)
    }
}

extension MCV {
    struct AddCollectionView: View {
        @State var name: String = ""

        var body: some View {
            Section {
                TextField("Collection Name", text: $name)
                    .onSubmit {
                        addCollection()
                    }
                Button { addCollection() }
                    label: {
                        HStack {
                            Spacer()
                            Text("Add Collection")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NeutralButtonStyle())
            }
        }

        func addCollection() {
            if name.isEmpty {
                return
            }
            DataManager.shared.addCollection(withName: name)
            name = ""
        }
    }
}

// MARK: Edit View

extension MCV {
    struct CollectionEditView: View {
        @State var name: String
        var collection: LibraryCollection
        @State var showDone = false
        @Binding var editting: Bool
        var body: some View {
            HStack {
                TextField("Enter Name", text: $name, onEditingChanged: { change in

                    if change {
                        withAnimation {
                            editting = false
                            showDone = true
                        }
                    } else {
                        withAnimation {
                            showDone = false
                        }
                    }

                })
                if showDone {
                    Button("Done") {
                        if !name.isEmpty {
                            DataManager.shared.renameCollection(collection, name)
                        }
                        resign()
                    }
                }
            }
        }

        func resign() {
            withAnimation {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showDone = false
                editting = true
            }
        }
    }
}