//
//  Extensions.swift
//
//
//  Created by Kevin Hinkson on 2022-04-13.
//

import Foundation

extension String {
    public var iso8601withFractionalSeconds: Date? {
        Formatter.iso8601withFractionalSeconds.date(from: self)
    }
}

extension Formatter {
    static let iso8601withFractionalSeconds = ISO8601DateFormatter([.withInternetDateTime, .withFractionalSeconds])
}

extension ISO8601DateFormatter {
    convenience init(_ formatOptions: Options, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
        self.init()
        self.formatOptions = formatOptions
        self.timeZone = timeZone
    }
}

extension Date {
    public var iso8601withFractionalSeconds: String { return Formatter.iso8601withFractionalSeconds.string(from: self) }
    
    public func unixTimestampInMilliseconds() -> Double {
        return self.timeIntervalSince1970 * 1000
    }
}

public enum DoubleError: LocalizedError {
    case millisecondTimestampFormatError(UUID, Double)
    
    public var errorDescription: String? {
        switch self {
        case .millisecondTimestampFormatError(_, let doubleValue):
            return "Unable to convert a String date timestamp to a unix Double timestamp\(divider)date:\(doubleValue)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case
                .millisecondTimestampFormatError(let errorID, _):
            return errorID.uuidString
        }
    }
}

extension Double {
    public func dateFromUnixTimestampInMilliseconds() throws -> Date? {
        guard let timestamp: Double = .init(self) else {
            throw DoubleError.millisecondTimestampFormatError(.init(), self)
        }
        let interval: TimeInterval = .init(timestamp/1000)
        return .init(timeIntervalSince1970: interval)
    }
}
