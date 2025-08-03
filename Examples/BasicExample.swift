import Foundation
import MicroservicesClient
import ServiceDiscovery
import LoadBalancing
import CircuitBreaker
import HealthMonitoring

/// Basic example demonstrating the iOS Microservices Client Framework
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
class BasicExample {
    
    private var client: MicroservicesClient!
    
    init() {
        setupClient()
    }
    
    private func setupClient() {
        // Configure service discovery
        let serviceDiscoveryConfig = ServiceDiscoveryConfiguration(
            discoveryInterval: 30.0,
            timeout: 10.0,
            maxCacheSize: 1000,
            enableHealthChecking: true
        )
        
        // Configure circuit breaker
        let circuitBreakerConfig = CircuitBreakerConfiguration(
            failureThreshold: 5,
            timeout: 60.0,
            successThreshold: 3,
            halfOpenRequestLimit: 1,
            enabled: true
        )
        
        // Configure health monitoring
        let healthConfig = HealthMonitoringConfiguration(
            monitoringInterval: 30.0,
            timeout: 10.0,
            retryCount: 3,
            enableNotifications: true
        )
        
        // Create main configuration
        let configuration = MicroservicesConfiguration(
            serviceDiscovery: serviceDiscoveryConfig,
            loadBalancingStrategy: .roundRobin,
            circuitBreaker: circuitBreakerConfig,
            healthMonitoring: healthConfig
        )
        
        // Initialize the client
        client = MicroservicesClient(configuration: configuration)
        
        print("✅ MicroservicesClient initialized successfully")
    }
    
    func runBasicExample() {
        print("\n🚀 Running Basic Example")
        print("=========================")
        
        // Step 1: Register services
        registerServices()
        
        // Step 2: Discover services
        discoverServices()
        
        // Step 3: Make service calls
        makeServiceCalls()
        
        // Step 4: Monitor health
        monitorHealth()
    }
    
    private func registerServices() {
        print("\n📝 Registering Services")
        print("----------------------")
        
        // Register User Service
        let userService = ServiceDefinition(
            name: "user-service",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "user-service-1",
                    endpoint: "https://user-service-1.example.com",
                    host: "user-service-1.example.com",
                    port: 443
                ),
                ServiceInstance(
                    id: "user-service-2",
                    endpoint: "https://user-service-2.example.com",
                    host: "user-service-2.example.com",
                    port: 443
                )
            ]
        )
        
        client.registerService(userService) { result in
            switch result {
            case .success:
                print("✅ User service registered successfully")
            case .failure(let error):
                print("❌ User service registration failed: \(error)")
            }
        }
        
        // Register Payment Service
        let paymentService = ServiceDefinition(
            name: "payment-service",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "payment-service-1",
                    endpoint: "https://payment-service-1.example.com",
                    host: "payment-service-1.example.com",
                    port: 443
                )
            ]
        )
        
        client.registerService(paymentService) { result in
            switch result {
            case .success:
                print("✅ Payment service registered successfully")
            case .failure(let error):
                print("❌ Payment service registration failed: \(error)")
            }
        }
    }
    
    private func discoverServices() {
        print("\n🔍 Discovering Services")
        print("----------------------")
        
        client.discoverServices { result in
            switch result {
            case .success(let services):
                print("✅ Discovered \(services.count) services:")
                for service in services {
                    print("   📦 \(service.name) v\(service.version) (\(service.instances.count) instances)")
                }
            case .failure(let error):
                print("❌ Service discovery failed: \(error)")
            }
        }
    }
    
    private func makeServiceCalls() {
        print("\n📞 Making Service Calls")
        print("----------------------")
        
        // Define request/response types
        struct UserRequest: Codable {
            let userId: String
        }
        
        struct UserResponse: Codable {
            let id: String
            let name: String
            let email: String
        }
        
        struct PaymentRequest: Codable {
            let amount: Double
            let currency: String
        }
        
        struct PaymentResponse: Codable {
            let transactionId: String
            let status: String
            let amount: Double
        }
        
        // Make user service call
        let userRequest = UserRequest(userId: "12345")
        
        client.callService("user-service", request: userRequest) { result in
            switch result {
            case .success(let response):
                print("✅ User service call successful:")
                print("   👤 User: \(response.name)")
                print("   📧 Email: \(response.email)")
            case .failure(let error):
                print("❌ User service call failed: \(error)")
            }
        }
        
        // Make payment service call
        let paymentRequest = PaymentRequest(amount: 99.99, currency: "USD")
        
        client.callService("payment-service", request: paymentRequest) { result in
            switch result {
            case .success(let response):
                print("✅ Payment service call successful:")
                print("   💳 Transaction ID: \(response.transactionId)")
                print("   💰 Amount: \(response.amount) \(response.currency)")
                print("   📊 Status: \(response.status)")
            case .failure(let error):
                print("❌ Payment service call failed: \(error)")
            }
        }
    }
    
    private func monitorHealth() {
        print("\n📊 Monitoring Health")
        print("-------------------")
        
        client.getHealthStatus { result in
            switch result {
            case .success(let statuses):
                print("✅ Health status retrieved:")
                for status in statuses {
                    let healthIcon = status.status == .healthy ? "🟢" : "🔴"
                    print("   \(healthIcon) \(status.serviceName): \(status.status.rawValue)")
                    print("      ⏱ Response Time: \(String(format: "%.2f", status.responseTime))ms")
                    if let errorMessage = status.errorMessage {
                        print("      ⚠️ Error: \(errorMessage)")
                    }
                }
            case .failure(let error):
                print("❌ Health monitoring failed: \(error)")
            }
        }
    }
}

// MARK: - Usage Example

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
func runBasicExample() {
    let example = BasicExample()
    example.runBasicExample()
}

// Example usage in your app:
// runBasicExample() 