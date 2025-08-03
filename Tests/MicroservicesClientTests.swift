import XCTest
@testable import MicroservicesClient
@testable import ServiceDiscovery
@testable import LoadBalancing
@testable import CircuitBreaker
@testable import HealthMonitoring

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class MicroservicesClientTests: XCTestCase {
    
    var client: MicroservicesClient!
    var configuration: MicroservicesConfiguration!
    
    override func setUp() {
        super.setUp()
        
        let serviceDiscoveryConfig = ServiceDiscoveryConfiguration(
            discoveryInterval: 1.0,
            timeout: 5.0,
            maxCacheSize: 100,
            enableHealthChecking: true
        )
        
        configuration = MicroservicesConfiguration(
            serviceDiscovery: serviceDiscoveryConfig,
            loadBalancingStrategy: .roundRobin,
            circuitBreaker: CircuitBreakerConfiguration(),
            healthMonitoring: HealthMonitoringConfiguration()
        )
        
        client = MicroservicesClient(configuration: configuration)
    }
    
    override func tearDown() {
        client = nil
        configuration = nil
        super.tearDown()
    }
    
    // MARK: - MicroservicesClient Tests
    
    func testMicroservicesClientInitialization() {
        XCTAssertNotNil(client)
        XCTAssertNotNil(client.serviceDiscovery)
        XCTAssertNotNil(client.loadBalancer)
        XCTAssertNotNil(client.circuitBreaker)
        XCTAssertNotNil(client.healthMonitor)
    }
    
    func testServiceRegistration() {
        let expectation = XCTestExpectation(description: "Service registration")
        
        let service = ServiceDefinition(
            name: "test-service",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://test-service-1.com",
                    host: "test-service-1.com",
                    port: 443
                )
            ]
        )
        
        client.registerService(service) { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testServiceDiscovery() {
        let expectation = XCTestExpectation(description: "Service discovery")
        
        let service = ServiceDefinition(
            name: "discovery-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://discovery-test-1.com",
                    host: "discovery-test-1.com",
                    port: 443
                )
            ]
        )
        
        client.registerService(service) { [weak self] result in
            switch result {
            case .success:
                self?.client.discoverServices { result in
                    switch result {
                    case .success(let services):
                        XCTAssertFalse(services.isEmpty)
                        XCTAssertTrue(services.contains { $0.name == "discovery-test" })
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Service discovery failed: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testLoadBalancing() {
        let service = ServiceDefinition(
            name: "load-balance-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://lb-test-1.com",
                    host: "lb-test-1.com",
                    port: 443
                ),
                ServiceInstance(
                    id: "instance-2",
                    endpoint: "https://lb-test-2.com",
                    host: "lb-test-2.com",
                    port: 443
                )
            ]
        )
        
        client.registerService(service) { [weak self] result in
            switch result {
            case .success:
                self?.client.serviceDiscovery.getServiceInstances(for: "load-balance-test") { result in
                    switch result {
                    case .success(let instances):
                        XCTAssertEqual(instances.count, 2)
                        
                        // Test load balancing
                        let selectedInstance = self?.client.loadBalancer.selectInstance(from: instances)
                        XCTAssertNotNil(selectedInstance)
                        XCTAssertTrue(instances.contains { $0.id == selectedInstance?.id })
                        
                    case .failure(let error):
                        XCTFail("Failed to get service instances: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
    }
    
    func testCircuitBreaker() {
        let service = ServiceDefinition(
            name: "circuit-breaker-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://cb-test-1.com",
                    host: "cb-test-1.com",
                    port: 443
                )
            ]
        )
        
        client.registerService(service) { [weak self] result in
            switch result {
            case .success:
                // Initially circuit should be closed
                XCTAssertTrue(self?.client.circuitBreaker.isClosed(for: "circuit-breaker-test") ?? false)
                
                // Record some failures
                for _ in 0..<5 {
                    self?.client.circuitBreaker.recordFailure(for: "circuit-breaker-test")
                }
                
                // Circuit should be open after 5 failures
                XCTAssertTrue(self?.client.circuitBreaker.isOpen(for: "circuit-breaker-test") ?? false)
                
                // Reset circuit
                self?.client.circuitBreaker.reset(for: "circuit-breaker-test")
                XCTAssertTrue(self?.client.circuitBreaker.isClosed(for: "circuit-breaker-test") ?? false)
                
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
    }
    
    func testHealthMonitoring() {
        let expectation = XCTestExpectation(description: "Health monitoring")
        
        let service = ServiceDefinition(
            name: "health-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://health-test-1.com",
                    host: "health-test-1.com",
                    port: 443
                )
            ]
        )
        
        client.registerService(service) { [weak self] result in
            switch result {
            case .success:
                self?.client.getHealthStatus { result in
                    switch result {
                    case .success(let statuses):
                        XCTAssertFalse(statuses.isEmpty)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Health monitoring failed: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConfigurationUpdate() {
        let newServiceDiscoveryConfig = ServiceDiscoveryConfiguration(
            discoveryInterval: 60.0,
            timeout: 15.0,
            maxCacheSize: 500,
            enableHealthChecking: false
        )
        
        let newConfiguration = MicroservicesConfiguration(
            serviceDiscovery: newServiceDiscoveryConfig,
            loadBalancingStrategy: .leastConnections,
            circuitBreaker: CircuitBreakerConfiguration(failureThreshold: 10),
            healthMonitoring: HealthMonitoringConfiguration(monitoringInterval: 60.0)
        )
        
        client.updateConfiguration(newConfiguration)
        
        // Verify configuration was updated
        XCTAssertEqual(client.configuration.serviceDiscovery.discoveryInterval, 60.0)
        XCTAssertEqual(client.configuration.loadBalancingStrategy, .leastConnections)
    }
    
    func testErrorHandling() {
        let expectation = XCTestExpectation(description: "Error handling")
        
        // Test with invalid service name
        let invalidService = ServiceDefinition(
            name: "",
            version: "1.0.0",
            instances: []
        )
        
        client.registerService(invalidService) { result in
            switch result {
            case .success:
                XCTFail("Should have failed with invalid service name")
            case .failure(let error):
                XCTAssertEqual(error, .serviceDiscoveryError("Invalid service name"))
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPerformance() {
        let expectation = XCTestExpectation(description: "Performance test")
        
        let startTime = Date()
        
        let service = ServiceDefinition(
            name: "performance-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://perf-test-1.com",
                    host: "perf-test-1.com",
                    port: 443
                )
            ]
        )
        
        client.registerService(service) { [weak self] result in
            switch result {
            case .success:
                let endTime = Date()
                let executionTime = endTime.timeIntervalSince(startTime)
                
                // Performance should be under 1 second
                XCTAssertLessThan(executionTime, 1.0)
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Performance test failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - ServiceDiscovery Tests

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class ServiceDiscoveryTests: XCTestCase {
    
    var serviceDiscovery: ServiceDiscoveryManager!
    var configuration: ServiceDiscoveryConfiguration!
    
    override func setUp() {
        super.setUp()
        
        configuration = ServiceDiscoveryConfiguration(
            discoveryInterval: 1.0,
            timeout: 5.0,
            maxCacheSize: 100,
            enableHealthChecking: true
        )
        
        serviceDiscovery = ServiceDiscoveryManager(configuration: configuration)
    }
    
    override func tearDown() {
        serviceDiscovery = nil
        configuration = nil
        super.tearDown()
    }
    
    func testServiceRegistration() {
        let expectation = XCTestExpectation(description: "Service registration")
        
        let service = ServiceDefinition(
            name: "test-service",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://test-service-1.com",
                    host: "test-service-1.com",
                    port: 443
                )
            ]
        )
        
        serviceDiscovery.registerService(service) { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testServiceDiscovery() {
        let expectation = XCTestExpectation(description: "Service discovery")
        
        let service = ServiceDefinition(
            name: "discovery-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://discovery-test-1.com",
                    host: "discovery-test-1.com",
                    port: 443
                )
            ]
        )
        
        serviceDiscovery.registerService(service) { [weak self] result in
            switch result {
            case .success:
                self?.serviceDiscovery.discoverServices { result in
                    switch result {
                    case .success(let services):
                        XCTAssertFalse(services.isEmpty)
                        XCTAssertTrue(services.contains { $0.name == "discovery-test" })
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Service discovery failed: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - LoadBalancing Tests

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class LoadBalancingTests: XCTestCase {
    
    var loadBalancer: LoadBalancer!
    
    override func setUp() {
        super.setUp()
        loadBalancer = LoadBalancer(strategy: .roundRobin)
    }
    
    override func tearDown() {
        loadBalancer = nil
        super.tearDown()
    }
    
    func testRoundRobinLoadBalancing() {
        let instances = [
            ServiceInstance(id: "1", endpoint: "https://instance-1.com", host: "instance-1.com", port: 443),
            ServiceInstance(id: "2", endpoint: "https://instance-2.com", host: "instance-2.com", port: 443),
            ServiceInstance(id: "3", endpoint: "https://instance-3.com", host: "instance-3.com", port: 443)
        ]
        
        let selected1 = loadBalancer.selectInstance(from: instances)
        let selected2 = loadBalancer.selectInstance(from: instances)
        let selected3 = loadBalancer.selectInstance(from: instances)
        let selected4 = loadBalancer.selectInstance(from: instances)
        
        XCTAssertNotNil(selected1)
        XCTAssertNotNil(selected2)
        XCTAssertNotNil(selected3)
        XCTAssertNotNil(selected4)
        
        // Round robin should cycle through instances
        XCTAssertEqual(selected1.id, "1")
        XCTAssertEqual(selected2.id, "2")
        XCTAssertEqual(selected3.id, "3")
        XCTAssertEqual(selected4.id, "1")
    }
    
    func testRandomLoadBalancing() {
        loadBalancer.updateStrategy(.random)
        
        let instances = [
            ServiceInstance(id: "1", endpoint: "https://instance-1.com", host: "instance-1.com", port: 443),
            ServiceInstance(id: "2", endpoint: "https://instance-2.com", host: "instance-2.com", port: 443)
        ]
        
        let selected1 = loadBalancer.selectInstance(from: instances)
        let selected2 = loadBalancer.selectInstance(from: instances)
        
        XCTAssertNotNil(selected1)
        XCTAssertNotNil(selected2)
        XCTAssertTrue(instances.contains { $0.id == selected1.id })
        XCTAssertTrue(instances.contains { $0.id == selected2.id })
    }
}

// MARK: - CircuitBreaker Tests

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class CircuitBreakerTests: XCTestCase {
    
    var circuitBreaker: CircuitBreaker!
    var configuration: CircuitBreakerConfiguration!
    
    override func setUp() {
        super.setUp()
        
        configuration = CircuitBreakerConfiguration(
            failureThreshold: 3,
            timeout: 60.0,
            successThreshold: 2,
            halfOpenRequestLimit: 1,
            enabled: true
        )
        
        circuitBreaker = CircuitBreaker(configuration: configuration)
    }
    
    override func tearDown() {
        circuitBreaker = nil
        configuration = nil
        super.tearDown()
    }
    
    func testCircuitBreakerStates() {
        let serviceName = "test-service"
        
        // Initially circuit should be closed
        XCTAssertTrue(circuitBreaker.isClosed(for: serviceName))
        XCTAssertFalse(circuitBreaker.isOpen(for: serviceName))
        XCTAssertFalse(circuitBreaker.isHalfOpen(for: serviceName))
    }
    
    func testCircuitBreakerFailureThreshold() {
        let serviceName = "test-service"
        
        // Record failures up to threshold
        for i in 1...3 {
            circuitBreaker.recordFailure(for: serviceName)
            
            if i < 3 {
                XCTAssertTrue(circuitBreaker.isClosed(for: serviceName))
            } else {
                XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
            }
        }
    }
    
    func testCircuitBreakerReset() {
        let serviceName = "test-service"
        
        // Open the circuit
        for _ in 1...3 {
            circuitBreaker.recordFailure(for: serviceName)
        }
        
        XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
        
        // Reset the circuit
        circuitBreaker.reset(for: serviceName)
        
        XCTAssertTrue(circuitBreaker.isClosed(for: serviceName))
    }
}

// MARK: - HealthMonitoring Tests

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class HealthMonitoringTests: XCTestCase {
    
    var healthMonitor: HealthMonitor!
    var configuration: HealthMonitoringConfiguration!
    
    override func setUp() {
        super.setUp()
        
        configuration = HealthMonitoringConfiguration(
            monitoringInterval: 1.0,
            timeout: 5.0,
            retryCount: 3,
            enableNotifications: true
        )
        
        healthMonitor = HealthMonitor(configuration: configuration)
    }
    
    override func tearDown() {
        healthMonitor = nil
        configuration = nil
        super.tearDown()
    }
    
    func testHealthStatusUpdate() {
        let serviceName = "test-service"
        let status = ServiceHealthStatus(
            serviceName: serviceName,
            status: .healthy,
            responseTime: 100.0,
            lastChecked: Date(),
            errorMessage: nil
        )
        
        healthMonitor.updateHealthStatus(status)
        
        let expectation = XCTestExpectation(description: "Health status retrieval")
        
        healthMonitor.getHealthStatus { result in
            switch result {
            case .success(let statuses):
                XCTAssertFalse(statuses.isEmpty)
                XCTAssertTrue(statuses.contains { $0.serviceName == serviceName })
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Health status retrieval failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testHealthMonitoringStartStop() {
        let expectation = XCTestExpectation(description: "Health monitoring")
        
        healthMonitor.startMonitoring { status in
            expectation.fulfill()
        }
        
        // Stop monitoring after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.healthMonitor.stopMonitoring()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
} 