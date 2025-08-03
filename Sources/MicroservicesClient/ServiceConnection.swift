import Foundation
import Logging

/// Represents a connection to a service instance
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class ServiceConnection {
    
    // MARK: - Properties
    
    /// The service instance this connection is for
    public let instance: ServiceInstance
    
    /// Connection status
    public private(set) var status: ConnectionStatus
    
    /// Connection creation time
    public let createdAt: Date
    
    /// Last activity time
    public private(set) var lastActivity: Date
    
    /// Connection statistics
    public private(set) var statistics: ConnectionStatistics
    
    /// Logger for debugging
    private let logger: Logger
    
    // MARK: - Initialization
    
    /// Initialize a service connection
    /// - Parameter instance: The service instance to connect to
    public init(instance: ServiceInstance) {
        self.instance = instance
        self.status = .connecting
        self.createdAt = Date()
        self.lastActivity = Date()
        self.statistics = ConnectionStatistics()
        self.logger = Logger(label: "com.microservices.connection")
        
        logger.info("Service connection created for instance: \(instance.id)")
    }
    
    // MARK: - Public Methods
    
    /// Update connection status
    /// - Parameter newStatus: The new connection status
    public func updateStatus(_ newStatus: ConnectionStatus) {
        let oldStatus = status
        status = newStatus
        lastActivity = Date()
        
        logger.debug("Connection status updated: \(oldStatus) -> \(newStatus) for instance: \(instance.id)")
    }
    
    /// Record a successful request
    public func recordSuccess() {
        statistics.successfulRequests += 1
        statistics.totalRequests += 1
        lastActivity = Date()
        
        logger.debug("Recorded successful request for instance: \(instance.id)")
    }
    
    /// Record a failed request
    public func recordFailure() {
        statistics.failedRequests += 1
        statistics.totalRequests += 1
        lastActivity = Date()
        
        logger.debug("Recorded failed request for instance: \(instance.id)")
    }
    
    /// Get connection health score
    /// - Returns: Health score between 0.0 and 1.0
    public func getHealthScore() -> Double {
        guard statistics.totalRequests > 0 else { return 1.0 }
        
        let successRate = Double(statistics.successfulRequests) / Double(statistics.totalRequests)
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivity)
        
        // Penalize connections that haven't been used recently
        let timePenalty = min(timeSinceLastActivity / 300.0, 0.5) // 5 minutes max penalty
        
        return max(0.0, successRate - timePenalty)
    }
    
    /// Check if connection is healthy
    /// - Returns: True if connection is healthy
    public func isHealthy() -> Bool {
        return status == .connected && getHealthScore() > 0.5
    }
    
    /// Get connection statistics
    /// - Returns: Current connection statistics
    public func getStatistics() -> ConnectionStatistics {
        return statistics
    }
    
    /// Reset connection statistics
    public func resetStatistics() {
        statistics = ConnectionStatistics()
        logger.info("Connection statistics reset for instance: \(instance.id)")
    }
}

// MARK: - Supporting Types

/// Connection status
public enum ConnectionStatus: String, CaseIterable {
    case connecting = "connecting"
    case connected = "connected"
    case disconnected = "disconnected"
    case failed = "failed"
    
    public var description: String {
        switch self {
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Failed"
        }
    }
}

/// Connection statistics
public struct ConnectionStatistics {
    public var totalRequests: Int
    public var successfulRequests: Int
    public var failedRequests: Int
    public var averageResponseTime: TimeInterval
    
    public init(
        totalRequests: Int = 0,
        successfulRequests: Int = 0,
        failedRequests: Int = 0,
        averageResponseTime: TimeInterval = 0.0
    ) {
        self.totalRequests = totalRequests
        self.successfulRequests = successfulRequests
        self.failedRequests = failedRequests
        self.averageResponseTime = averageResponseTime
    }
    
    public var successRate: Double {
        guard totalRequests > 0 else { return 1.0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    public var failureRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(failedRequests) / Double(totalRequests)
    }
} 