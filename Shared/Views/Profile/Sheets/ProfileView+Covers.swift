//
//  ProfileView+Covers.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import AlertToast
import Kingfisher
import NukeUI
import SwiftUI

extension ProfileView {
    struct CoversSheet: View {
        var covers: [String]
        @Environment(\.presentationMode) var presentMode
        @ObservedObject var toastManager = ToastManager()
        var body: some View {
            NavigationView {
                TabView {
                    ForEach(covers, id: \.self) { cover in

                        LazyImage(url: URL(string: cover), resizingMode: .aspectFit)
                            .contextMenu {
                                Button {
                                    handleSaveEvent(for: cover)
                                } label: {
                                    Label("Save Image", systemImage: "square.and.arrow.down")
                                }
                            }
                            .cornerRadius(5)
                            .padding()
                            .tag(cover)
                    }
                }

                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            presentMode.wrappedValue.dismiss()
                        }
                    }
                }
                .tabViewStyle(.page)
                .navigationTitle("Covers")
                .navigationViewStyle(.stack)
            }

            .toast(isPresenting: $toastManager.show) { toastManager.toast }
        }

        func handleSaveEvent(for cover: String) {
            //            toastManager.setToast(toast: .init(type: .loading, title: "Saving"))
            KingfisherManager.shared.retrieveImage(with: URL(string: cover)!) { result in
                switch result {
                case let .failure(error):
                    toastManager.setError(error: error)
                case let .success(KIR):
                    STTPhotoAlbum.shared.save(KIR.image)
                    toastManager.setToast(toast: .init(type: .complete(.green), title: "Saved"))
                }
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var itemsToShare: [Any]
    var servicesToShareItem: [UIActivity]? = nil
    func makeUIViewController(context _: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: itemsToShare, applicationActivities: servicesToShareItem)
        return controller
    }

    func updateUIViewController(_: UIActivityViewController,
                                context _: UIViewControllerRepresentableContext<ActivityViewController>) {}
}