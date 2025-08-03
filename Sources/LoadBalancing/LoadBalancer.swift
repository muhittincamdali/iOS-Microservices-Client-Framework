import Foundation
import Logging
import Collections

/// Load balancer for distributing requests across service instances
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class LoadBalancer {
    
    // MARK: - Properties
    
    /// Current load balancing strategy
    private var strategy: LoadBalancingStrategy
    
    /// Logger for debugging
    private let logger: Logger
    
    /// Round-robin counter
    private var roundRobinCounter: [String: Int] = [:]
    
    /// Weighted round-robin weights
    private var weightedWeights: [String: [Int]] = [:]
    
    /// Least connections tracking
    private var connectionCounts: [String: [String: Int]] = [:]
    
    /// Health-based instance tracking
    private var healthScores: [String: [String: Double]] = [:]
    
    // MARK: - Initialization
    
    /// Initialize the load balancer with a strategy
    /// - Parameter strategy: The load balancing strategy to use
    public init(strategy: LoadBalancingStrategy) {
        self.strategy = strategy
        self.logger = Logger(label: "com.microservices.load.balancer")
        
        logger.info("LoadBalancer initialized with strategy: \(strategy)")
    }
    
    // MARK: - Public Methods
    
    /// Select an instance from the available instances using the configured strategy
    /// - Parameter instances: Available service instances
    /// - Returns: Selected service instance
    public func selectInstance(from instances: [ServiceInstance]) -> ServiceInstance {
        guard !instances.isEmpty else {
            logger.error("No instances available for load balancing")
            return ServiceInstance(id: "", endpoint: "", host: "", port: 0)
        }
        
        let selectedInstance: ServiceInstance
        
        switch strategy {
        case .roundRobin:
            selectedInstance = selectRoundRobin(from: instances)
        case .weightedRoundRobin:
            selectedInstance = selectWeightedRoundRobin(from: instances)
        case .leastConnections:
            selectedInstance = selectLeastConnections(from: instances)
        case .healthBased:
            selectedInstance = selectHealthBased(from: instances)
        case .random:
            selectedInstance = selectRandom(from: instances)
        case .ipHash:
            selectedInstance = selectIpHash(from: instances)
        }
        
        logger.debug("Selected instance: \(selectedInstance.id) using strategy: \(strategy)")
        return selectedInstance
    }
    
    /// Update the load balancing strategy
    /// - Parameter newStrategy: The new strategy to use
    public func updateStrategy(_ newStrategy: LoadBalancingStrategy) {
        self.strategy = newStrategy
        logger.info("Load balancing strategy updated to: \(newStrategy)")
    }
    
    /// Record a connection for an instance (for least connections strategy)
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - instanceId: The instance ID
    public func recordConnection(for serviceName: String, instanceId: String) {
        if connectionCounts[serviceName] == nil {
            connectionCounts[serviceName] = [:]
        }
        connectionCounts[serviceName]?[instanceId, default: 0] += 1
        logger.debug("Recorded connection for service: \(serviceName), instance: \(instanceId)")
    }
    
    /// Release a connection for an instance
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - instanceId: The instance ID
    public func releaseConnection(for serviceName: String, instanceId: String) {
        guard let counts = connectionCounts[serviceName],
              let currentCount = counts[instanceId],
              currentCount > 0 else { return }
        
        connectionCounts[serviceName]?[instanceId] = currentCount - 1
        logger.debug("Released connection for service: \(serviceName), instance: \(instanceId)")
    }
    
    /// Update health score for an instance
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - instanceId: The instance ID
    ///   - healthScore: The health score (0.0 to 1.0)
    public func updateHealthScore(for serviceName: String, instanceId: String, healthScore: Double) {
        if healthScores[serviceName] == nil {
            healthScores[serviceName] = [:]
        }
        healthScores[serviceName]?[instanceId] = max(0.0, min(1.0, healthScore))
        logger.debug("Updated health score for service: \(serviceName), instance: \(instanceId): \(healthScore)")
    }
    
    // MARK: - Private Methods
    
    private func selectRoundRobin(from instances: [ServiceInstance]) -> ServiceInstance {
        let serviceName = instances.first?.host ?? "default"
        let currentIndex = roundRobinCounter[serviceName, default: 0]
        let selectedIndex = currentIndex % instances.count
        roundRobinCounter[serviceName] = currentIndex + 1
        
        return instances[selectedIndex]
    }
    
    private func selectWeightedRoundRobin(from instances: [ServiceInstance]) -> ServiceInstance {
        let serviceName = instances.first?.host ?? "default"
        
        // Initialize weights if not set
        if weightedWeights[serviceName] == nil {
            weightedWeights[serviceName] = instances.map { _ in 1 }
        }
        
        guard let weights = weightedWeights[serviceName], weights.count == instances.count else {
            return selectRoundRobin(from: instances)
        }
        
        let currentIndex = roundRobinCounter[serviceName, default: 0]
        let totalWeight = weights.reduce(0, +)
        let normalizedIndex = currentIndex % totalWeight
        
        var cumulativeWeight = 0
        for (index, weight) in weights.enumerated() {
            cumulativeWeight += weight
            if normalizedIndex < cumulativeWeight {
                roundRobinCounter[serviceName] = currentIndex + 1
                return instances[index]
            }
        }
        
        return instances[0]
    }
    
    private func selectLeastConnections(from instances: [ServiceInstance]) -> ServiceInstance {
        let serviceName = instances.first?.host ?? "default"
        let counts = connectionCounts[serviceName] ?? [:]
        
        var minConnections = Int.max
        var selectedInstance = instances[0]
        
        for instance in instances {
            let connectionCount = counts[instance.id] ?? 0
            if connectionCount < minConnections {
                minConnections = connectionCount
                selectedInstance = instance
            }
        }
        
        return selectedInstance
    }
    
    private func selectHealthBased(from instances: [ServiceInstance]) -> ServiceInstance {
        let serviceName = instances.first?.host ?? "default"
        let scores = healthScores[serviceName] ?? [:]
        
        var bestScore = 0.0
        var selectedInstance = instances[0]
        
        for instance in instances {
            let healthScore = scores[instance.id] ?? 1.0
            if healthScore > bestScore {
                bestScore = healthScore
                selectedInstance = instance
            }
        }
        
        return selectedInstance
    }
    
    private func selectRandom(from instances: [ServiceInstance]) -> ServiceInstance {
        let randomIndex = Int.random(in: 0..<instances.count)
        return instances[randomIndex]
    }
    
    private func selectIpHash(from instances: [ServiceInstance]) -> ServiceInstance {
        // In a real implementation, this would hash the client IP
        // For now, we'll use a simple hash of the current timestamp
        let hash = abs(Date().timeIntervalSince1970.hashValue)
        let index = hash % instances.count
        return instances[index]
    }
}

// MARK: - Supporting Types

/// Load balancing strategies
public enum LoadBalancingStrategy: String, CaseIterable {
    case roundRobin = "round_robin"
    case weightedRoundRobin = "weighted_round_robin"
    case leastConnections = "least_connections"
    case healthBased = "health_based"
    case random = "random"
    case ipHash = "ip_hash"
    
    public var description: String {
        switch self {
        case .roundRobin:
            return "Round Robin"
        case .weightedRoundRobin:
            return "Weighted Round Robin"
        case .leastConnections:
            return "Least Connections"
        case .healthBased:
            return "Health Based"
        case .random:
            return "Random"
        case .ipHash:
            return "IP Hash"
        }
    }
}

/// Load balancer statistics
public struct LoadBalancerStatistics {
    public let totalRequests: Int
    public let requestsPerInstance: [String: Int]
    public let averageResponseTime: TimeInterval
    public let errorRate: Double
    
    public init(
        totalRequests: Int,
        requestsPerInstance: [String: Int],
        averageResponseTime: TimeInterval,
        errorRate: Double
    ) {
        self.totalRequests = totalRequests
        self.requestsPerInstance = requestsPerInstance
        self.averageResponseTime = averageResponseTime
        self.errorRate = errorRate
    }
}

/// Load balancer configuration
public struct LoadBalancerConfiguration {
    public let strategy: LoadBalancingStrategy
    public let healthCheckInterval: TimeInterval
    public let maxRetries: Int
    public let timeout: TimeInterval
    
    public init(
        strategy: LoadBalancingStrategy = .roundRobin,
        healthCheckInterval: TimeInterval = 30.0,
        maxRetries: Int = 3,
        timeout: TimeInterval = 10.0
    ) {
        self.strategy = strategy
        self.healthCheckInterval = healthCheckInterval
        self.maxRetries = maxRetries
        self.timeout = timeout
    }
} 