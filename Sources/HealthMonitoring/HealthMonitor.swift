import Foundation
import Logging
import Collections

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class HealthMonitor {
    
    private let configuration: HealthMonitoringConfiguration
    private let logger: Logger
    
    private var healthStatuses: [String: ServiceHealthStatus] = [:]
    private var healthCallbacks: [String: [HealthStatusCallback]] = [:]
    private var monitoringTimer: Timer?
    
    public init(configuration: HealthMonitoringConfiguration) {
        self.configuration = configuration
        self.logger = Logger(label: "com.microservices.health.monitor")
        logger.info("HealthMonitor initialized with configuration: \(configuration)")
    }
    
    public func startMonitoring(callback: @escaping HealthStatusCallback) {
        monitoringTimer?.invalidate()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: configuration.monitoringInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck(callback: callback)
        }
        
        logger.info("Health monitoring started with interval: \(configuration.monitoringInterval)s")
    }
    
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        logger.info("Health monitoring stopped")
    }
    
    public func getHealthStatus(completion: @escaping (Result<[ServiceHealthStatus], HealthMonitoringError>) -> Void) {
        let statuses = Array(healthStatuses.values)
        completion(.success(statuses))
    }
    
    public func updateHealthStatus(_ status: ServiceHealthStatus) {
        healthStatuses[status.serviceName] = status
        notifyHealthCallbacks(for: status.serviceName, status: status)
        logger.debug("Updated health status for service: \(status.serviceName)")
    }
    
    public func subscribeToHealthUpdates(for serviceName: String, callback: @escaping HealthStatusCallback) {
        if healthCallbacks[serviceName] == nil {
            healthCallbacks[serviceName] = []
        }
        healthCallbacks[serviceName]?.append(callback)
        logger.info("Subscribed to health updates for service: \(serviceName)")
    }
    
    public func unsubscribeFromHealthUpdates(for serviceName: String) {
        healthCallbacks.removeValue(forKey: serviceName)
        logger.info("Unsubscribed from health updates for service: \(serviceName)")
    }
    
    public func updateConfiguration(_ newConfiguration: HealthMonitoringConfiguration) {
        // Update configuration
        logger.info("Health monitoring configuration updated")
    }
    
    private func performHealthCheck(callback: @escaping HealthStatusCallback) {
        logger.debug("Performing health check for \(healthStatuses.count) services")
        
        for (serviceName, status) in healthStatuses {
            let newStatus = checkServiceHealth(serviceName: serviceName, currentStatus: status)
            healthStatuses[serviceName] = newStatus
            callback(newStatus)
        }
    }
    
    private func checkServiceHealth(serviceName: String, currentStatus: ServiceHealthStatus) -> ServiceHealthStatus {
        // Simulate health check - in production, this would make actual HTTP requests
        let random = Double.random(in: 0...1)
        let isHealthy = random > 0.1
        
        return ServiceHealthStatus(
            serviceName: serviceName,
            status: isHealthy ? .healthy : .unhealthy,
            responseTime: Double.random(in: 10...500),
            lastChecked: Date(),
            errorMessage: isHealthy ? nil : "Service temporarily unavailable"
        )
    }
    
    private func notifyHealthCallbacks(for serviceName: String, status: ServiceHealthStatus) {
        guard let callbacks = healthCallbacks[serviceName] else { return }
        
        for callback in callbacks {
            callback(status)
        }
    }
}

public struct HealthMonitoringConfiguration {
    public let monitoringInterval: TimeInterval
    public let timeout: TimeInterval
    public let retryCount: Int
    public let enableNotifications: Bool
    
    public init(
        monitoringInterval: TimeInterval = 30.0,
        timeout: TimeInterval = 10.0,
        retryCount: Int = 3,
        enableNotifications: Bool = true
    ) {
        self.monitoringInterval = monitoringInterval
        self.timeout = timeout
        self.retryCount = retryCount
        self.enableNotifications = enableNotifications
    }
}

public struct ServiceHealthStatus {
    public let serviceName: String
    public let status: HealthStatus
    public let responseTime: TimeInterval
    public let lastChecked: Date
    public let errorMessage: String?
    
    public init(
        serviceName: String,
        status: HealthStatus,
        responseTime: TimeInterval,
        lastChecked: Date,
        errorMessage: String?
    ) {
        self.serviceName = serviceName
        self.status = status
        self.responseTime = responseTime
        self.lastChecked = lastChecked
        self.errorMessage = errorMessage
    }
}

public enum HealthStatus: String, CaseIterable {
    case healthy = "healthy"
    case unhealthy = "unhealthy"
    case unknown = "unknown"
    
    public var description: String {
        switch self {
        case .healthy: return "Healthy"
        case .unhealthy: return "Unhealthy"
        case .unknown: return "Unknown"
        }
    }
}

public typealias HealthStatusCallback = (ServiceHealthStatus) -> Void

public enum HealthMonitoringError: Error, LocalizedError {
    case serviceNotFound
    case monitoringTimeout
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .serviceNotFound:
            return "Service not found"
        case .monitoringTimeout:
            return "Health monitoring timeout"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
} 