import Foundation
import MicroservicesClient
import ServiceDiscovery
import LoadBalancing
import CircuitBreaker
import HealthMonitoring

/// Advanced example demonstrating enterprise features of the iOS Microservices Client Framework
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
class AdvancedExample {
    
    private var client: MicroservicesClient!
    private var healthCallback: ((ServiceHealthStatus) -> Void)?
    
    init() {
        setupAdvancedClient()
    }
    
    private func setupAdvancedClient() {
        // Advanced service discovery configuration
        let serviceDiscoveryConfig = ServiceDiscoveryConfiguration(
            discoveryInterval: 15.0,  // More frequent discovery
            timeout: 5.0,
            maxCacheSize: 2000,       // Larger cache for enterprise
            enableHealthChecking: true
        )
        
        // Advanced circuit breaker configuration
        let circuitBreakerConfig = CircuitBreakerConfiguration(
            failureThreshold: 3,      // Lower threshold for faster failure detection
            timeout: 30.0,            // Shorter timeout for faster recovery
            successThreshold: 2,      // Fewer successes needed to close
            halfOpenRequestLimit: 1,
            enabled: true
        )
        
        // Advanced health monitoring configuration
        let healthConfig = HealthMonitoringConfiguration(
            monitoringInterval: 15.0, // More frequent health checks
            timeout: 5.0,
            retryCount: 5,            // More retries for reliability
            enableNotifications: true
        )
        
        // Advanced configuration with health-based load balancing
        let configuration = MicroservicesConfiguration(
            serviceDiscovery: serviceDiscoveryConfig,
            loadBalancingStrategy: .healthBased,  // Use health-based strategy
            circuitBreaker: circuitBreakerConfig,
            healthMonitoring: healthConfig
        )
        
        client = MicroservicesClient(configuration: configuration)
        
        print("✅ Advanced MicroservicesClient initialized successfully")
    }
    
    func runAdvancedExample() {
        print("\n🚀 Running Advanced Example")
        print("============================")
        
        // Step 1: Register multiple services with different configurations
        registerAdvancedServices()
        
        // Step 2: Demonstrate advanced load balancing
        demonstrateAdvancedLoadBalancing()
        
        // Step 3: Show circuit breaker patterns
        demonstrateCircuitBreakerPatterns()
        
        // Step 4: Advanced health monitoring
        demonstrateAdvancedHealthMonitoring()
        
        // Step 5: Dynamic configuration updates
        demonstrateDynamicConfiguration()
        
        // Step 6: Performance monitoring
        demonstratePerformanceMonitoring()
    }
    
    private func registerAdvancedServices() {
        print("\n📝 Registering Advanced Services")
        print("-------------------------------")
        
        // Register User Service with multiple instances
        let userService = ServiceDefinition(
            name: "user-service",
            version: "2.0.0",
            instances: [
                ServiceInstance(
                    id: "user-service-1",
                    endpoint: "https://user-service-1.prod.example.com",
                    host: "user-service-1.prod.example.com",
                    port: 443,
                    healthStatus: .healthy,
                    metadata: ["region": "us-east-1", "zone": "a", "version": "2.0.0"]
                ),
                ServiceInstance(
                    id: "user-service-2",
                    endpoint: "https://user-service-2.prod.example.com",
                    host: "user-service-2.prod.example.com",
                    port: 443,
                    healthStatus: .healthy,
                    metadata: ["region": "us-east-1", "zone": "b", "version": "2.0.0"]
                ),
                ServiceInstance(
                    id: "user-service-3",
                    endpoint: "https://user-service-3.prod.example.com",
                    host: "user-service-3.prod.example.com",
                    port: 443,
                    healthStatus: .healthy,
                    metadata: ["region": "us-west-2", "zone": "a", "version": "2.0.0"]
                )
            ],
            metadata: ["service-type": "user-management", "criticality": "high"]
        )
        
        // Register Payment Service with different health statuses
        let paymentService = ServiceDefinition(
            name: "payment-service",
            version: "1.5.0",
            instances: [
                ServiceInstance(
                    id: "payment-service-1",
                    endpoint: "https://payment-service-1.prod.example.com",
                    host: "payment-service-1.prod.example.com",
                    port: 443,
                    healthStatus: .healthy,
                    metadata: ["region": "us-east-1", "zone": "a", "version": "1.5.0"]
                ),
                ServiceInstance(
                    id: "payment-service-2",
                    endpoint: "https://payment-service-2.prod.example.com",
                    host: "payment-service-2.prod.example.com",
                    port: 443,
                    healthStatus: .unhealthy,
                    metadata: ["region": "us-east-1", "zone": "b", "version": "1.5.0"]
                )
            ],
            metadata: ["service-type": "payment-processing", "criticality": "critical"]
        )
        
        // Register Notification Service
        let notificationService = ServiceDefinition(
            name: "notification-service",
            version: "1.2.0",
            instances: [
                ServiceInstance(
                    id: "notification-service-1",
                    endpoint: "https://notification-service-1.prod.example.com",
                    host: "notification-service-1.prod.example.com",
                    port: 443,
                    healthStatus: .healthy,
                    metadata: ["region": "us-east-1", "zone": "a", "version": "1.2.0"]
                )
            ],
            metadata: ["service-type": "notifications", "criticality": "medium"]
        )
        
        let services = [userService, paymentService, notificationService]
        
        for service in services {
            client.registerService(service) { result in
                switch result {
                case .success:
                    print("✅ \(service.name) registered successfully (\(service.instances.count) instances)")
                case .failure(let error):
                    print("❌ \(service.name) registration failed: \(error)")
                }
            }
        }
    }
    
    private func demonstrateAdvancedLoadBalancing() {
        print("\n⚖️ Demonstrating Advanced Load Balancing")
        print("----------------------------------------")
        
        // Get instances for user service
        client.serviceDiscovery.getServiceInstances(for: "user-service") { result in
            switch result {
            case .success(let instances):
                print("📊 User service instances:")
                for instance in instances {
                    let healthIcon = instance.healthStatus == .healthy ? "🟢" : "🔴"
                    print("   \(healthIcon) \(instance.id) (\(instance.host))")
                    print("      📍 Region: \(instance.metadata["region"] ?? "unknown")")
                    print("      🏷️ Zone: \(instance.metadata["zone"] ?? "unknown")")
                    print("      📦 Version: \(instance.metadata["version"] ?? "unknown")")
                }
                
                // Demonstrate health-based load balancing
                print("\n🎯 Health-based load balancing selection:")
                for i in 1...5 {
                    let selected = self.client.loadBalancer.selectInstance(from: instances)
                    print("   Selection \(i): \(selected.id) (\(selected.host))")
                }
                
            case .failure(let error):
                print("❌ Failed to get service instances: \(error)")
            }
        }
    }
    
    private func demonstrateCircuitBreakerPatterns() {
        print("\n🛡️ Demonstrating Circuit Breaker Patterns")
        print("------------------------------------------")
        
        let serviceName = "payment-service"
        
        // Simulate circuit breaker behavior
        print("📈 Simulating circuit breaker for \(serviceName):")
        
        // Initially closed
        print("   🔵 Initial state: \(client.circuitBreaker.getCircuitState(for: serviceName).rawValue)")
        
        // Record some failures
        for i in 1...3 {
            client.circuitBreaker.recordFailure(for: serviceName)
            let state = client.circuitBreaker.getCircuitState(for: serviceName)
            print("   🔴 After failure \(i): \(state.rawValue)")
        }
        
        // Circuit should be open now
        let openState = client.circuitBreaker.getCircuitState(for: serviceName)
        print("   🔴 Circuit state: \(openState.rawValue)")
        
        // Reset circuit
        client.circuitBreaker.reset(for: serviceName)
        let resetState = client.circuitBreaker.getCircuitState(for: serviceName)
        print("   🔵 After reset: \(resetState.rawValue)")
        
        // Show statistics
        let stats = client.circuitBreaker.getStatistics(for: serviceName)
        print("   📊 Statistics: \(stats.totalRequests) requests, \(stats.totalFailures) failures, \(String(format: "%.1f", stats.failureRate * 100))% failure rate")
    }
    
    private func demonstrateAdvancedHealthMonitoring() {
        print("\n📊 Demonstrating Advanced Health Monitoring")
        print("--------------------------------------------")
        
        // Subscribe to health updates
        client.healthMonitor.subscribeToHealthUpdates(for: "user-service") { status in
            let healthIcon = status.status == .healthy ? "🟢" : "🔴"
            print("   \(healthIcon) Health update for \(status.serviceName):")
            print("      ⏱️ Response time: \(String(format: "%.2f", status.responseTime))ms")
            print("      📅 Last checked: \(status.lastChecked)")
            if let error = status.errorMessage {
                print("      ⚠️ Error: \(error)")
            }
        }
        
        // Get comprehensive health status
        client.getHealthStatus { result in
            switch result {
            case .success(let statuses):
                print("📈 Overall health status:")
                for status in statuses {
                    let healthIcon = status.status == .healthy ? "🟢" : "🔴"
                    let criticality = getCriticality(for: status.serviceName)
                    print("   \(healthIcon) \(status.serviceName) (\(criticality)):")
                    print("      ⏱️ Response time: \(String(format: "%.2f", status.responseTime))ms")
                    print("      📊 Status: \(status.status.rawValue)")
                }
                
            case .failure(let error):
                print("❌ Health monitoring failed: \(error)")
            }
        }
    }
    
    private func demonstrateDynamicConfiguration() {
        print("\n⚙️ Demonstrating Dynamic Configuration Updates")
        print("----------------------------------------------")
        
        // Create new configuration with different settings
        let newServiceDiscoveryConfig = ServiceDiscoveryConfiguration(
            discoveryInterval: 60.0,  // Less frequent discovery
            timeout: 10.0,
            maxCacheSize: 5000,
            enableHealthChecking: true
        )
        
        let newCircuitBreakerConfig = CircuitBreakerConfiguration(
            failureThreshold: 5,      // Higher threshold
            timeout: 120.0,           // Longer timeout
            successThreshold: 3,      // More successes needed
            halfOpenRequestLimit: 2,
            enabled: true
        )
        
        let newHealthConfig = HealthMonitoringConfiguration(
            monitoringInterval: 60.0, // Less frequent monitoring
            timeout: 10.0,
            retryCount: 3,
            enableNotifications: true
        )
        
        let newConfiguration = MicroservicesConfiguration(
            serviceDiscovery: newServiceDiscoveryConfig,
            loadBalancingStrategy: .leastConnections,  // Change strategy
            circuitBreaker: newCircuitBreakerConfig,
            healthMonitoring: newHealthConfig
        )
        
        print("🔄 Updating configuration...")
        client.updateConfiguration(newConfiguration)
        print("✅ Configuration updated successfully")
        print("   📊 New load balancing strategy: \(newConfiguration.loadBalancingStrategy.rawValue)")
        print("   🛡️ New circuit breaker threshold: \(newCircuitBreakerConfig.failureThreshold)")
        print("   📊 New health monitoring interval: \(newHealthConfig.monitoringInterval)s")
    }
    
    private func demonstratePerformanceMonitoring() {
        print("\n📈 Demonstrating Performance Monitoring")
        print("---------------------------------------")
        
        // Simulate performance monitoring
        let startTime = Date()
        
        // Make multiple service calls to measure performance
        let requests = [
            UserRequest(userId: "user-1"),
            UserRequest(userId: "user-2"),
            UserRequest(userId: "user-3"),
            PaymentRequest(amount: 100.0, currency: "USD"),
            PaymentRequest(amount: 250.0, currency: "EUR")
        ]
        
        var completedRequests = 0
        let totalRequests = requests.count
        
        for (index, request) in requests.enumerated() {
            let serviceName = index < 3 ? "user-service" : "payment-service"
            
            client.callService(serviceName, request: request) { result in
                completedRequests += 1
                
                switch result {
                case .success(let response):
                    print("   ✅ Request \(completedRequests)/\(totalRequests) completed successfully")
                case .failure(let error):
                    print("   ❌ Request \(completedRequests)/\(totalRequests) failed: \(error)")
                }
                
                if completedRequests == totalRequests {
                    let endTime = Date()
                    let totalTime = endTime.timeIntervalSince(startTime)
                    let avgTime = totalTime / Double(totalRequests)
                    
                    print("\n📊 Performance Summary:")
                    print("   ⏱️ Total time: \(String(format: "%.2f", totalTime))s")
                    print("   📊 Average time per request: \(String(format: "%.2f", avgTime))s")
                    print("   🚀 Requests per second: \(String(format: "%.2f", Double(totalRequests) / totalTime))")
                }
            }
        }
    }
    
    private func getCriticality(for serviceName: String) -> String {
        switch serviceName {
        case "payment-service":
            return "CRITICAL"
        case "user-service":
            return "HIGH"
        case "notification-service":
            return "MEDIUM"
        default:
            return "LOW"
        }
    }
}

// MARK: - Request/Response Types

struct UserRequest: Codable {
    let userId: String
}

struct UserResponse: Codable {
    let id: String
    let name: String
    let email: String
    let profile: UserProfile
}

struct UserProfile: Codable {
    let avatar: String
    let preferences: [String: String]
}

struct PaymentRequest: Codable {
    let amount: Double
    let currency: String
    let paymentMethod: String
}

struct PaymentResponse: Codable {
    let transactionId: String
    let status: String
    let amount: Double
    let currency: String
    let timestamp: Date
}

// MARK: - Usage Example

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
func runAdvancedExample() {
    let example = AdvancedExample()
    example.runAdvancedExample()
}

// Example usage in your app:
// runAdvancedExample() 