//
//  Modifiers.swift
//  xClient6001
//
//  Created by Douglas Adams on 3/5/21.
//  Copyright © 2020-2021 Douglas Adams. All rights reserved.
//

import SwiftUI

public struct ClearButton: ViewModifier {
    var text: Binding<String>
    var trailing: Bool

    public init(boundText: Binding<String>, trailing: Bool = true) {
        self.text = boundText
        self.trailing = trailing
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: trailing ? .trailing : .leading) {
            content

            if !text.wrappedValue.isEmpty {
                Image(systemName: "x.circle")
                    .resizable()
                    .frame(width: 17, height: 17)
                    .onTapGesture {
                        text.wrappedValue = ""
                    }
            }
        }
    }
}
