import XCTest
@testable import LoadBalancing

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
    
    func testWeightedRoundRobinLoadBalancing() {
        loadBalancer.updateStrategy(.weightedRoundRobin)
        
        let instances = [
            ServiceInstance(id: "1", endpoint: "https://instance-1.com", host: "instance-1.com", port: 443),
            ServiceInstance(id: "2", endpoint: "https://instance-2.com", host: "instance-2.com", port: 443),
            ServiceInstance(id: "3", endpoint: "https://instance-3.com", host: "instance-3.com", port: 443)
        ]
        
        let selected1 = loadBalancer.selectInstance(from: instances)
        let selected2 = loadBalancer.selectInstance(from: instances)
        let selected3 = loadBalancer.selectInstance(from: instances)
        
        XCTAssertNotNil(selected1)
        XCTAssertNotNil(selected2)
        XCTAssertNotNil(selected3)
        XCTAssertTrue(instances.contains { $0.id == selected1.id })
        XCTAssertTrue(instances.contains { $0.id == selected2.id })
        XCTAssertTrue(instances.contains { $0.id == selected3.id })
    }
    
    func testLeastConnectionsLoadBalancing() {
        loadBalancer.updateStrategy(.leastConnections)
        
        let instances = [
            ServiceInstance(id: "1", endpoint: "https://instance-1.com", host: "instance-1.com", port: 443),
            ServiceInstance(id: "2", endpoint: "https://instance-2.com", host: "instance-2.com", port: 443),
            ServiceInstance(id: "3", endpoint: "https://instance-3.com", host: "instance-3.com", port: 443)
        ]
        
        // Record some connections
        loadBalancer.recordConnection(for: "test-service", instanceId: "1")
        loadBalancer.recordConnection(for: "test-service", instanceId: "1")
        loadBalancer.recordConnection(for: "test-service", instanceId: "2")
        
        let selected = loadBalancer.selectInstance(from: instances)
        
        // Should select instance with least connections (instance 3)
        XCTAssertEqual(selected.id, "3")
    }
    
    func testHealthBasedLoadBalancing() {
        loadBalancer.updateStrategy(.healthBased)
        
        let instances = [
            ServiceInstance(id: "1", endpoint: "https://instance-1.com", host: "instance-1.com", port: 443),
            ServiceInstance(id: "2", endpoint: "https://instance-2.com", host: "instance-2.com", port: 443),
            ServiceInstance(id: "3", endpoint: "https://instance-3.com", host: "instance-3.com", port: 443)
        ]
        
        // Update health scores
        loadBalancer.updateHealthScore(for: "test-service", instanceId: "1", healthScore: 0.8)
        loadBalancer.updateHealthScore(for: "test-service", instanceId: "2", healthScore: 0.9)
        loadBalancer.updateHealthScore(for: "test-service", instanceId: "3", healthScore: 0.7)
        
        let selected = loadBalancer.selectInstance(from: instances)
        
        // Should select instance with highest health score (instance 2)
        XCTAssertEqual(selected.id, "2")
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
    
    func testIpHashLoadBalancing() {
        loadBalancer.updateStrategy(.ipHash)
        
        let instances = [
            ServiceInstance(id: "1", endpoint: "https://instance-1.com", host: "instance-1.com", port: 443),
            ServiceInstance(id: "2", endpoint: "https://instance-2.com", host: "instance-2.com", port: 443),
            ServiceInstance(id: "3", endpoint: "https://instance-3.com", host: "instance-3.com", port: 443)
        ]
        
        let selected1 = loadBalancer.selectInstance(from: instances)
        let selected2 = loadBalancer.selectInstance(from: instances)
        
        XCTAssertNotNil(selected1)
        XCTAssertNotNil(selected2)
        XCTAssertTrue(instances.contains { $0.id == selected1.id })
        XCTAssertTrue(instances.contains { $0.id == selected2.id })
    }
    
    func testConnectionTracking() {
        let serviceName = "connection-test"
        let instanceId = "instance-1"
        
        // Record connections
        loadBalancer.recordConnection(for: serviceName, instanceId: instanceId)
        loadBalancer.recordConnection(for: serviceName, instanceId: instanceId)
        loadBalancer.recordConnection(for: serviceName, instanceId: instanceId)
        
        // Release connections
        loadBalancer.releaseConnection(for: serviceName, instanceId: instanceId)
        loadBalancer.releaseConnection(for: serviceName, instanceId: instanceId)
        
        // Should have 1 active connection
        let instances = [
            ServiceInstance(id: instanceId, endpoint: "https://instance-1.com", host: "instance-1.com", port: 443)
        ]
        
        loadBalancer.updateStrategy(.leastConnections)
        let selected = loadBalancer.selectInstance(from: instances)
        
        XCTAssertEqual(selected.id, instanceId)
    }
    
    func testHealthScoreUpdates() {
        let serviceName = "health-test"
        let instanceId = "instance-1"
        
        // Update health scores
        loadBalancer.updateHealthScore(for: serviceName, instanceId: instanceId, healthScore: 0.8)
        loadBalancer.updateHealthScore(for: serviceName, instanceId: instanceId, healthScore: 0.9)
        loadBalancer.updateHealthScore(for: serviceName, instanceId: instanceId, healthScore: 0.7)
        
        let instances = [
            ServiceInstance(id: instanceId, endpoint: "https://instance-1.com", host: "instance-1.com", port: 443)
        ]
        
        loadBalancer.updateStrategy(.healthBased)
        let selected = loadBalancer.selectInstance(from: instances)
        
        XCTAssertEqual(selected.id, instanceId)
    }
    
    func testStrategyUpdates() {
        let instances = [
            ServiceInstance(id: "1", endpoint: "https://instance-1.com", host: "instance-1.com", port: 443),
            ServiceInstance(id: "2", endpoint: "https://instance-2.com", host: "instance-2.com", port: 443)
        ]
        
        // Test round robin
        loadBalancer.updateStrategy(.roundRobin)
        let roundRobinSelected = loadBalancer.selectInstance(from: instances)
        XCTAssertEqual(roundRobinSelected.id, "1")
        
        // Test random
        loadBalancer.updateStrategy(.random)
        let randomSelected = loadBalancer.selectInstance(from: instances)
        XCTAssertTrue(instances.contains { $0.id == randomSelected.id })
        
        // Test least connections
        loadBalancer.updateStrategy(.leastConnections)
        let leastConnectionsSelected = loadBalancer.selectInstance(from: instances)
        XCTAssertTrue(instances.contains { $0.id == leastConnectionsSelected.id })
    }
    
    func testEmptyInstances() {
        let instances: [ServiceInstance] = []
        
        let selected = loadBalancer.selectInstance(from: instances)
        
        // Should return empty instance when no instances available
        XCTAssertEqual(selected.id, "")
        XCTAssertEqual(selected.endpoint, "")
        XCTAssertEqual(selected.host, "")
        XCTAssertEqual(selected.port, 0)
    }
    
    func testSingleInstance() {
        let instances = [
            ServiceInstance(id: "1", endpoint: "https://instance-1.com", host: "instance-1.com", port: 443)
        ]
        
        let selected = loadBalancer.selectInstance(from: instances)
        
        XCTAssertEqual(selected.id, "1")
        XCTAssertEqual(selected.endpoint, "https://instance-1.com")
        XCTAssertEqual(selected.host, "instance-1.com")
        XCTAssertEqual(selected.port, 443)
    }
} 