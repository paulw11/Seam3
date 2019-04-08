//
//  SMLogger.swift
//  WebVideoCast
//
//  Created by hugo on 11/7/18.
//  Copyright © 2018 Swishly. All rights reserved.
//

import Foundation
import os.log

public enum SMLogType {
  case defaultType
  case info
  case debug
  case error
  case fault
}

public protocol SMLogDelegate: class {
  func log(_ message: @autoclosure() -> String, type: SMLogType)
  func info(_ message: @autoclosure() -> String)
  func debug(_ message: @autoclosure() -> String)
  func error(_ message: @autoclosure() -> String)
  func fault(_ message: @autoclosure() -> String)
}

extension SMLogDelegate {
  func info(_ message: @autoclosure() -> String) {
    self.log(message(), type: .info)
  }
  func debug(_ message: @autoclosure() -> String) {
    self.log(message(), type: .debug)
  }
  func error(_ message: @autoclosure() -> String) {
    self.log(message(), type: .error)
  }
  func fault(_ message: @autoclosure() -> String) {
    self.log(message(), type: .fault)
  }
}

class SMLogger: SMLogDelegate {
  static let sharedInstance = SMLogger()
  func log(_ message: @autoclosure() -> String, type: SMLogType = .defaultType) {
    let messageTemplate: StaticString = "%{private}@"
    switch type {
    case .defaultType:
        os_log(messageTemplate, message())
    case .info:
        os_log(messageTemplate, message()) // Use of unresolved identifier 'os_log_info' (Xcode10.1)??
    case .debug:
        os_log(messageTemplate, message()) // Use of unresolved identifier 'os_log_debug' ??
    case .error:
        os_log(messageTemplate, message()) // Use of unresolved identifier 'os_log_error' ??
    case .fault:
        os_log(messageTemplate, message()) // Use of unresolved identifier 'os_log_fault' ??
    }
  }
}
