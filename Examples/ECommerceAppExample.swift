import SwiftUI
import MicroservicesClient

@available(iOS 15.0, *)
struct ECommerceAppExample: View {
    @StateObject private var ecommerceManager = ECommerceManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Products Tab
            ProductsView(ecommerceManager: ecommerceManager)
                .tabItem {
                    Image(systemName: "bag")
                    Text("Products")
                }
                .tag(0)
            
            // Cart Tab
            CartView(ecommerceManager: ecommerceManager)
                .tabItem {
                    Image(systemName: "cart")
                    Text("Cart")
                }
                .tag(1)
            
            // Orders Tab
            OrdersView(ecommerceManager: ecommerceManager)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Orders")
                }
                .tag(2)
            
            // Profile Tab
            ProfileView(ecommerceManager: ecommerceManager)
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
                .tag(3)
        }
        .onAppear {
            ecommerceManager.initializeServices()
        }
    }
}

@available(iOS 15.0, *)
class ECommerceManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var cart: [CartItem] = []
    @Published var orders: [Order] = []
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let microservicesManager = MicroservicesClientManager()
    
    func initializeServices() {
        // Discover and register microservices
        microservicesManager.discoverServices { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let services):
                    print("Discovered \(services.count) services")
                    self?.loadInitialData()
                case .failure(let error):
                    self?.errorMessage = "Service discovery failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadInitialData() {
        isLoading = true
        
        // Load products
        loadProducts()
        
        // Load user profile
        loadUserProfile()
        
        // Load cart
        loadCart()
        
        // Load orders
        loadOrders()
    }
    
    func loadProducts() {
        let request = ServiceRequest(
            serviceId: "product-service",
            method: "GET",
            path: "/products",
            headers: ["Authorization": "Bearer user-token"]
        )
        
        microservicesManager.executeRequest(serviceId: "product-service", request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Parse products from response
                    self?.products = self?.parseProducts(from: response) ?? []
                case .failure(let error):
                    self?.errorMessage = "Failed to load products: \(error.localizedDescription)"
                }
                self?.isLoading = false
            }
        }
    }
    
    func loadUserProfile() {
        let request = ServiceRequest(
            serviceId: "user-service",
            method: "GET",
            path: "/users/profile",
            headers: ["Authorization": "Bearer user-token"]
        )
        
        microservicesManager.executeRequest(serviceId: "user-service", request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Parse user from response
                    self?.user = self?.parseUser(from: response)
                case .failure(let error):
                    self?.errorMessage = "Failed to load user profile: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func loadCart() {
        let request = ServiceRequest(
            serviceId: "cart-service",
            method: "GET",
            path: "/cart",
            headers: ["Authorization": "Bearer user-token"]
        )
        
        microservicesManager.executeRequest(serviceId: "cart-service", request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Parse cart from response
                    self?.cart = self?.parseCart(from: response) ?? []
                case .failure(let error):
                    self?.errorMessage = "Failed to load cart: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func loadOrders() {
        let request = ServiceRequest(
            serviceId: "order-service",
            method: "GET",
            path: "/orders",
            headers: ["Authorization": "Bearer user-token"]
        )
        
        microservicesManager.executeRequest(serviceId: "order-service", request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Parse orders from response
                    self?.orders = self?.parseOrders(from: response) ?? []
                case .failure(let error):
                    self?.errorMessage = "Failed to load orders: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func addToCart(product: Product, quantity: Int = 1) {
        let request = ServiceRequest(
            serviceId: "cart-service",
            method: "POST",
            path: "/cart/items",
            headers: ["Authorization": "Bearer user-token"],
            body: """
            {
                "productId": "\(product.id)",
                "quantity": \(quantity)
            }
            """.data(using: .utf8)
        )
        
        microservicesManager.executeRequest(serviceId: "cart-service", request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadCart() // Refresh cart
                case .failure(let error):
                    self?.errorMessage = "Failed to add to cart: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func placeOrder() {
        let request = ServiceRequest(
            serviceId: "order-service",
            method: "POST",
            path: "/orders",
            headers: ["Authorization": "Bearer user-token"],
            body: """
            {
                "items": \(cart.map { $0.toJSON() }.joined(separator: ","))
            }
            """.data(using: .utf8)
        )
        
        microservicesManager.executeRequest(serviceId: "order-service", request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.cart = [] // Clear cart
                    self?.loadOrders() // Refresh orders
                case .failure(let error):
                    self?.errorMessage = "Failed to place order: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Parsing Methods
    
    private func parseProducts(from response: ServiceResponse) -> [Product] {
        // Mock parsing - in real app, parse JSON response
        return [
            Product(id: "1", name: "iPhone 15 Pro", price: 999.99, description: "Latest iPhone", imageURL: "iphone15pro"),
            Product(id: "2", name: "MacBook Pro", price: 1999.99, description: "Powerful laptop", imageURL: "macbookpro"),
            Product(id: "3", name: "AirPods Pro", price: 249.99, description: "Wireless earbuds", imageURL: "airpodspro")
        ]
    }
    
    private func parseUser(from response: ServiceResponse) -> User? {
        // Mock parsing - in real app, parse JSON response
        return User(id: "user123", name: "John Doe", email: "john@example.com")
    }
    
    private func parseCart(from response: ServiceResponse) -> [CartItem] {
        // Mock parsing - in real app, parse JSON response
        return []
    }
    
    private func parseOrders(from response: ServiceResponse) -> [Order] {
        // Mock parsing - in real app, parse JSON response
        return []
    }
}

// MARK: - Data Models

@available(iOS 15.0, *)
struct Product: Identifiable {
    let id: String
    let name: String
    let price: Double
    let description: String
    let imageURL: String
}

@available(iOS 15.0, *)
struct User: Identifiable {
    let id: String
    let name: String
    let email: String
}

@available(iOS 15.0, *)
struct CartItem: Identifiable {
    let id: String
    let productId: String
    let quantity: Int
    let price: Double
    
    func toJSON() -> String {
        return """
        {
            "id": "\(id)",
            "productId": "\(productId)",
            "quantity": \(quantity),
            "price": \(price)
        }
        """
    }
}

@available(iOS 15.0, *)
struct Order: Identifiable {
    let id: String
    let items: [CartItem]
    let total: Double
    let status: OrderStatus
    let createdAt: Date
    
    enum OrderStatus: String {
        case pending = "pending"
        case confirmed = "confirmed"
        case shipped = "shipped"
        case delivered = "delivered"
    }
}

// MARK: - Views

@available(iOS 15.0, *)
struct ProductsView: View {
    @ObservedObject var ecommerceManager: ECommerceManager
    
    var body: some View {
        NavigationView {
            List(ecommerceManager.products) { product in
                ProductRow(product: product) {
                    ecommerceManager.addToCart(product: product)
                }
            }
            .navigationTitle("Products")
            .refreshable {
                ecommerceManager.loadProducts()
            }
        }
    }
}

@available(iOS 15.0, *)
struct ProductRow: View {
    let product: Product
    let onAddToCart: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "photo")
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("$\(product.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Button("Add") {
                onAddToCart()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 15.0, *)
struct CartView: View {
    @ObservedObject var ecommerceManager: ECommerceManager
    
    var body: some View {
        NavigationView {
            VStack {
                if ecommerceManager.cart.isEmpty {
                    VStack {
                        Image(systemName: "cart")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Your cart is empty")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(ecommerceManager.cart) { item in
                        CartItemRow(item: item)
                    }
                    
                    VStack {
                        HStack {
                            Text("Total:")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("$\(ecommerceManager.cart.reduce(0) { $0 + $1.price * Double($1.quantity) }, specifier: "%.2f")")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        
                        Button("Place Order") {
                            ecommerceManager.placeOrder()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
            }
            .navigationTitle("Cart")
            .refreshable {
                ecommerceManager.loadCart()
            }
        }
    }
}

@available(iOS 15.0, *)
struct CartItemRow: View {
    let item: CartItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Product \(item.productId)")
                    .font(.headline)
                
                Text("Quantity: \(item.quantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(item.price * Double(item.quantity), specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

@available(iOS 15.0, *)
struct OrdersView: View {
    @ObservedObject var ecommerceManager: ECommerceManager
    
    var body: some View {
        NavigationView {
            List(ecommerceManager.orders) { order in
                OrderRow(order: order)
            }
            .navigationTitle("Orders")
            .refreshable {
                ecommerceManager.loadOrders()
            }
        }
    }
}

@available(iOS 15.0, *)
struct OrderRow: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order #\(order.id)")
                    .font(.headline)
                
                Spacer()
                
                Text(order.status.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            Text("\(order.items.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Total: $\(order.total, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch order.status {
        case .pending: return .orange
        case .confirmed: return .blue
        case .shipped: return .purple
        case .delivered: return .green
        }
    }
}

@available(iOS 15.0, *)
struct ProfileView: View {
    @ObservedObject var ecommerceManager: ECommerceManager
    
    var body: some View {
        NavigationView {
            VStack {
                if let user = ecommerceManager.user {
                    VStack(spacing: 20) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 8) {
                            Text(user.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                ecommerceManager.loadUserProfile()
            }
        }
    }
}

@available(iOS 15.0, *)
struct ECommerceAppExample_Previews: PreviewProvider {
    static var previews: some View {
        ECommerceAppExample()
    }
} 