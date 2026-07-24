import Foundation

private let ipv4Expression = try! NSRegularExpression(
  pattern: #"(?:\d{1,3}\.){3}\d{1,3}"#
)

private let ipv6Expression = try! NSRegularExpression(
  pattern: #"(?<![A-Fa-f0-9:])(?:[A-Fa-f0-9]{0,4}:){2,8}[A-Fa-f0-9]{0,4}(?![A-Fa-f0-9:])"#
)

func redactSensitiveNetworkDetails(_ value: String) -> String {
  let fullRange = NSRange(value.startIndex..<value.endIndex, in: value)
  let withoutIPv4 = ipv4Expression.stringByReplacingMatches(
    in: value,
    range: fullRange,
    withTemplate: "[address]"
  )
  let ipv6Range = NSRange(withoutIPv4.startIndex..<withoutIPv4.endIndex, in: withoutIPv4)
  return ipv6Expression.stringByReplacingMatches(
    in: withoutIPv4,
    range: ipv6Range,
    withTemplate: "[address]"
  )
}

func shouldRemoveLog(modifiedAt: Date, now: Date = Date()) -> Bool {
  let retention = TimeInterval(AppConfiguration.logRetentionDays * 24 * 60 * 60)
  return now.timeIntervalSince(modifiedAt) > retention
}
