import Foundation
import Logging
import Collections

/// Manages health checks for service instances
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class HealthCheckManager {
    
    // MARK: - Properties
    
    /// Health check configurations per service
    private var healthCheckConfigs: [String: HealthCheckConfiguration] = [:]
    
    /// Health check results cache
    private var healthCheckResults: [String: [String: HealthCheckResult]] = [:]
    
    /// Health check timers
    private var healthCheckTimers: [String: Timer] = [:]
    
    /// Logger for debugging
    private let logger: Logger
    
    /// Health check queue
    private let healthCheckQueue = DispatchQueue(label: "com.microservices.health.check", qos: .utility)
    
    // MARK: - Initialization
    
    public init() {
        self.logger = Logger(label: "com.microservices.health.check.manager")
        logger.info("HealthCheckManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Configure health checks for a service
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - configuration: Health check configuration
    public func configureHealthChecks(
        for serviceName: String,
        configuration: HealthCheckConfiguration
    ) {
        healthCheckConfigs[serviceName] = configuration
        logger.info("Health checks configured for service: \(serviceName)")
    }
    
    /// Start health checks for a service
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - instances: Service instances to check
    ///   - callback: Callback for health check results
    public func startHealthChecks(
        for serviceName: String,
        instances: [ServiceInstance],
        callback: @escaping ([HealthCheckResult]) -> Void
    ) {
        guard let config = healthCheckConfigs[serviceName] else {
            logger.warning("No health check configuration found for service: \(serviceName)")
            return
        }
        
        // Stop existing timer if any
        healthCheckTimers[serviceName]?.invalidate()
        
        // Create timer for periodic health checks
        let timer = Timer.scheduledTimer(withTimeInterval: config.interval, repeats: true) { [weak self] _ in
            self?.performHealthChecks(for: serviceName, instances: instances, callback: callback)
        }
        
        healthCheckTimers[serviceName] = timer
        
        // Perform initial health check
        performHealthChecks(for: serviceName, instances: instances, callback: callback)
        
        logger.info("Health checks started for service: \(serviceName)")
    }
    
    /// Stop health checks for a service
    /// - Parameter serviceName: The name of the service
    public func stopHealthChecks(for serviceName: String) {
        healthCheckTimers[serviceName]?.invalidate()
        healthCheckTimers.removeValue(forKey: serviceName)
        
        logger.info("Health checks stopped for service: \(serviceName)")
    }
    
    /// Perform manual health check
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - instances: Service instances to check
    ///   - callback: Callback for health check results
    public func performManualHealthCheck(
        for serviceName: String,
        instances: [ServiceInstance],
        callback: @escaping ([HealthCheckResult]) -> Void
    ) {
        performHealthChecks(for: serviceName, instances: instances, callback: callback)
    }
    
    /// Get health check results for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: Health check results
    public func getHealthCheckResults(for serviceName: String) -> [HealthCheckResult] {
        return healthCheckResults[serviceName]?.values.map { $0 } ?? []
    }
    
    /// Get health check configuration for a service
    /// - Parameter serviceName: The name of the service
    /// - Returns: Health check configuration
    public func getHealthCheckConfiguration(for serviceName: String) -> HealthCheckConfiguration? {
        return healthCheckConfigs[serviceName]
    }
    
    /// Update health check configuration
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - configuration: New health check configuration
    public func updateHealthCheckConfiguration(
        for serviceName: String,
        configuration: HealthCheckConfiguration
    ) {
        healthCheckConfigs[serviceName] = configuration
        
        // Restart health checks with new configuration
        if healthCheckTimers[serviceName] != nil {
            stopHealthChecks(for: serviceName)
            // Note: Would need instances to restart, this is simplified
        }
        
        logger.info("Health check configuration updated for service: \(serviceName)")
    }
    
    // MARK: - Private Methods
    
    private func performHealthChecks(
        for serviceName: String,
        instances: [ServiceInstance],
        callback: @escaping ([HealthCheckResult]) -> Void
    ) {
        guard let config = healthCheckConfigs[serviceName] else { return }
        
        let group = DispatchGroup()
        var results: [HealthCheckResult] = []
        let resultsLock = NSLock()
        
        for instance in instances {
            group.enter()
            
            performHealthCheck(for: instance, configuration: config) { result in
                resultsLock.lock()
                results.append(result)
                resultsLock.unlock()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Cache results
            if self.healthCheckResults[serviceName] == nil {
                self.healthCheckResults[serviceName] = [:]
            }
            
            for result in results {
                self.healthCheckResults[serviceName]?[result.instanceId] = result
            }
            
            callback(results)
        }
    }
    
    private func performHealthCheck(
        for instance: ServiceInstance,
        configuration: HealthCheckConfiguration,
        completion: @escaping (HealthCheckResult) -> Void
    ) {
        let startTime = Date()
        
        // Create health check request
        guard let url = URL(string: "\(instance.endpoint)\(configuration.endpoint)") else {
            let result = HealthCheckResult(
                instanceId: instance.id,
                serviceName: instance.host,
                status: .unhealthy,
                responseTime: 0,
                errorMessage: "Invalid health check URL",
                timestamp: Date()
            )
            completion(result)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = configuration.method.rawValue
        request.timeoutInterval = configuration.timeout
        
        // Add headers
        for (key, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let endTime = Date()
            let responseTime = endTime.timeIntervalSince(startTime)
            
            let result: HealthCheckResult
            
            if let error = error {
                result = HealthCheckResult(
                    instanceId: instance.id,
                    serviceName: instance.host,
                    status: .unhealthy,
                    responseTime: responseTime,
                    errorMessage: error.localizedDescription,
                    timestamp: endTime
                )
            } else if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = configuration.expectedStatusCodes.contains(httpResponse.statusCode)
                result = HealthCheckResult(
                    instanceId: instance.id,
                    serviceName: instance.host,
                    status: isHealthy ? .healthy : .unhealthy,
                    responseTime: responseTime,
                    errorMessage: isHealthy ? nil : "HTTP \(httpResponse.statusCode)",
                    timestamp: endTime
                )
            } else {
                result = HealthCheckResult(
                    instanceId: instance.id,
                    serviceName: instance.host,
                    status: .unknown,
                    responseTime: responseTime,
                    errorMessage: "Invalid response",
                    timestamp: endTime
                )
            }
            
            completion(result)
        }
        
        task.resume()
    }
}

// MARK: - Supporting Types

/// Health check configuration
public struct HealthCheckConfiguration {
    public let endpoint: String
    public let method: HTTPMethod
    public let interval: TimeInterval
    public let timeout: TimeInterval
    public let expectedStatusCodes: Set<Int>
    public let headers: [String: String]
    
    public init(
        endpoint: String = "/health",
        method: HTTPMethod = .GET,
        interval: TimeInterval = 30.0,
        timeout: TimeInterval = 10.0,
        expectedStatusCodes: Set<Int> = [200],
        headers: [String: String] = [:]
    ) {
        self.endpoint = endpoint
        self.method = method
        self.interval = interval
        self.timeout = timeout
        self.expectedStatusCodes = expectedStatusCodes
        self.headers = headers
    }
}

/// HTTP method for health checks
public enum HTTPMethod: String, CaseIterable {
    case GET = "GET"
    case POST = "POST"
    case HEAD = "HEAD"
}

/// Health check result
public struct HealthCheckResult {
    public let instanceId: String
    public let serviceName: String
    public let status: HealthStatus
    public let responseTime: TimeInterval
    public let errorMessage: String?
    public let timestamp: Date
    
    public init(
        instanceId: String,
        serviceName: String,
        status: HealthStatus,
        responseTime: TimeInterval,
        errorMessage: String?,
        timestamp: Date
    ) {
        self.instanceId = instanceId
        self.serviceName = serviceName
        self.status = status
        self.responseTime = responseTime
        self.errorMessage = errorMessage
        self.timestamp = timestamp
    }
} 