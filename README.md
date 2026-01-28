# 🏗️ iOS Microservices Client Framework

<div align="center">

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-000000?style=for-the-badge&logo=ios&logoColor=white)](https://developer.apple.com/ios/)
[![macOS 12.0+](https://img.shields.io/badge/macOS-12.0+-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

**Enterprise-grade microservices client for iOS applications**

Service discovery, load balancing, circuit breaker patterns, and health monitoring for distributed iOS apps.

[Features](#-features) • [Installation](#-installation) • [Quick Start](#-quick-start) • [API Reference](#-api-reference) • [Examples](#-examples)

</div>

---

## ✨ Features

- **🔍 Service Discovery** — Automatic service registration and discovery
- **⚖️ Load Balancing** — Round-robin, least connections, weighted, and random strategies
- **🔌 Circuit Breaker** — Fault tolerance with automatic recovery
- **🔗 Connection Pooling** — Efficient connection management
- **📊 Health Monitoring** — Real-time service health tracking
- **📈 Analytics** — Built-in metrics and performance monitoring
- **🔒 Secure** — TLS support via Swift-Crypto
- **⚡ High Performance** — Built on Swift-NIO for async networking

---

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/iOS-Microservices-Client-Framework.git", from: "1.0.0")
]
```

Add the product to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "MicroservicesClient", package: "iOS-Microservices-Client-Framework")
    ]
)
```

### Xcode

1. Go to **File → Add Package Dependencies**
2. Enter: `https://github.com/muhittincamdali/iOS-Microservices-Client-Framework.git`
3. Select version and add to your project

---

## 🚀 Quick Start

### Initialize the Client Manager

```swift
import MicroservicesClient

// Create the microservices client manager
let clientManager = MicroservicesClientManager()

// Or with custom analytics
let analytics = MyCustomAnalytics()
let clientManager = MicroservicesClientManager(analytics: analytics)
```

### Register Services

```swift
// Define a microservice
let userService = Microservice(
    id: "user-service-1",
    name: "User Service",
    type: .user,
    endpoint: URL(string: "https://api.example.com/users")!,
    health: .healthy,
    version: "2.1.0"
)

// Register the service
clientManager.registerService(userService) { result in
    switch result {
    case .success:
        print("Service registered successfully")
    case .failure(let error):
        print("Registration failed: \(error)")
    }
}
```

### Discover Services

```swift
// Discover all available services
clientManager.discoverServices { result in
    switch result {
    case .success(let services):
        print("Discovered \(services.count) services")
        for service in services {
            print("- \(service.name) (\(service.health))")
        }
    case .failure(let error):
        print("Discovery failed: \(error)")
    }
}
```

### Execute Requests with Load Balancing

```swift
// Create a request
let request = ServiceRequest(
    serviceId: "user-service",
    method: "GET",
    path: "/api/v1/users/123",
    headers: ["Authorization": "Bearer token"],
    timeout: 30.0
)

// Execute with automatic load balancing and circuit breaker protection
clientManager.executeRequest(serviceId: "user-service", request: request) { (result: Result<UserResponse, MicroservicesError>) in
    switch result {
    case .success(let response):
        print("User: \(response)")
    case .failure(let error):
        print("Request failed: \(error)")
    }
}
```

---

## 📚 API Reference

### MicroservicesClientManager

The main entry point for all microservices operations.

#### Service Discovery

```swift
// Discover services
func discoverServices(completion: @escaping (Result<[Microservice], MicroservicesError>) -> Void)

// Register a service
func registerService(_ service: Microservice, completion: @escaping (Result<Void, MicroservicesError>) -> Void)

// Get service by ID
func getService(id: String) -> Microservice?

// Get all registered services
func getAllServices() -> [Microservice]
```

#### Load Balancing

```swift
// Balance load across services
func balanceLoad(
    serviceType: ServiceType,
    strategy: LoadBalancingStrategy = .roundRobin,
    completion: @escaping (Result<Microservice, MicroservicesError>) -> Void
)

// Update service health
func updateServiceHealth(serviceId: String, health: ServiceHealth)
```

#### Circuit Breaker

```swift
// Execute with circuit breaker protection
func executeWithCircuitBreaker<T>(
    serviceId: String,
    request: ServiceRequest,
    completion: @escaping (Result<T, MicroservicesError>) -> Void
)

// Get circuit breaker status
func getCircuitBreakerStatus(serviceId: String) -> CircuitBreakerStatus?
```

#### Connection Management

```swift
// Establish connection
func establishConnection(
    to service: Microservice,
    completion: @escaping (Result<ServiceConnection, MicroservicesError>) -> Void
)

// Close connection
func closeConnection(_ connection: ServiceConnection)

// Get connection statistics
func getConnectionStatistics() -> ConnectionStatistics?
```

### Service Types

```swift
enum ServiceType {
    case user
    case payment
    case notification
    case analytics
    case storage
    case authentication
    case custom(String)
}
```

### Load Balancing Strategies

```swift
enum LoadBalancingStrategy {
    case roundRobin       // Distribute evenly
    case leastConnections // Prefer least busy
    case weighted         // Based on weights
    case random           // Random selection
}
```

### Circuit Breaker States

```swift
enum CircuitBreakerStatus {
    case closed   // Normal operation
    case open     // Failing, requests blocked
    case halfOpen // Testing recovery
}
```

---

## 💡 Examples

### E-Commerce App Example

```swift
import MicroservicesClient

class ECommerceClient {
    private let manager = MicroservicesClientManager()
    
    func initialize() {
        // Register services
        let services: [Microservice] = [
            Microservice(id: "product-1", name: "Product Service", type: .custom("product"), endpoint: URL(string: "https://products.api.com")!),
            Microservice(id: "cart-1", name: "Cart Service", type: .custom("cart"), endpoint: URL(string: "https://cart.api.com")!),
            Microservice(id: "payment-1", name: "Payment Service", type: .payment, endpoint: URL(string: "https://payment.api.com")!)
        ]
        
        for service in services {
            manager.registerService(service) { _ in }
        }
    }
    
    func checkout(cartId: String) async throws -> OrderConfirmation {
        // Load balance to payment service
        return try await withCheckedThrowingContinuation { continuation in
            manager.balanceLoad(serviceType: .payment, strategy: .leastConnections) { result in
                switch result {
                case .success(let service):
                    // Execute payment request with circuit breaker
                    let request = ServiceRequest(
                        serviceId: service.id,
                        method: "POST",
                        path: "/checkout",
                        body: try? JSONEncoder().encode(["cartId": cartId])
                    )
                    
                    self.manager.executeWithCircuitBreaker(serviceId: service.id, request: request) { (result: Result<OrderConfirmation, MicroservicesError>) in
                        continuation.resume(with: result.mapError { $0 as Error })
                    }
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

### Health Monitoring Example

```swift
import MicroservicesClient

class HealthMonitor {
    private let manager: MicroservicesClientManager
    private var timer: Timer?
    
    init(manager: MicroservicesClientManager) {
        self.manager = manager
    }
    
    func startMonitoring(interval: TimeInterval = 30.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
    }
    
    private func checkHealth() {
        manager.monitorPerformance { result in
            switch result {
            case .success(let metrics):
                print("📊 Performance Report:")
                print("  Services: \(metrics.serviceCount)")
                print("  Active Connections: \(metrics.activeConnections)")
                print("  Circuit Breaker: \(metrics.circuitBreakerStatus)")
                print("  Avg Response Time: \(metrics.averageResponseTime)ms")
                
            case .failure(let error):
                print("❌ Monitoring failed: \(error)")
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}
```

---

## 🏗️ Architecture

```
iOS-Microservices-Client-Framework/
├── Sources/
│   ├── Microservices/
│   │   └── MicroservicesClientManager.swift  # Main client manager
│   ├── Core/
│   │   └── MainFramework.swift               # Core framework
│   └── Analytics/                             # Analytics module
├── Tests/
│   ├── MicroservicesClientTests/             # Client tests
│   ├── MicroservicesClientCoreTests/         # Core tests
│   └── MicroservicesClientPerformanceTests/  # Performance tests
└── Examples/
    ├── CircuitBreakerExamples/               # Circuit breaker usage
    ├── CachingExamples/                      # Caching patterns
    └── ECommerceAppExample.swift             # Full app example
```

---

## 📋 Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS      | 15.0+           |
| macOS    | 12.0+           |
| watchOS  | 8.0+            |
| tvOS     | 15.0+           |
| Swift    | 5.9+            |
| Xcode    | 15.0+           |

### Dependencies

- [Swift-NIO](https://github.com/apple/swift-nio) — High-performance networking
- [Swift-Log](https://github.com/apple/swift-log) — Server-side logging
- [Swift-Crypto](https://github.com/apple/swift-crypto) — Cryptographic operations

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built for distributed iOS applications**

⭐ Star this repository if you find it helpful!

</div>
