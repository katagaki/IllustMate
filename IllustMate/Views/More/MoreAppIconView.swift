//
//  MoreAppIconView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2023/10/18.
//

import Komponents
import SwiftUI

struct MoreAppIconView: View {

    var icons: [AppIcon] = [AppIcon(previewImageName: "AppIconPreview.Default",
                                    name: "More.Customization.AppIcon.Default"),
                            AppIcon(previewImageName: "AppIconPreview.Default.Dark",
                                    name: "More.Customization.AppIcon.Default.Dark",
                                    iconName: "AppIcon.Default.Dark"),
                            AppIcon(previewImageName: "AppIconPreview.Plastic",
                                    name: "More.Customization.AppIcon.Plastic",
                                    iconName: "AppIcon.Plastic"),
                            AppIcon(previewImageName: "AppIconPreview.Plastic.Dark",
                                    name: "More.Customization.AppIcon.Plastic.Dark",
                                    iconName: "AppIcon.Plastic.Dark"),
                            AppIcon(previewImageName: "AppIconPreview.Pastel",
                                    name: "More.Customization.AppIcon.Pastel",
                                    iconName: "AppIcon.Pastel"),
                            AppIcon(previewImageName: "AppIconPreview.Pastel.Dark",
                                    name: "More.Customization.AppIcon.Pastel.Dark",
                                    iconName: "AppIcon.Pastel.Dark"),
                            AppIcon(previewImageName: "AppIconPreview.Leather",
                                    name: "More.Customization.AppIcon.Leather",
                                    iconName: "AppIcon.Leather")]

    var body: some View {
        List {
            ForEach(icons, id: \.name) { icon in
                Button {
                    UIApplication.shared.setAlternateIconName(icon.iconName)
                } label: {
                    ListAppIconRow(image: icon.previewImageName,
                                   text: NSLocalizedString(icon.name, comment: ""),
                                   iconToSet: icon.iconName)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.body)
        .listStyle(.insetGrouped)
        .navigationTitle("ViewTitle.More.Customization.AppIcon")
    }
}
