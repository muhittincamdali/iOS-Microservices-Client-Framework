import Foundation
import Logging
import Collections

/// Metrics tracking for load balancer performance
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class LoadBalancerMetrics {
    
    // MARK: - Properties
    
    /// Request counts per instance
    private var requestCounts: [String: [String: Int]] = [:]
    
    /// Response times per instance
    private var responseTimes: [String: [String: [TimeInterval]]] = [:]
    
    /// Error counts per instance
    private var errorCounts: [String: [String: Int]] = [:]
    
    /// Load balancer strategy usage
    private var strategyUsage: [LoadBalancingStrategy: Int] = [:]
    
    /// Logger for debugging
    private let logger: Logger
    
    /// Metrics lock for thread safety
    private let metricsLock = NSLock()
    
    // MARK: - Initialization
    
    public init() {
        self.logger = Logger(label: "com.microservices.load.balancer.metrics")
        logger.info("LoadBalancerMetrics initialized")
    }
    
    // MARK: - Public Methods
    
    /// Record a request for an instance
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - instanceId: The instance ID
    ///   - responseTime: The response time for the request
    ///   - success: Whether the request was successful
    public func recordRequest(
        for serviceName: String,
        instanceId: String,
        responseTime: TimeInterval,
        success: Bool
    ) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        // Record request count
        if requestCounts[serviceName] == nil {
            requestCounts[serviceName] = [:]
        }
        requestCounts[serviceName]?[instanceId, default: 0] += 1
        
        // Record response time
        if responseTimes[serviceName] == nil {
            responseTimes[serviceName] = [:]
        }
        if responseTimes[serviceName]?[instanceId] == nil {
            responseTimes[serviceName]?[instanceId] = []
        }
        responseTimes[serviceName]?[instanceId]?.append(responseTime)
        
        // Record error count
        if !success {
            if errorCounts[serviceName] == nil {
                errorCounts[serviceName] = [:]
            }
            errorCounts[serviceName]?[instanceId, default: 0] += 1
        }
        
        logger.debug("Recorded request for service: \(serviceName), instance: \(instanceId), responseTime: \(responseTime)s, success: \(success)")
    }
    
    /// Record strategy usage
    /// - Parameter strategy: The load balancing strategy used
    public func recordStrategyUsage(_ strategy: LoadBalancingStrategy) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        strategyUsage[strategy, default: 0] += 1
        logger.debug("Recorded strategy usage: \(strategy.rawValue)")
    }
    
    /// Get metrics for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: Service metrics
    public func getServiceMetrics(for serviceName: String) -> ServiceLoadBalancerMetrics? {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        guard let serviceRequestCounts = requestCounts[serviceName],
              let serviceResponseTimes = responseTimes[serviceName] else {
            return nil
        }
        
        var instanceMetrics: [String: InstanceLoadBalancerMetrics] = [:]
        
        for (instanceId, requestCount) in serviceRequestCounts {
            let responseTimeList = serviceResponseTimes[instanceId] ?? []
            let errorCount = errorCounts[serviceName]?[instanceId] ?? 0
            
            let avgResponseTime = responseTimeList.isEmpty ? 0.0 : responseTimeList.reduce(0, +) / Double(responseTimeList.count)
            let minResponseTime = responseTimeList.min() ?? 0.0
            let maxResponseTime = responseTimeList.max() ?? 0.0
            let successRate = requestCount > 0 ? Double(requestCount - errorCount) / Double(requestCount) : 1.0
            
            instanceMetrics[instanceId] = InstanceLoadBalancerMetrics(
                instanceId: instanceId,
                requestCount: requestCount,
                errorCount: errorCount,
                successRate: successRate,
                averageResponseTime: avgResponseTime,
                minResponseTime: minResponseTime,
                maxResponseTime: maxResponseTime,
                totalResponseTime: responseTimeList.reduce(0, +)
            )
        }
        
        return ServiceLoadBalancerMetrics(
            serviceName: serviceName,
            instanceMetrics: instanceMetrics,
            totalRequests: serviceRequestCounts.values.reduce(0, +),
            totalErrors: errorCounts[serviceName]?.values.reduce(0, +) ?? 0
        )
    }
    
    /// Get overall metrics
    /// - Returns: Overall load balancer metrics
    public func getOverallMetrics() -> OverallLoadBalancerMetrics {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let totalRequests = requestCounts.values.reduce(0) { $0 + $1.values.reduce(0, +) }
        let totalErrors = errorCounts.values.reduce(0) { $0 + $1.values.reduce(0, +) }
        let totalServices = requestCounts.count
        
        let allResponseTimes = responseTimes.values.flatMap { $0.values }.flatMap { $0 }
        let averageResponseTime = allResponseTimes.isEmpty ? 0.0 : allResponseTimes.reduce(0, +) / Double(allResponseTimes.count)
        
        return OverallLoadBalancerMetrics(
            totalRequests: totalRequests,
            totalErrors: totalErrors,
            totalServices: totalServices,
            averageResponseTime: averageResponseTime,
            strategyUsage: strategyUsage
        )
    }
    
    /// Reset metrics for a service
    /// - Parameter serviceName: The name of the service
    public func resetMetrics(for serviceName: String) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        requestCounts.removeValue(forKey: serviceName)
        responseTimes.removeValue(forKey: serviceName)
        errorCounts.removeValue(forKey: serviceName)
        
        logger.info("Metrics reset for service: \(serviceName)")
    }
    
    /// Reset all metrics
    public func resetAllMetrics() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        requestCounts.removeAll()
        responseTimes.removeAll()
        errorCounts.removeAll()
        strategyUsage.removeAll()
        
        logger.info("All metrics reset")
    }
}

// MARK: - Supporting Types

/// Metrics for a specific service
public struct ServiceLoadBalancerMetrics {
    public let serviceName: String
    public let instanceMetrics: [String: InstanceLoadBalancerMetrics]
    public let totalRequests: Int
    public let totalErrors: Int
    
    public var successRate: Double {
        guard totalRequests > 0 else { return 1.0 }
        return Double(totalRequests - totalErrors) / Double(totalRequests)
    }
    
    public var errorRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(totalErrors) / Double(totalRequests)
    }
    
    public init(
        serviceName: String,
        instanceMetrics: [String: InstanceLoadBalancerMetrics],
        totalRequests: Int,
        totalErrors: Int
    ) {
        self.serviceName = serviceName
        self.instanceMetrics = instanceMetrics
        self.totalRequests = totalRequests
        self.totalErrors = totalErrors
    }
}

/// Metrics for a specific instance
public struct InstanceLoadBalancerMetrics {
    public let instanceId: String
    public let requestCount: Int
    public let errorCount: Int
    public let successRate: Double
    public let averageResponseTime: TimeInterval
    public let minResponseTime: TimeInterval
    public let maxResponseTime: TimeInterval
    public let totalResponseTime: TimeInterval
    
    public init(
        instanceId: String,
        requestCount: Int,
        errorCount: Int,
        successRate: Double,
        averageResponseTime: TimeInterval,
        minResponseTime: TimeInterval,
        maxResponseTime: TimeInterval,
        totalResponseTime: TimeInterval
    ) {
        self.instanceId = instanceId
        self.requestCount = requestCount
        self.errorCount = errorCount
        self.successRate = successRate
        self.averageResponseTime = averageResponseTime
        self.minResponseTime = minResponseTime
        self.maxResponseTime = maxResponseTime
        self.totalResponseTime = totalResponseTime
    }
}

/// Overall load balancer metrics
public struct OverallLoadBalancerMetrics {
    public let totalRequests: Int
    public let totalErrors: Int
    public let totalServices: Int
    public let averageResponseTime: TimeInterval
    public let strategyUsage: [LoadBalancingStrategy: Int]
    
    public var successRate: Double {
        guard totalRequests > 0 else { return 1.0 }
        return Double(totalRequests - totalErrors) / Double(totalRequests)
    }
    
    public var errorRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(totalErrors) / Double(totalRequests)
    }
    
    public var mostUsedStrategy: LoadBalancingStrategy? {
        return strategyUsage.max(by: { $0.value < $1.value })?.key
    }
    
    public init(
        totalRequests: Int,
        totalErrors: Int,
        totalServices: Int,
        averageResponseTime: TimeInterval,
        strategyUsage: [LoadBalancingStrategy: Int]
    ) {
        self.totalRequests = totalRequests
        self.totalErrors = totalErrors
        self.totalServices = totalServices
        self.averageResponseTime = averageResponseTime
        self.strategyUsage = strategyUsage
    }
} 