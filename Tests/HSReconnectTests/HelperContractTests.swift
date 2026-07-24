import Foundation
import XCTest

final class HelperContractTests: XCTestCase {
  func testHelperTimingIsFixedForPublicRelease() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let helperURL =
      repositoryRoot
      .appendingPathComponent("Support")
      .appendingPathComponent("hsreconnect-helper")
    let helper = try String(contentsOf: helperURL, encoding: .utf8)

    XCTAssertTrue(helper.contains("SECONDS_TO_BLOCK=3"))
    XCTAssertTrue(helper.contains("IDLE_SECONDS=10"))
    XCTAssertFalse(helper.contains("--seconds)"))
    XCTAssertFalse(helper.contains("--idle-seconds)"))
    XCTAssertTrue(helper.hasPrefix("#!/bin/bash\n"))
    XCTAssertTrue(helper.contains("-L \"$EXECUTABLE\""))
    XCTAssertTrue(
      helper.contains(
        "/usr/bin/codesign --verify --strict \"$canonical_executable\""
      )
    )
  }
}
