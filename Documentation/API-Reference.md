# API Reference

This document provides comprehensive API documentation for the iOS Microservices Client Framework.

## Table of Contents

- [MicroservicesClient](#microservicesclient)
- [ServiceDiscoveryManager](#servicediscoverymanager)
- [LoadBalancer](#loadbalancer)
- [CircuitBreaker](#circuitbreaker)
- [HealthMonitor](#healthmonitor)
- [Configuration Types](#configuration-types)
- [Error Types](#error-types)

## MicroservicesClient

The main client interface for microservices communication.

### Initialization

```swift
init(configuration: MicroservicesConfiguration)
```

Creates a new microservices client with the specified configuration.

**Parameters:**
- `configuration`: The configuration for the client

**Example:**
```swift
let configuration = MicroservicesConfiguration(
    serviceDiscovery: ServiceDiscoveryConfiguration(),
    loadBalancingStrategy: .roundRobin,
    circuitBreaker: CircuitBreakerConfiguration(),
    healthMonitoring: HealthMonitoringConfiguration()
)

let client = MicroservicesClient(configuration: configuration)
```

### Methods

#### registerService(_:completion:)

```swift
func registerService(_ service: ServiceDefinition, completion: @escaping (Result<Void, MicroservicesError>) -> Void)
```

Registers a service with the discovery system.

**Parameters:**
- `service`: The service definition to register
- `completion`: Completion handler called with the result

**Example:**
```swift
let service = ServiceDefinition(
    name: "user-service",
    version: "1.0.0",
    instances: [
        ServiceInstance(
            id: "user-service-1",
            endpoint: "https://user-service-1.example.com",
            host: "user-service-1.example.com",
            port: 443
        )
    ]
)

client.registerService(service) { result in
    switch result {
    case .success:
        print("Service registered successfully")
    case .failure(let error):
        print("Registration failed: \(error)")
    }
}
```

#### discoverServices(completion:)

```swift
func discoverServices(completion: @escaping (Result<[ServiceDefinition], MicroservicesError>) -> Void)
```

Discovers all available services.

**Parameters:**
- `completion`: Completion handler called with discovered services

**Example:**
```swift
client.discoverServices { result in
    switch result {
    case .success(let services):
        print("Discovered \(services.count) services")
        for service in services {
            print("Service: \(service.name), Version: \(service.version)")
        }
    case .failure(let error):
        print("Discovery failed: \(error)")
    }
}
```

#### callService(_:request:completion:)

```swift
func callService<T: Codable, U: Codable>(
    _ serviceName: String,
    request: T,
    completion: @escaping (Result<U, MicroservicesError>) -> Void
)
```

Makes a request to a service with automatic load balancing and circuit breaker.

**Parameters:**
- `serviceName`: The name of the service to call
- `request`: The request to send (must conform to Codable)
- `completion`: Completion handler called with the response

**Example:**
```swift
struct UserRequest: Codable {
    let userId: String
}

struct UserResponse: Codable {
    let id: String
    let name: String
    let email: String
}

let request = UserRequest(userId: "12345")

client.callService("user-service", request: request) { result in
    switch result {
    case .success(let response):
        print("User: \(response.name), Email: \(response.email)")
    case .failure(let error):
        print("Service call failed: \(error)")
    }
}
```

#### getHealthStatus(completion:)

```swift
func getHealthStatus(completion: @escaping (Result<[ServiceHealthStatus], MicroservicesError>) -> Void)
```

Gets the health status of all services.

**Parameters:**
- `completion`: Completion handler called with health status

**Example:**
```swift
client.getHealthStatus { result in
    switch result {
    case .success(let statuses):
        for status in statuses {
            print("Service: \(status.serviceName), Status: \(status.status)")
        }
    case .failure(let error):
        print("Health monitoring failed: \(error)")
    }
}
```

#### updateConfiguration(_:)

```swift
func updateConfiguration(_ newConfiguration: MicroservicesConfiguration)
```

Updates the client configuration dynamically.

**Parameters:**
- `newConfiguration`: The new configuration

**Example:**
```swift
let newConfiguration = MicroservicesConfiguration(
    serviceDiscovery: ServiceDiscoveryConfiguration(discoveryInterval: 60.0),
    loadBalancingStrategy: .leastConnections,
    circuitBreaker: CircuitBreakerConfiguration(failureThreshold: 10),
    healthMonitoring: HealthMonitoringConfiguration(monitoringInterval: 60.0)
)

client.updateConfiguration(newConfiguration)
```

## ServiceDiscoveryManager

Manages service discovery for microservices architecture.

### Initialization

```swift
init(configuration: ServiceDiscoveryConfiguration)
```

Creates a new service discovery manager.

**Parameters:**
- `configuration`: Configuration for service discovery

### Methods

#### registerService(_:completion:)

```swift
func registerService(_ service: ServiceDefinition, completion: @escaping (Result<Void, ServiceDiscoveryError>) -> Void)
```

Registers a service with the discovery system.

#### discoverServices(completion:)

```swift
func discoverServices(completion: @escaping (Result<[ServiceDefinition], ServiceDiscoveryError>) -> Void)
```

Discovers all available services.

#### getServiceInstances(for:completion:)

```swift
func getServiceInstances(for serviceName: String, completion: @escaping (Result<[ServiceInstance], ServiceDiscoveryError>) -> Void)
```

Gets instances for a specific service.

#### subscribeToService(_:callback:)

```swift
func subscribeToService(_ serviceName: String, callback: @escaping ServiceDiscoveryCallback)
```

Subscribes to service discovery updates.

#### unsubscribeFromService(_:)

```swift
func unsubscribeFromService(_ serviceName: String)
```

Unsubscribes from service discovery updates.

#### updateConfiguration(_:)

```swift
func updateConfiguration(_ newConfiguration: ServiceDiscoveryConfiguration)
```

Updates the service discovery configuration.

#### deregisterService(_:completion:)

```swift
func deregisterService(_ serviceName: String, completion: @escaping (Result<Void, ServiceDiscoveryError>) -> Void)
```

Deregisters a service.

## LoadBalancer

Load balancer for distributing requests across service instances.

### Initialization

```swift
init(strategy: LoadBalancingStrategy)
```

Creates a new load balancer with the specified strategy.

**Parameters:**
- `strategy`: The load balancing strategy to use

### Methods

#### selectInstance(from:)

```swift
func selectInstance(from instances: [ServiceInstance]) -> ServiceInstance
```

Selects an instance from the available instances using the configured strategy.

**Parameters:**
- `instances`: Available service instances

**Returns:**
- Selected service instance

#### updateStrategy(_:)

```swift
func updateStrategy(_ newStrategy: LoadBalancingStrategy)
```

Updates the load balancing strategy.

#### recordConnection(for:instanceId:)

```swift
func recordConnection(for serviceName: String, instanceId: String)
```

Records a connection for an instance (for least connections strategy).

#### releaseConnection(for:instanceId:)

```swift
func releaseConnection(for serviceName: String, instanceId: String)
```

Releases a connection for an instance.

#### updateHealthScore(for:instanceId:healthScore:)

```swift
func updateHealthScore(for serviceName: String, instanceId: String, healthScore: Double)
```

Updates health score for an instance.

## CircuitBreaker

Circuit breaker for fault tolerance patterns.

### Initialization

```swift
init(configuration: CircuitBreakerConfiguration)
```

Creates a new circuit breaker with the specified configuration.

### Methods

#### isClosed(for:)

```swift
func isClosed(for serviceName: String) -> Bool
```

Checks if circuit is closed for a service.

#### isOpen(for:)

```swift
func isOpen(for serviceName: String) -> Bool
```

Checks if circuit is open for a service.

#### isHalfOpen(for:)

```swift
func isHalfOpen(for serviceName: String) -> Bool
```

Checks if circuit is half-open for a service.

#### recordSuccess(for:)

```swift
func recordSuccess(for serviceName: String)
```

Records a successful request.

#### recordFailure(for:)

```swift
func recordFailure(for serviceName: String)
```

Records a failed request.

#### getCircuitState(for:)

```swift
func getCircuitState(for serviceName: String) -> CircuitState
```

Gets circuit state for a service.

#### getStatistics(for:)

```swift
func getStatistics(for serviceName: String) -> CircuitBreakerStatistics
```

Gets circuit breaker statistics for a service.

#### reset(for:)

```swift
func reset(for serviceName: String)
```

Resets circuit breaker for a service.

#### updateConfiguration(_:)

```swift
func updateConfiguration(_ newConfiguration: CircuitBreakerConfiguration)
```

Updates circuit breaker configuration.

## HealthMonitor

Health monitoring system for services.

### Initialization

```swift
init(configuration: HealthMonitoringConfiguration)
```

Creates a new health monitor with the specified configuration.

### Methods

#### startMonitoring(callback:)

```swift
func startMonitoring(callback: @escaping HealthStatusCallback)
```

Starts health monitoring.

#### stopMonitoring()

```swift
func stopMonitoring()
```

Stops health monitoring.

#### getHealthStatus(completion:)

```swift
func getHealthStatus(completion: @escaping (Result<[ServiceHealthStatus], HealthMonitoringError>) -> Void)
```

Gets health status of all services.

#### updateHealthStatus(_:)

```swift
func updateHealthStatus(_ status: ServiceHealthStatus)
```

Updates health status for a service.

#### subscribeToHealthUpdates(for:callback:)

```swift
func subscribeToHealthUpdates(for serviceName: String, callback: @escaping HealthStatusCallback)
```

Subscribes to health updates for a service.

#### unsubscribeFromHealthUpdates(for:)

```swift
func unsubscribeFromHealthUpdates(for serviceName: String)
```

Unsubscribes from health updates for a service.

#### updateConfiguration(_:)

```swift
func updateConfiguration(_ newConfiguration: HealthMonitoringConfiguration)
```

Updates health monitoring configuration.

## Configuration Types

### MicroservicesConfiguration

```swift
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
    )
}
```

### ServiceDiscoveryConfiguration

```swift
public struct ServiceDiscoveryConfiguration {
    public let discoveryInterval: TimeInterval
    public let timeout: TimeInterval
    public let maxCacheSize: Int
    public let enableHealthChecking: Bool
    
    public init(
        discoveryInterval: TimeInterval = 30.0,
        timeout: TimeInterval = 10.0,
        maxCacheSize: Int = 1000,
        enableHealthChecking: Bool = true
    )
}
```

### CircuitBreakerConfiguration

```swift
public struct CircuitBreakerConfiguration {
    public let failureThreshold: Int
    public let timeout: TimeInterval
    public let successThreshold: Int
    public let halfOpenRequestLimit: Int
    public let enabled: Bool
    
    public init(
        failureThreshold: Int = 5,
        timeout: TimeInterval = 60.0,
        successThreshold: Int = 3,
        halfOpenRequestLimit: Int = 1,
        enabled: Bool = true
    )
}
```

### HealthMonitoringConfiguration

```swift
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
    )
}
```

## Data Types

### ServiceDefinition

```swift
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
    )
}
```

### ServiceInstance

```swift
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
    )
}
```

### ServiceHealthStatus

```swift
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
    )
}
```

## Enums

### LoadBalancingStrategy

```swift
public enum LoadBalancingStrategy: String, CaseIterable {
    case roundRobin = "round_robin"
    case weightedRoundRobin = "weighted_round_robin"
    case leastConnections = "least_connections"
    case healthBased = "health_based"
    case random = "random"
    case ipHash = "ip_hash"
}
```

### CircuitState

```swift
public enum CircuitState: String, CaseIterable {
    case closed = "closed"
    case open = "open"
    case halfOpen = "half_open"
}
```

### HealthStatus

```swift
public enum HealthStatus: String, CaseIterable {
    case healthy = "healthy"
    case unhealthy = "unhealthy"
    case unknown = "unknown"
}
```

## Error Types

### MicroservicesError

```swift
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
}
```

### ServiceDiscoveryError

```swift
public enum ServiceDiscoveryError: Error, LocalizedError {
    case invalidServiceName
    case serviceNotFound
    case noHealthyInstances
    case discoveryTimeout
    case networkError(Error)
}
```

### HealthMonitoringError

```swift
public enum HealthMonitoringError: Error, LocalizedError {
    case serviceNotFound
    case monitoringTimeout
    case networkError(Error)
}
```

## Callback Types

### ServiceDiscoveryCallback

```swift
public typealias ServiceDiscoveryCallback = ([ServiceInstance]) -> Void
```

### HealthStatusCallback

```swift
public typealias HealthStatusCallback = (ServiceHealthStatus) -> Void
```

## Platform Availability

All public APIs are available on:
- iOS 15.0+
- macOS 12.0+
- tvOS 15.0+
- watchOS 8.0+

## Thread Safety

All public APIs are thread-safe and can be called from any thread. The framework handles thread synchronization internally.

## Memory Management

The framework uses automatic reference counting (ARC) and properly manages memory. No manual memory management is required.

## Performance Considerations

- Service discovery operations are cached for performance
- Load balancing algorithms are optimized for O(1) selection
- Circuit breaker state changes are atomic
- Health monitoring uses efficient polling mechanisms

## Error Handling

All operations return `Result` types with appropriate error handling. Errors include detailed descriptions and recovery suggestions.

## Logging

The framework uses structured logging with different log levels:
- `debug`: Detailed debugging information
- `info`: General information
- `warning`: Warning messages
- `error`: Error messages

Log messages include correlation IDs for tracking requests across the system. 