//
//  lecsyTests.swift
//  lecsyTests
//
//  Created by Takuminittono on 2026/01/26.
//

import Testing
@testable import lecsy

struct lecsyTests {

    @Test func appImportsSuccessfully() async throws {
        // Verify the module can be imported and basic types are accessible
        let lecture = Lecture(title: "Smoke Test", duration: 1)
        #expect(lecture.title == "Smoke Test")
    }
}
