//
//  HTTPConfiguratorMethod.swift
//  MKit
//
//  Created by Martin Prusa on 8/17/19.
//

import Foundation

public enum HTTPConfiguratorMethod: String {
    case options = "OPTIONS"
    case get     = "GET"
    case head    = "HEAD"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case trace   = "TRACE"
    case connect = "CONNECT"
}
