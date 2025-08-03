import Foundation
import Logging

/// Extensions for MicroservicesClient to provide additional functionality
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public extension MicroservicesClient {
    
    // MARK: - Convenience Methods
    
    /// Register a service with default configuration
    /// - Parameters:
    ///   - name: The service name
    ///   - version: The service version
    ///   - instances: The service instances
    ///   - completion: Completion handler with result
    func registerService(
        name: String,
        version: String,
        instances: [ServiceInstance],
        completion: @escaping (Result<Void, MicroservicesError>) -> Void
    ) {
        let service = ServiceDefinition(
            name: name,
            version: version,
            instances: instances
        )
        
        registerService(service, completion: completion)
    }
    
    /// Make a simple service call without request body
    /// - Parameters:
    ///   - serviceName: The name of the service to call
    ///   - completion: Completion handler with response
    func callService<T: Codable>(
        _ serviceName: String,
        completion: @escaping (Result<T, MicroservicesError>) -> Void
    ) {
        let emptyRequest = EmptyRequest()
        callService(serviceName, request: emptyRequest, completion: completion)
    }
    
    /// Get service instances for a specific service
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - completion: Completion handler with instances
    func getServiceInstances(
        for serviceName: String,
        completion: @escaping (Result<[ServiceInstance], MicroservicesError>) -> Void
    ) {
        serviceDiscovery.getServiceInstances(for: serviceName) { result in
            switch result {
            case .success(let instances):
                completion(.success(instances))
            case .failure(let error):
                completion(.failure(.serviceDiscoveryError(error.localizedDescription)))
            }
        }
    }
    
    /// Check if a service is healthy
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - completion: Completion handler with health status
    func isServiceHealthy(
        _ serviceName: String,
        completion: @escaping (Result<Bool, MicroservicesError>) -> Void
    ) {
        getHealthStatus { result in
            switch result {
            case .success(let statuses):
                let serviceStatus = statuses.first { $0.serviceName == serviceName }
                let isHealthy = serviceStatus?.status == .healthy
                completion(.success(isHealthy))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get circuit breaker state for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: Circuit breaker state
    func getCircuitBreakerState(for serviceName: String) -> CircuitState {
        return circuitBreaker.getCircuitState(for: serviceName)
    }
    
    /// Reset circuit breaker for a service
    /// - Parameter serviceName: The name of the service
    func resetCircuitBreaker(for serviceName: String) {
        circuitBreaker.reset(for: serviceName)
    }
    
    /// Get load balancer statistics
    /// - Returns: Load balancer statistics
    func getLoadBalancerStatistics() -> [String: Any] {
        // This would return actual statistics in a real implementation
        return [
            "strategy": configuration.loadBalancingStrategy.rawValue,
            "totalServices": "N/A",
            "totalInstances": "N/A"
        ]
    }
    
    /// Subscribe to service health updates
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - callback: Callback for health updates
    func subscribeToHealthUpdates(
        for serviceName: String,
        callback: @escaping (ServiceHealthStatus) -> Void
    ) {
        healthMonitor.subscribeToHealthUpdates(for: serviceName, callback: callback)
    }
    
    /// Unsubscribe from service health updates
    /// - Parameter serviceName: The name of the service
    func unsubscribeFromHealthUpdates(for serviceName: String) {
        healthMonitor.unsubscribeFromHealthUpdates(for: serviceName)
    }
}

// MARK: - Supporting Types

/// Empty request for simple service calls
public struct EmptyRequest: Codable {
    public init() {}
}

/// Service health status with additional information
public struct ServiceHealthStatus {
    public let serviceName: String
    public let status: HealthStatus
    public let responseTime: TimeInterval
    public let lastChecked: Date
    public let errorMessage: String?
    public let instanceCount: Int
    public let healthyInstanceCount: Int
    
    public init(
        serviceName: String,
        status: HealthStatus,
        responseTime: TimeInterval,
        lastChecked: Date,
        errorMessage: String?,
        instanceCount: Int,
        healthyInstanceCount: Int
    ) {
        self.serviceName = serviceName
        self.status = status
        self.responseTime = responseTime
        self.lastChecked = lastChecked
        self.errorMessage = errorMessage
        self.instanceCount = instanceCount
        self.healthyInstanceCount = healthyInstanceCount
    }
    
    public var healthPercentage: Double {
        guard instanceCount > 0 else { return 100.0 }
        return Double(healthyInstanceCount) / Double(instanceCount) * 100.0
    }
} 