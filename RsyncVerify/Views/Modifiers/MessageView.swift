//
//  MessageView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 10/01/2026.
//

import SwiftUI

struct MessageView: View {
    @Environment(\.colorScheme) var colorScheme

    private var mytext: String
    private var textsize: Font

    var body: some View {
        if colorScheme == .dark {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.3))
                Text(mytext)
                    // .font(.caption2)
                    .font(textsize)
                    .foregroundColor(Color.green)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .allowsTightening(false)
                    .minimumScaleFactor(0.5)
            }
            .frame(height: 30, alignment: .center)
            .background(RoundedRectangle(cornerRadius: 25).stroke(Color.gray, lineWidth: 1))
            .padding()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.3))
                Text(mytext)
                    // .font(.caption2)
                    .font(textsize)
                    .foregroundColor(Color.blue)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .allowsTightening(false)
                    .minimumScaleFactor(0.5)
            }
            .frame(height: 30, alignment: .center)
            .background(RoundedRectangle(cornerRadius: 25).stroke(Color.gray, lineWidth: 1))
            .padding()
        }
    }

    init(mytext: String, size: Font) {
        self.mytext = mytext
        textsize = size
    }
}
