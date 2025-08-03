import Foundation
import Logging
import Collections

/// Metrics tracking for circuit breaker performance
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class CircuitBreakerMetrics {
    
    // MARK: - Properties
    
    /// Circuit state changes per service
    private var stateChanges: [String: [CircuitStateChange]] = [:]
    
    /// Request counts per service
    private var requestCounts: [String: Int] = [:]
    
    /// Success counts per service
    private var successCounts: [String: Int] = [:]
    
    /// Failure counts per service
    private var failureCounts: [String: Int] = [:]
    
    /// Time spent in each state per service
    private var stateDurations: [String: [CircuitState: TimeInterval]] = [:]
    
    /// Logger for debugging
    private let logger: Logger
    
    /// Metrics lock for thread safety
    private let metricsLock = NSLock()
    
    // MARK: - Initialization
    
    public init() {
        self.logger = Logger(label: "com.microservices.circuit.breaker.metrics")
        logger.info("CircuitBreakerMetrics initialized")
    }
    
    // MARK: - Public Methods
    
    /// Record a state change
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - fromState: The previous state
    ///   - toState: The new state
    ///   - timestamp: When the change occurred
    public func recordStateChange(
        for serviceName: String,
        fromState: CircuitState,
        toState: CircuitState,
        timestamp: Date = Date()
    ) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        if stateChanges[serviceName] == nil {
            stateChanges[serviceName] = []
        }
        
        let stateChange = CircuitStateChange(
            fromState: fromState,
            toState: toState,
            timestamp: timestamp
        )
        
        stateChanges[serviceName]?.append(stateChange)
        
        logger.debug("Recorded state change for \(serviceName): \(fromState.rawValue) -> \(toState.rawValue)")
    }
    
    /// Record a request
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - success: Whether the request was successful
    public func recordRequest(for serviceName: String, success: Bool) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        requestCounts[serviceName, default: 0] += 1
        
        if success {
            successCounts[serviceName, default: 0] += 1
        } else {
            failureCounts[serviceName, default: 0] += 1
        }
        
        logger.debug("Recorded request for \(serviceName): success=\(success)")
    }
    
    /// Record time spent in a state
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - state: The circuit state
    ///   - duration: Time spent in the state
    public func recordStateDuration(
        for serviceName: String,
        state: CircuitState,
        duration: TimeInterval
    ) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        if stateDurations[serviceName] == nil {
            stateDurations[serviceName] = [:]
        }
        
        stateDurations[serviceName]?[state, default: 0] += duration
        
        logger.debug("Recorded state duration for \(serviceName) in \(state.rawValue): \(duration)s")
    }
    
    /// Get metrics for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: Service circuit breaker metrics
    public func getServiceMetrics(for serviceName: String) -> ServiceCircuitBreakerMetrics? {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let requestCount = requestCounts[serviceName] ?? 0
        let successCount = successCounts[serviceName] ?? 0
        let failureCount = failureCounts[serviceName] ?? 0
        let stateChangeList = stateChanges[serviceName] ?? []
        let stateDurationMap = stateDurations[serviceName] ?? [:]
        
        guard requestCount > 0 else { return nil }
        
        let successRate = Double(successCount) / Double(requestCount)
        let failureRate = Double(failureCount) / Double(requestCount)
        
        let totalStateChanges = stateChangeList.count
        let lastStateChange = stateChangeList.last
        
        return ServiceCircuitBreakerMetrics(
            serviceName: serviceName,
            totalRequests: requestCount,
            successfulRequests: successCount,
            failedRequests: failureCount,
            successRate: successRate,
            failureRate: failureRate,
            totalStateChanges: totalStateChanges,
            lastStateChange: lastStateChange,
            stateDurations: stateDurationMap
        )
    }
    
    /// Get overall metrics
    /// - Returns: Overall circuit breaker metrics
    public func getOverallMetrics() -> OverallCircuitBreakerMetrics {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let totalRequests = requestCounts.values.reduce(0, +)
        let totalSuccesses = successCounts.values.reduce(0, +)
        let totalFailures = failureCounts.values.reduce(0, +)
        let totalServices = requestCounts.count
        let totalStateChanges = stateChanges.values.reduce(0) { $0 + $1.count }
        
        let overallSuccessRate = totalRequests > 0 ? Double(totalSuccesses) / Double(totalRequests) : 1.0
        let overallFailureRate = totalRequests > 0 ? Double(totalFailures) / Double(totalRequests) : 0.0
        
        return OverallCircuitBreakerMetrics(
            totalRequests: totalRequests,
            totalSuccesses: totalSuccesses,
            totalFailures: totalFailures,
            totalServices: totalServices,
            totalStateChanges: totalStateChanges,
            overallSuccessRate: overallSuccessRate,
            overallFailureRate: overallFailureRate
        )
    }
    
    /// Reset metrics for a service
    /// - Parameter serviceName: The name of the service
    public func resetMetrics(for serviceName: String) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        requestCounts.removeValue(forKey: serviceName)
        successCounts.removeValue(forKey: serviceName)
        failureCounts.removeValue(forKey: serviceName)
        stateChanges.removeValue(forKey: serviceName)
        stateDurations.removeValue(forKey: serviceName)
        
        logger.info("Metrics reset for service: \(serviceName)")
    }
    
    /// Reset all metrics
    public func resetAllMetrics() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        requestCounts.removeAll()
        successCounts.removeAll()
        failureCounts.removeAll()
        stateChanges.removeAll()
        stateDurations.removeAll()
        
        logger.info("All metrics reset")
    }
}

// MARK: - Supporting Types

/// Circuit state change record
public struct CircuitStateChange {
    public let fromState: CircuitState
    public let toState: CircuitState
    public let timestamp: Date
    
    public init(fromState: CircuitState, toState: CircuitState, timestamp: Date) {
        self.fromState = fromState
        self.toState = toState
        self.timestamp = timestamp
    }
}

/// Metrics for a specific service
public struct ServiceCircuitBreakerMetrics {
    public let serviceName: String
    public let totalRequests: Int
    public let successfulRequests: Int
    public let failedRequests: Int
    public let successRate: Double
    public let failureRate: Double
    public let totalStateChanges: Int
    public let lastStateChange: CircuitStateChange?
    public let stateDurations: [CircuitState: TimeInterval]
    
    public var averageTimeInClosed: TimeInterval {
        return stateDurations[.closed] ?? 0.0
    }
    
    public var averageTimeInOpen: TimeInterval {
        return stateDurations[.open] ?? 0.0
    }
    
    public var averageTimeInHalfOpen: TimeInterval {
        return stateDurations[.halfOpen] ?? 0.0
    }
    
    public init(
        serviceName: String,
        totalRequests: Int,
        successfulRequests: Int,
        failedRequests: Int,
        successRate: Double,
        failureRate: Double,
        totalStateChanges: Int,
        lastStateChange: CircuitStateChange?,
        stateDurations: [CircuitState: TimeInterval]
    ) {
        self.serviceName = serviceName
        self.totalRequests = totalRequests
        self.successfulRequests = successfulRequests
        self.failedRequests = failedRequests
        self.successRate = successRate
        self.failureRate = failureRate
        self.totalStateChanges = totalStateChanges
        self.lastStateChange = lastStateChange
        self.stateDurations = stateDurations
    }
}

/// Overall circuit breaker metrics
public struct OverallCircuitBreakerMetrics {
    public let totalRequests: Int
    public let totalSuccesses: Int
    public let totalFailures: Int
    public let totalServices: Int
    public let totalStateChanges: Int
    public let overallSuccessRate: Double
    public let overallFailureRate: Double
    
    public init(
        totalRequests: Int,
        totalSuccesses: Int,
        totalFailures: Int,
        totalServices: Int,
        totalStateChanges: Int,
        overallSuccessRate: Double,
        overallFailureRate: Double
    ) {
        self.totalRequests = totalRequests
        self.totalSuccesses = totalSuccesses
        self.totalFailures = totalFailures
        self.totalServices = totalServices
        self.totalStateChanges = totalStateChanges
        self.overallSuccessRate = overallSuccessRate
        self.overallFailureRate = overallFailureRate
    }
} 