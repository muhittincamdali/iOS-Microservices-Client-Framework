import Foundation
import Logging
import Collections

/// Manages service discovery for microservices architecture
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class ServiceDiscoveryManager {
    
    // MARK: - Properties
    
    /// Configuration for service discovery
    private var configuration: ServiceDiscoveryConfiguration
    
    /// Logger for debugging
    private let logger: Logger
    
    /// Registered services cache
    private var registeredServices: OrderedDictionary<String, ServiceDefinition> = [:]
    
    /// Service instances cache
    private var serviceInstances: OrderedDictionary<String, [ServiceInstance]> = [:]
    
    /// Discovery timer for periodic updates
    private var discoveryTimer: Timer?
    
    /// Discovery callbacks
    private var discoveryCallbacks: [String: [ServiceDiscoveryCallback]] = [:]
    
    // MARK: - Initialization
    
    /// Initialize the service discovery manager
    /// - Parameter configuration: Configuration for service discovery
    public init(configuration: ServiceDiscoveryConfiguration) {
        self.configuration = configuration
        self.logger = Logger(label: "com.microservices.service.discovery")
        
        setupPeriodicDiscovery()
        logger.info("ServiceDiscoveryManager initialized with configuration: \(configuration)")
    }
    
    // MARK: - Public Methods
    
    /// Register a service with the discovery system
    /// - Parameters:
    ///   - service: The service definition to register
    ///   - completion: Completion handler with result
    public func registerService(_ service: ServiceDefinition, completion: @escaping (Result<Void, ServiceDiscoveryError>) -> Void) {
        guard !service.name.isEmpty else {
            completion(.failure(.invalidServiceName))
            return
        }
        
        registeredServices[service.name] = service
        
        // Notify discovery callbacks
        notifyDiscoveryCallbacks(for: service.name, instances: service.instances)
        
        logger.info("Service registered: \(service.name) with \(service.instances.count) instances")
        completion(.success(()))
    }
    
    /// Discover all available services
    /// - Parameter completion: Completion handler with discovered services
    public func discoverServices(completion: @escaping (Result<[ServiceDefinition], ServiceDiscoveryError>) -> Void) {
        let services = Array(registeredServices.values)
        logger.info("Discovered \(services.count) services")
        completion(.success(services))
    }
    
    /// Get instances for a specific service
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - completion: Completion handler with service instances
    public func getServiceInstances(for serviceName: String, completion: @escaping (Result<[ServiceInstance], ServiceDiscoveryError>) -> Void) {
        guard let service = registeredServices[serviceName] else {
            completion(.failure(.serviceNotFound))
            return
        }
        
        let instances = service.instances.filter { instance in
            // Filter by health status
            instance.healthStatus == .healthy
        }
        
        guard !instances.isEmpty else {
            completion(.failure(.noHealthyInstances))
            return
        }
        
        logger.info("Found \(instances.count) healthy instances for service: \(serviceName)")
        completion(.success(instances))
    }
    
    /// Subscribe to service discovery updates
    /// - Parameters:
    ///   - serviceName: The service name to subscribe to
    ///   - callback: Callback for discovery updates
    public func subscribeToService(_ serviceName: String, callback: @escaping ServiceDiscoveryCallback) {
        if discoveryCallbacks[serviceName] == nil {
            discoveryCallbacks[serviceName] = []
        }
        discoveryCallbacks[serviceName]?.append(callback)
        
        logger.info("Subscribed to service discovery updates for: \(serviceName)")
    }
    
    /// Unsubscribe from service discovery updates
    /// - Parameter serviceName: The service name to unsubscribe from
    public func unsubscribeFromService(_ serviceName: String) {
        discoveryCallbacks.removeValue(forKey: serviceName)
        logger.info("Unsubscribed from service discovery updates for: \(serviceName)")
    }
    
    /// Update service discovery configuration
    /// - Parameter newConfiguration: The new configuration
    public func updateConfiguration(_ newConfiguration: ServiceDiscoveryConfiguration) {
        self.configuration = newConfiguration
        setupPeriodicDiscovery()
        logger.info("Service discovery configuration updated")
    }
    
    /// Deregister a service
    /// - Parameters:
    ///   - serviceName: The name of the service to deregister
    ///   - completion: Completion handler with result
    public func deregisterService(_ serviceName: String, completion: @escaping (Result<Void, ServiceDiscoveryError>) -> Void) {
        guard registeredServices.removeValue(forKey: serviceName) != nil else {
            completion(.failure(.serviceNotFound))
            return
        }
        
        serviceInstances.removeValue(forKey: serviceName)
        discoveryCallbacks.removeValue(forKey: serviceName)
        
        logger.info("Service deregistered: \(serviceName)")
        completion(.success(()))
    }
    
    // MARK: - Private Methods
    
    private func setupPeriodicDiscovery() {
        discoveryTimer?.invalidate()
        
        guard configuration.discoveryInterval > 0 else { return }
        
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: configuration.discoveryInterval, repeats: true) { [weak self] _ in
            self?.performPeriodicDiscovery()
        }
    }
    
    private func performPeriodicDiscovery() {
        logger.debug("Performing periodic service discovery")
        
        // Update health status for all instances
        for (serviceName, service) in registeredServices {
            let updatedInstances = service.instances.map { instance in
                var updatedInstance = instance
                updatedInstance.healthStatus = checkInstanceHealth(instance)
                return updatedInstance
            }
            
            let updatedService = ServiceDefinition(
                name: service.name,
                version: service.version,
                instances: updatedInstances,
                metadata: service.metadata
            )
            
            registeredServices[serviceName] = updatedService
            notifyDiscoveryCallbacks(for: serviceName, instances: updatedInstances)
        }
    }
    
    private func checkInstanceHealth(_ instance: ServiceInstance) -> ServiceHealthStatus {
        // Simple health check - in production, this would make an actual HTTP request
        let random = Double.random(in: 0...1)
        return random > 0.1 ? .healthy : .unhealthy
    }
    
    private func notifyDiscoveryCallbacks(for serviceName: String, instances: [ServiceInstance]) {
        guard let callbacks = discoveryCallbacks[serviceName] else { return }
        
        for callback in callbacks {
            callback(instances)
        }
    }
}

// MARK: - Supporting Types

/// Configuration for service discovery
public struct ServiceDiscoveryConfiguration {
    /// Interval for periodic service discovery (in seconds)
    public let discoveryInterval: TimeInterval
    
    /// Timeout for service discovery requests
    public let timeout: TimeInterval
    
    /// Maximum number of service instances to cache
    public let maxCacheSize: Int
    
    /// Whether to enable automatic health checking
    public let enableHealthChecking: Bool
    
    public init(
        discoveryInterval: TimeInterval = 30.0,
        timeout: TimeInterval = 10.0,
        maxCacheSize: Int = 1000,
        enableHealthChecking: Bool = true
    ) {
        self.discoveryInterval = discoveryInterval
        self.timeout = timeout
        self.maxCacheSize = maxCacheSize
        self.enableHealthChecking = enableHealthChecking
    }
}

/// Service definition
public struct ServiceDefinition: Codable {
    public let name: String
    public let version: String
    public let instances: [ServiceInstance]
    public let metadata: [String: String]
    
    public init(
        name: String,
        version: String,
        instances: [ServiceInstance],
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.version = version
        self.instances = instances
        self.metadata = metadata
    }
}

/// Service instance
public struct ServiceInstance: Codable {
    public let id: String
    public let endpoint: String
    public let host: String
    public let port: Int
    public var healthStatus: ServiceHealthStatus
    public let metadata: [String: String]
    
    public init(
        id: String,
        endpoint: String,
        host: String,
        port: Int,
        healthStatus: ServiceHealthStatus = .healthy,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.endpoint = endpoint
        self.host = host
        self.port = port
        self.healthStatus = healthStatus
        self.metadata = metadata
    }
}

/// Service health status
public enum ServiceHealthStatus: String, Codable {
    case healthy
    case unhealthy
    case unknown
}

/// Service discovery callback type
public typealias ServiceDiscoveryCallback = ([ServiceInstance]) -> Void

/// Errors that can occur in service discovery
public enum ServiceDiscoveryError: Error, LocalizedError {
    case invalidServiceName
    case serviceNotFound
    case noHealthyInstances
    case discoveryTimeout
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidServiceName:
            return "Invalid service name"
        case .serviceNotFound:
            return "Service not found"
        case .noHealthyInstances:
            return "No healthy service instances available"
        case .discoveryTimeout:
            return "Service discovery timeout"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
} 