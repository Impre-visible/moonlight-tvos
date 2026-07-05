//
//  AppCardView.swift
//  Moonlight
//
//  Created by Roméo on 05/07/2026.
//  Copyright © 2026 Moonlight Game Streaming Project. All rights reserved.
//
import SwiftUI
import UIKit
import ObjectiveC

struct AppCardView: View {
    var title: String
    var image: UIImage?
    var isPlaying: Bool
    
    var body: some View {
        ZStack {
            // Le Fond
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 265)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            // Le dégradé
            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            
            // L'icône Play
            if isPlaying {
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 2)
            }
        }
        .frame(width: 200, height: 265)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// Stable key address for the associated object that retains the UIHostingController.
private var _hostingControllerAssocKey: UInt8 = 0

// 2. Le Pont pour l'Objective-C (Inchangé)
@objc public class LiquidGlassCardBridge: NSObject {
    @objc public static func createCard(title: String, image: UIImage?, isPlaying: Bool) -> UIView {
        let cardView = AppCardView(title: title, image: image, isPlaying: isPlaying)

        let hostingController = UIHostingController(rootView: cardView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Bind the controller's lifetime to the view's lifetime.
        // The view retains the controller via the associated object; the controller
        // already retains its view normally. Both are released together once the
        // view leaves its superview and no other strong reference remains.
        objc_setAssociatedObject(
            hostingController.view,
            &_hostingControllerAssocKey,
            hostingController,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return hostingController.view
    }
}
