import Foundation
import Logging
import Collections

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class CircuitBreaker {
    
    // MARK: - Properties
    
    private let configuration: CircuitBreakerConfiguration
    private let logger: Logger
    
    /// Circuit state for each service
    private var circuitStates: [String: CircuitState] = [:]
    
    /// Failure counts for each service
    private var failureCounts: [String: Int] = [:]
    
    /// Last failure time for each service
    private var lastFailureTimes: [String: Date] = [:]
    
    /// Success counts for each service
    private var successCounts: [String: Int] = [:]
    
    /// Request counts for each service
    private var requestCounts: [String: Int] = [:]
    
    // MARK: - Initialization
    
    public init(configuration: CircuitBreakerConfiguration) {
        self.configuration = configuration
        self.logger = Logger(label: "com.microservices.circuit.breaker")
        logger.info("CircuitBreaker initialized with configuration: \(configuration)")
    }
    
    // MARK: - Public Methods
    
    /// Check if circuit is closed for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: True if circuit is closed (requests allowed)
    public func isClosed(for serviceName: String) -> Bool {
        let state = getCircuitState(for: serviceName)
        return state == .closed
    }
    
    /// Check if circuit is open for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: True if circuit is open (requests blocked)
    public func isOpen(for serviceName: String) -> Bool {
        let state = getCircuitState(for: serviceName)
        return state == .open
    }
    
    /// Check if circuit is half-open for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: True if circuit is half-open (limited requests allowed)
    public func isHalfOpen(for serviceName: String) -> Bool {
        let state = getCircuitState(for: serviceName)
        return state == .halfOpen
    }
    
    /// Record a successful request
    /// - Parameter serviceName: The name of the service
    public func recordSuccess(for serviceName: String) {
        successCounts[serviceName, default: 0] += 1
        requestCounts[serviceName, default: 0] += 1
        
        let state = getCircuitState(for: serviceName)
        if state == .halfOpen {
            // If we have enough successful requests, close the circuit
            let successCount = successCounts[serviceName, default: 0]
            if successCount >= configuration.successThreshold {
                circuitStates[serviceName] = .closed
                failureCounts[serviceName] = 0
                logger.info("Circuit closed for service: \(serviceName)")
            }
        }
        
        logger.debug("Recorded success for service: \(serviceName)")
    }
    
    /// Record a failed request
    /// - Parameter serviceName: The name of the service
    public func recordFailure(for serviceName: String) {
        failureCounts[serviceName, default: 0] += 1
        requestCounts[serviceName, default: 0] += 1
        lastFailureTimes[serviceName] = Date()
        
        let state = getCircuitState(for: serviceName)
        let failureCount = failureCounts[serviceName, default: 0]
        
        if state == .closed && failureCount >= configuration.failureThreshold {
            // Open the circuit
            circuitStates[serviceName] = .open
            logger.warning("Circuit opened for service: \(serviceName) after \(failureCount) failures")
        } else if state == .halfOpen {
            // If we fail in half-open state, open the circuit again
            circuitStates[serviceName] = .open
            logger.warning("Circuit reopened for service: \(serviceName)")
        }
        
        logger.debug("Recorded failure for service: \(serviceName)")
    }
    
    /// Get circuit state for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: The current circuit state
    public func getCircuitState(for serviceName: String) -> CircuitState {
        let currentState = circuitStates[serviceName, default: .closed]
        
        // Check if we should transition from open to half-open
        if currentState == .open {
            if let lastFailureTime = lastFailureTimes[serviceName] {
                let timeSinceLastFailure = Date().timeIntervalSince(lastFailureTime)
                if timeSinceLastFailure >= configuration.timeout {
                    circuitStates[serviceName] = .halfOpen
                    successCounts[serviceName] = 0
                    logger.info("Circuit moved to half-open for service: \(serviceName)")
                    return .halfOpen
                }
            }
        }
        
        return currentState
    }
    
    /// Get circuit breaker statistics for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: Circuit breaker statistics
    public func getStatistics(for serviceName: String) -> CircuitBreakerStatistics {
        let totalRequests = requestCounts[serviceName, default: 0]
        let totalFailures = failureCounts[serviceName, default: 0]
        let totalSuccesses = successCounts[serviceName, default: 0]
        let failureRate = totalRequests > 0 ? Double(totalFailures) / Double(totalRequests) : 0.0
        
        return CircuitBreakerStatistics(
            serviceName: serviceName,
            state: getCircuitState(for: serviceName),
            totalRequests: totalRequests,
            totalFailures: totalFailures,
            totalSuccesses: totalSuccesses,
            failureRate: failureRate,
            lastFailureTime: lastFailureTimes[serviceName]
        )
    }
    
    /// Reset circuit breaker for a service
    /// - Parameter serviceName: The name of the service
    public func reset(for serviceName: String) {
        circuitStates[serviceName] = .closed
        failureCounts[serviceName] = 0
        successCounts[serviceName] = 0
        requestCounts[serviceName] = 0
        lastFailureTimes.removeValue(forKey: serviceName)
        
        logger.info("Circuit breaker reset for service: \(serviceName)")
    }
    
    /// Update circuit breaker configuration
    /// - Parameter newConfiguration: The new configuration
    public func updateConfiguration(_ newConfiguration: CircuitBreakerConfiguration) {
        // Update configuration
        // Note: In a real implementation, this would update the configuration property
        logger.info("Circuit breaker configuration updated")
    }
    
    // MARK: - Private Methods
    
    private func shouldAllowRequest(for serviceName: String) -> Bool {
        let state = getCircuitState(for: serviceName)
        
        switch state {
        case .closed:
            return true
        case .open:
            return false
        case .halfOpen:
            // Allow limited requests in half-open state
            let requestCount = requestCounts[serviceName, default: 0]
            return requestCount < configuration.halfOpenRequestLimit
        }
    }
}

// MARK: - Supporting Types

/// Circuit breaker states
public enum CircuitState: String, CaseIterable {
    case closed = "closed"
    case open = "open"
    case halfOpen = "half_open"
    
    public var description: String {
        switch self {
        case .closed:
            return "Closed"
        case .open:
            return "Open"
        case .halfOpen:
            return "Half-Open"
        }
    }
}

/// Circuit breaker configuration
public struct CircuitBreakerConfiguration {
    /// Number of failures before opening the circuit
    public let failureThreshold: Int
    
    /// Timeout before moving from open to half-open
    public let timeout: TimeInterval
    
    /// Number of successful requests to close the circuit
    public let successThreshold: Int
    
    /// Maximum number of requests allowed in half-open state
    public let halfOpenRequestLimit: Int
    
    /// Whether to enable circuit breaker
    public let enabled: Bool
    
    public init(
        failureThreshold: Int = 5,
        timeout: TimeInterval = 60.0,
        successThreshold: Int = 3,
        halfOpenRequestLimit: Int = 1,
        enabled: Bool = true
    ) {
        self.failureThreshold = failureThreshold
        self.timeout = timeout
        self.successThreshold = successThreshold
        self.halfOpenRequestLimit = halfOpenRequestLimit
        self.enabled = enabled
    }
}

/// Circuit breaker statistics
public struct CircuitBreakerStatistics {
    public let serviceName: String
    public let state: CircuitState
    public let totalRequests: Int
    public let totalFailures: Int
    public let totalSuccesses: Int
    public let failureRate: Double
    public let lastFailureTime: Date?
    
    public init(
        serviceName: String,
        state: CircuitState,
        totalRequests: Int,
        totalFailures: Int,
        totalSuccesses: Int,
        failureRate: Double,
        lastFailureTime: Date?
    ) {
        self.serviceName = serviceName
        self.state = state
        self.totalRequests = totalRequests
        self.totalFailures = totalFailures
        self.totalSuccesses = totalSuccesses
        self.failureRate = failureRate
        self.lastFailureTime = lastFailureTime
    }
} 