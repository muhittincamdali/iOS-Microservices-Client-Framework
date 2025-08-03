import Foundation
import Logging
import Collections

/// Service registry for managing service registrations and metadata
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class ServiceRegistry {
    
    // MARK: - Properties
    
    /// Registered services with their metadata
    private var registeredServices: OrderedDictionary<String, ServiceRegistration> = [:]
    
    /// Service metadata cache
    private var serviceMetadata: [String: [String: String]] = [:]
    
    /// Logger for debugging
    private let logger: Logger
    
    /// Registry lock for thread safety
    private let registryLock = NSLock()
    
    // MARK: - Initialization
    
    public init() {
        self.logger = Logger(label: "com.microservices.service.registry")
        logger.info("ServiceRegistry initialized")
    }
    
    // MARK: - Public Methods
    
    /// Register a service with metadata
    /// - Parameters:
    ///   - service: The service to register
    ///   - metadata: Additional metadata for the service
    ///   - completion: Completion handler with result
    public func registerService(
        _ service: ServiceDefinition,
        metadata: [String: String] = [:],
        completion: @escaping (Result<Void, ServiceRegistryError>) -> Void
    ) {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        guard !service.name.isEmpty else {
            completion(.failure(.invalidServiceName))
            return
        }
        
        let registration = ServiceRegistration(
            service: service,
            metadata: metadata,
            registeredAt: Date(),
            lastUpdated: Date()
        )
        
        registeredServices[service.name] = registration
        serviceMetadata[service.name] = metadata
        
        logger.info("Service registered: \(service.name) with \(service.instances.count) instances")
        completion(.success(()))
    }
    
    /// Get all registered services
    /// - Returns: Array of registered services
    public func getAllServices() -> [ServiceDefinition] {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        return Array(registeredServices.values.map { $0.service })
    }
    
    /// Get service by name
    /// - Parameter serviceName: The name of the service
    /// - Returns: The service definition if found
    public func getService(by name: String) -> ServiceDefinition? {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        return registeredServices[name]?.service
    }
    
    /// Get service metadata
    /// - Parameter serviceName: The name of the service
    /// - Returns: Service metadata if found
    public func getServiceMetadata(for serviceName: String) -> [String: String]? {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        return serviceMetadata[serviceName]
    }
    
    /// Update service metadata
    /// - Parameters:
    ///   - serviceName: The name of the service
    ///   - metadata: New metadata
    ///   - completion: Completion handler with result
    public func updateServiceMetadata(
        for serviceName: String,
        metadata: [String: String],
        completion: @escaping (Result<Void, ServiceRegistryError>) -> Void
    ) {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        guard registeredServices[serviceName] != nil else {
            completion(.failure(.serviceNotFound))
            return
        }
        
        serviceMetadata[serviceName] = metadata
        
        if var registration = registeredServices[serviceName] {
            registration.metadata = metadata
            registration.lastUpdated = Date()
            registeredServices[serviceName] = registration
        }
        
        logger.info("Service metadata updated for: \(serviceName)")
        completion(.success(()))
    }
    
    /// Deregister a service
    /// - Parameters:
    ///   - serviceName: The name of the service to deregister
    ///   - completion: Completion handler with result
    public func deregisterService(
        _ serviceName: String,
        completion: @escaping (Result<Void, ServiceRegistryError>) -> Void
    ) {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        guard registeredServices.removeValue(forKey: serviceName) != nil else {
            completion(.failure(.serviceNotFound))
            return
        }
        
        serviceMetadata.removeValue(forKey: serviceName)
        
        logger.info("Service deregistered: \(serviceName)")
        completion(.success(()))
    }
    
    /// Get service statistics
    /// - Returns: Registry statistics
    public func getStatistics() -> ServiceRegistryStatistics {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        let totalServices = registeredServices.count
        let totalInstances = registeredServices.values.reduce(0) { $0 + $1.service.instances.count }
        let healthyInstances = registeredServices.values.reduce(0) { count, registration in
            count + registration.service.instances.filter { $0.healthStatus == .healthy }.count
        }
        
        return ServiceRegistryStatistics(
            totalServices: totalServices,
            totalInstances: totalInstances,
            healthyInstances: healthyInstances,
            unhealthyInstances: totalInstances - healthyInstances
        )
    }
    
    /// Clear all registrations
    public func clearAll() {
        registryLock.lock()
        defer { registryLock.unlock() }
        
        registeredServices.removeAll()
        serviceMetadata.removeAll()
        
        logger.info("All service registrations cleared")
    }
}

// MARK: - Supporting Types

/// Service registration with metadata
public struct ServiceRegistration {
    public let service: ServiceDefinition
    public var metadata: [String: String]
    public let registeredAt: Date
    public var lastUpdated: Date
    
    public init(
        service: ServiceDefinition,
        metadata: [String: String],
        registeredAt: Date,
        lastUpdated: Date
    ) {
        self.service = service
        self.metadata = metadata
        self.registeredAt = registeredAt
        self.lastUpdated = lastUpdated
    }
}

/// Service registry statistics
public struct ServiceRegistryStatistics {
    public let totalServices: Int
    public let totalInstances: Int
    public let healthyInstances: Int
    public let unhealthyInstances: Int
    
    public var healthPercentage: Double {
        guard totalInstances > 0 else { return 100.0 }
        return Double(healthyInstances) / Double(totalInstances) * 100.0
    }
    
    public init(
        totalServices: Int,
        totalInstances: Int,
        healthyInstances: Int,
        unhealthyInstances: Int
    ) {
        self.totalServices = totalServices
        self.totalInstances = totalInstances
        self.healthyInstances = healthyInstances
        self.unhealthyInstances = unhealthyInstances
    }
}

/// Errors that can occur in service registry
public enum ServiceRegistryError: Error, LocalizedError {
    case invalidServiceName
    case serviceNotFound
    case serviceAlreadyExists
    case invalidMetadata
    
    public var errorDescription: String? {
        switch self {
        case .invalidServiceName:
            return "Invalid service name"
        case .serviceNotFound:
            return "Service not found"
        case .serviceAlreadyExists:
            return "Service already exists"
        case .invalidMetadata:
            return "Invalid metadata"
        }
    }
} 