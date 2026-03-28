//
//  TokenIndicator.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct TokenIndicator: View {
    let tokensRemaining: Int
    let maxTokens: Int
    
    init(tokensRemaining: Int, maxTokens: Int = 2) {
        self.tokensRemaining = tokensRemaining
        self.maxTokens = maxTokens
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "snowflake")
                .foregroundStyle(Color.tealAccent)
            
            HStack(spacing: 2) {
                ForEach(0..<maxTokens, id: \.self) { index in
                    Image(systemName: index < tokensRemaining ? "circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(index < tokensRemaining ? Color.tealAccent : Color.gray.opacity(0.3))
                }
            }
        }
    }
}

#Preview {
    VStack {
        TokenIndicator(tokensRemaining: 2)
        TokenIndicator(tokensRemaining: 1)
        TokenIndicator(tokensRemaining: 0)
    }
}
