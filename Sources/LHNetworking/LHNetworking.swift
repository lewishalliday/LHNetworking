// LHNetworking
// Core umbrella file kept intentionally minimal.
// Public symbols are declared in dedicated files for clarity.
// This file exists to keep the module tree tidy.

import Foundation
@_exported import struct Foundation.URL
@_exported import struct Foundation.Data

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
