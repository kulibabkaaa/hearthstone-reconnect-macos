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
    XCTAssertTrue(helper.contains("--ignore-resources"))
    XCTAssertTrue(
      helper.contains(
        "--test-requirement=\"$HEARTHSTONE_REQUIREMENT\""
      )
    )
    XCTAssertTrue(
      helper.contains(
        "anchor apple generic and identifier "
          + "\"unity.Blizzard Entertainment.Hearthstone\" "
          + "and certificate leaf[subject.OU] = \"G847MC6JZ5\""
      )
    )
  }
}
