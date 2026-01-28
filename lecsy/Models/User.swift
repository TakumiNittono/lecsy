//
//  User.swift
//  lecsy
//
//  Created on 2026/01/27.
//

import Foundation

/// ユーザーモデル
struct User: Codable {
    let id: UUID
    let email: String?
    let name: String?
    
    init(id: UUID, email: String? = nil, name: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
    }
}
