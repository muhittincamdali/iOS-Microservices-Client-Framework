import Foundation
import Logging
import Collections
import AsyncAlgorithms

/// A comprehensive microservices client framework for iOS applications
/// providing service discovery, load balancing, circuit breaker patterns,
/// and health monitoring capabilities.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class MicroservicesClient {
    
    // MARK: - Properties
    
    /// The configuration for the microservices client
    public let configuration: MicroservicesConfiguration
    
    /// Service discovery manager
    public let serviceDiscovery: ServiceDiscoveryManager
    
    /// Load balancer for distributing requests
    public let loadBalancer: LoadBalancer
    
    /// Circuit breaker for fault tolerance
    public let circuitBreaker: CircuitBreaker
    
    /// Health monitoring system
    public let healthMonitor: HealthMonitor
    
    /// Logger for debugging and monitoring
    private let logger: Logger
    
    /// Active service connections
    private var activeConnections: OrderedDictionary<String, ServiceConnection> = [:]
    
    /// Request queue for handling high load
    private let requestQueue = DispatchQueue(label: "com.microservices.client.queue", qos: .userInitiated)
    
    // MARK: - Initialization
    
    /// Initialize the microservices client with configuration
    /// - Parameter configuration: The configuration for the client
    public init(configuration: MicroservicesConfiguration) {
        self.configuration = configuration
        self.logger = Logger(label: "com.microservices.client")
        
        // Initialize components
        self.serviceDiscovery = ServiceDiscoveryManager(configuration: configuration.serviceDiscovery)
        self.loadBalancer = LoadBalancer(strategy: configuration.loadBalancingStrategy)
        self.circuitBreaker = CircuitBreaker(configuration: configuration.circuitBreaker)
        self.healthMonitor = HealthMonitor(configuration: configuration.healthMonitoring)
        
        setupHealthMonitoring()
        logger.info("MicroservicesClient initialized with configuration: \(configuration)")
    }
    
    // MARK: - Public Methods
    
    /// Register a service with the discovery system
    /// - Parameters:
    ///   - service: The service to register
    ///   - completion: Completion handler with result
    public func registerService(_ service: ServiceDefinition, completion: @escaping (Result<Void, MicroservicesError>) -> Void) {
        serviceDiscovery.registerService(service) { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("Service registered successfully: \(service.name)")
                completion(.success(()))
            case .failure(let error):
                self?.logger.error("Failed to register service: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Discover available services
    /// - Parameter completion: Completion handler with discovered services
    public func discoverServices(completion: @escaping (Result<[ServiceDefinition], MicroservicesError>) -> Void) {
        serviceDiscovery.discoverServices { [weak self] result in
            switch result {
            case .success(let services):
                self?.logger.info("Discovered \(services.count) services")
                completion(.success(services))
            case .failure(let error):
                self?.logger.error("Failed to discover services: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Make a request to a service with automatic load balancing and circuit breaker
    /// - Parameters:
    ///   - serviceName: The name of the service to call
    ///   - request: The request to send
    ///   - completion: Completion handler with response
    public func callService<T: Codable, U: Codable>(
        _ serviceName: String,
        request: T,
        completion: @escaping (Result<U, MicroservicesError>) -> Void
    ) {
        guard circuitBreaker.isClosed(for: serviceName) else {
            logger.warning("Circuit breaker is open for service: \(serviceName)")
            completion(.failure(.circuitBreakerOpen))
            return
        }
        
        // Get available instances
        serviceDiscovery.getServiceInstances(for: serviceName) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let instances):
                guard !instances.isEmpty else {
                    self.logger.error("No instances available for service: \(serviceName)")
                    completion(.failure(.noServiceInstances))
                    return
                }
                
                // Select instance using load balancer
                let selectedInstance = self.loadBalancer.selectInstance(from: instances)
                
                // Make the request
                self.makeRequest(to: selectedInstance, request: request) { result in
                    switch result {
                    case .success(let response):
                        self.circuitBreaker.recordSuccess(for: serviceName)
                        completion(.success(response))
                    case .failure(let error):
                        self.circuitBreaker.recordFailure(for: serviceName)
                        self.logger.error("Request failed: \(error)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                self.logger.error("Failed to get service instances: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Get health status of all services
    /// - Parameter completion: Completion handler with health status
    public func getHealthStatus(completion: @escaping (Result<[ServiceHealthStatus], MicroservicesError>) -> Void) {
        healthMonitor.getHealthStatus { [weak self] result in
            switch result {
            case .success(let statuses):
                self?.logger.info("Retrieved health status for \(statuses.count) services")
                completion(.success(statuses))
            case .failure(let error):
                self?.logger.error("Failed to get health status: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Update configuration dynamically
    /// - Parameter newConfiguration: The new configuration
    public func updateConfiguration(_ newConfiguration: MicroservicesConfiguration) {
        configuration = newConfiguration
        serviceDiscovery.updateConfiguration(newConfiguration.serviceDiscovery)
        loadBalancer.updateStrategy(newConfiguration.loadBalancingStrategy)
        circuitBreaker.updateConfiguration(newConfiguration.circuitBreaker)
        healthMonitor.updateConfiguration(newConfiguration.healthMonitoring)
        
        logger.info("Configuration updated successfully")
    }
    
    // MARK: - Private Methods
    
    private func setupHealthMonitoring() {
        healthMonitor.startMonitoring { [weak self] status in
            self?.logger.info("Health status update: \(status)")
        }
    }
    
    private func makeRequest<T: Codable, U: Codable>(
        to instance: ServiceInstance,
        request: T,
        completion: @escaping (Result<U, MicroservicesError>) -> Void
    ) {
        guard let url = URL(string: instance.endpoint) else {
            completion(.failure(.invalidEndpoint))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(U.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
}

// MARK: - Supporting Types

/// Configuration for the microservices client
public struct MicroservicesConfiguration {
    public let serviceDiscovery: ServiceDiscoveryConfiguration
    public let loadBalancingStrategy: LoadBalancingStrategy
    public let circuitBreaker: CircuitBreakerConfiguration
    public let healthMonitoring: HealthMonitoringConfiguration
    
    public init(
        serviceDiscovery: ServiceDiscoveryConfiguration,
        loadBalancingStrategy: LoadBalancingStrategy = .roundRobin,
        circuitBreaker: CircuitBreakerConfiguration = CircuitBreakerConfiguration(),
        healthMonitoring: HealthMonitoringConfiguration = HealthMonitoringConfiguration()
    ) {
        self.serviceDiscovery = serviceDiscovery
        self.loadBalancingStrategy = loadBalancingStrategy
        self.circuitBreaker = circuitBreaker
        self.healthMonitoring = healthMonitoring
    }
}

/// Errors that can occur in the microservices client
public enum MicroservicesError: Error, LocalizedError {
    case circuitBreakerOpen
    case noServiceInstances
    case invalidEndpoint
    case encodingError
    case decodingError
    case noData
    case networkError(Error)
    case serviceDiscoveryError(String)
    case loadBalancingError(String)
    case healthMonitoringError(String)
    
    public var errorDescription: String? {
        switch self {
        case .circuitBreakerOpen:
            return "Circuit breaker is open for this service"
        case .noServiceInstances:
            return "No service instances available"
        case .invalidEndpoint:
            return "Invalid service endpoint"
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        case .noData:
            return "No data received from service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serviceDiscoveryError(let message):
            return "Service discovery error: \(message)"
        case .loadBalancingError(let message):
            return "Load balancing error: \(message)"
        case .healthMonitoringError(let message):
            return "Health monitoring error: \(message)"
        }
    }
} 