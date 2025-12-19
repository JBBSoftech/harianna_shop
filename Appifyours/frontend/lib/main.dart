import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/config/environment.dart';

// Define PriceUtils class
class PriceUtils {
  static String formatPrice(double price, {String currency = '\$'}) {
    return '$currency\${price.toStringAsFixed(2)}';
  }
  
  // Extract numeric value from price string with any currency symbol
  static double parsePrice(String priceString) {
    if (priceString.isEmpty) return 0.0;
    // Remove all currency symbols and non-numeric characters except decimal point
    String numericString = priceString.replaceAll(RegExp(r'[^d.]'), '');
    return double.tryParse(numericString) ?? 0.0;
  }
  
  // Detect currency symbol from price string
  static String detectCurrency(String priceString) {
    if (priceString.contains('₹')) return '₹';
    if (priceString.contains('\$')) return '\$';
    if (priceString.contains('€')) return '€';
    if (priceString.contains('£')) return '£';
    if (priceString.contains('¥')) return '¥';
    if (priceString.contains('₩')) return '₩';
    if (priceString.contains('₽')) return '₽';
    if (priceString.contains('₦')) return '₦';
    if (priceString.contains('₨')) return '₨';
    return '\$'; // Default to dollar
  }
  
  static double calculateDiscountPrice(double originalPrice, double discountPercentage) {
    return originalPrice * (1 - discountPercentage / 100);
  }
  
  static double calculateTotal(List<double> prices) {
    return prices.fold(0.0, (sum, price) => sum + price);
  }
  
  static double calculateTax(double subtotal, double taxRate) {
    return subtotal * (taxRate / 100);
  }
  
  static double applyShipping(double total, double shippingFee, {double freeShippingThreshold = 100.0}) {
    return total >= freeShippingThreshold ? total : total + shippingFee;
  }
}

// Cart item model
class CartItem {
  final String id;
  final String name;
  final double price;
  final double discountPrice;
  int quantity;
  final String? image;
  
  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.discountPrice = 0.0,
    this.quantity = 1,
    this.image,
  });
  
  double get effectivePrice => discountPrice > 0 ? discountPrice : price;
  double get totalPrice => effectivePrice * quantity;
}

// Cart manager
class CartManager extends ChangeNotifier {
  final List<CartItem> _items = [];
  double _gstPercentage = 18.0; // Default GST percentage
  double _discountPercentage = 0.0; // Default discount percentage
  
  List<CartItem> get items => List.unmodifiable(_items);
  
  // Update GST percentage
  void updateGSTPercentage(double percentage) {
    _gstPercentage = percentage;
    notifyListeners();
  }
  
  // Update discount percentage
  void updateDiscountPercentage(double percentage) {
    _discountPercentage = percentage;
    notifyListeners();
  }
  
  // Get GST percentage
  double get gstPercentage => _gstPercentage;
  
  // Get discount percentage
  double get discountPercentage => _discountPercentage;
  
  // Update GST percentage
  void updateGSTPercentage(double percentage) {
    _gstPercentage = percentage;
    notifyListeners();
  }
  
  // Update discount percentage
  void updateDiscountPercentage(double percentage) {
    _discountPercentage = percentage;
    notifyListeners();
  }
  
  // Get GST percentage
  double get gstPercentage => _gstPercentage;
  
  // Get discount percentage
  double get discountPercentage => _discountPercentage;
  
  void addItem(CartItem item) {
    final existingIndex = _items.indexWhere((i) => i.id == item.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }
  
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
  
  void updateQuantity(String id, int quantity) {
    final item = _items.firstWhere((i) => i.id == id);
    item.quantity = quantity;
    notifyListeners();
  }
  
  void clearCart() {
    clear(); // Reuse existing clear method
  }
  
  void clear() {
    _items.clear();
    notifyListeners();
  }
  
  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }
  
  double get totalWithTax {
    final tax = PriceUtils.calculateTax(subtotal, 8.0); // 8% tax
    return subtotal + tax;
  }
  
  double get totalDiscount {
    return _items.fold(0.0, (sum, item) => 
      sum + ((item.price - item.effectivePrice) * item.quantity));
  }
  
  double get gstAmount {
    return PriceUtils.calculateTax(subtotal, _gstPercentage); // Dynamic GST percentage
  }
  
  double get finalTotal {
    return subtotal + gstAmount;
  }
  
  double get finalTotalWithShipping {
    return PriceUtils.applyShipping(totalWithTax, 5.99); // $5.99 shipping
  }
}

// Wishlist item model
class WishlistItem {
  final String id;
  final String name;
  final double price;
  final double discountPrice;
  final String? image;
  final String currencySymbol;
  
  WishlistItem({
    required this.id,
    required this.name,
    required this.price,
    this.discountPrice = 0.0,
    this.image,
    this.currencySymbol = '$',
  });
  
  double get effectivePrice => discountPrice > 0 ? discountPrice : price;
}

// Wishlist manager
class WishlistManager extends ChangeNotifier {
  void clearWishlist() {
    clear(); // Reuse existing clear method
  }

  final List<WishlistItem> _items = [];
  
  List<WishlistItem> get items => List.unmodifiable(_items);
  
  void addItem(WishlistItem item) {
    if (!_items.any((i) => i.id == item.id)) {
      _items.add(item);
      notifyListeners();
    }
  }
  
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
  
  void clearCart() {
    clear(); // Reuse existing clear method
  }
  
  void clear() {
    _items.clear();
    notifyListeners();
  }
  
  bool isInWishlist(String id) {
    return _items.any((item) => item.id == id);
  }
}

// Dynamic Configuration from Form
final String gstNumber = '$gstNumber';
final String selectedCategory = '$selectedCategory';
final Map<String, dynamic> storeInfo = {
  'storeName': '${storeInfo['storeName'] ?? 'My Store'}',
  'address': '${storeInfo['address'] ?? '123 Main St'}',
  'email': '${storeInfo['email'] ?? 'support@example.com'}',
  'phone': '${storeInfo['phone'] ?? '(123) 456-7890'}',
};

// Dynamic Product Data - Will be loaded from backend
List<Map<String, dynamic>> productCards = [];
bool isLoading = true;
String? errorMessage;

// Quantity tracking for products
Map<String, int> _productQuantities = {};

// WebSocket Real-time Sync Service
class DynamicAppSync {
  static final DynamicAppSync _instance = DynamicAppSync._internal();
  factory DynamicAppSync() => _instance;
  DynamicAppSync._internal();

  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _updateController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  bool _isConnected = false;
  String? _adminId;

  Stream<Map<String, dynamic>> get updates => _updateController.stream;
  bool get isConnected => _isConnected;

  void connect({String? adminId, required String apiBase}) {
    if (_isConnected && _socket != null) return;

    _adminId = adminId;
    
    try {
      final options = {
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
        'timeout': 5000,
      };

      _socket = IO.io('$apiBase/real-time-updates', options);
      _setupSocketListeners();
      
    } catch (e) {
      print('DynamicAppSync: Error connecting: $e');
    }
  }

  void _setupSocketListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      print('DynamicAppSync: Connected');
      _isConnected = true;
      
      if (_adminId != null && _adminId!.isNotEmpty) {
        _socket!.emit('join-admin-room', {'adminId': _adminId});
      }
    });

    _socket!.onDisconnect((_) {
      print('DynamicAppSync: Disconnected');
      _isConnected = false;
    });

    _socket!.on('dynamic-update', (data) {
      print('DynamicAppSync: Received update: $data');
      if (!_updateController.isClosed) {
        _updateController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('home-page', (data) {
      _handleUpdate({'type': 'home-page', 'data': data});
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    if (!_updateController.isClosed) {
      _updateController.add(update);
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    if (!_updateController.isClosed) {
      _updateController.close();
    }
  }
}

// Function to load dynamic product data from backend
Future<void> loadDynamicProductData() async {
  try {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    // Get dynamic admin ID
    final adminId = await AdminManager.getCurrentAdminId();
    print('🔍 Loading dynamic data with admin ID: ${adminId}');
    
    final response = await http.get(
      Uri.parse('${Environment.apiBase}/api/get-form?adminId=${adminId}'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['pages'] != null) {
        final pages = data['pages'] as List;
        final newProducts = <Map<String, dynamic>>[];
        
        // Extract products from all widgets
        for (var page in pages) {
          if (page['widgets'] != null) {
            for (var widget in page['widgets']) {
              if (widget['properties'] != null && widget['properties']['productCards'] != null) {
                final products = List<Map<String, dynamic>>.from(widget['properties']['productCards']);
                newProducts.addAll(products);
              }
            }
          }
        }
        
        setState(() {
          productCards = newProducts;
          isLoading = false;
        });
        
        print('✅ Loaded ${productCards.length} dynamic products');
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error loading dynamic data: $e');
    setState(() {
      errorMessage = e.toString();
      isLoading = false;
    });
  }
}

// Real-time updates with WebSocket
final DynamicAppSync _appSync = DynamicAppSync();
StreamSubscription? _updateSubscription;

void startRealTimeUpdates() async {
  final adminId = await AdminManager.getCurrentAdminId();
  if (adminId != null) {
    _appSync.connect(adminId: adminId, apiBase: Environment.apiBase);
    
    _updateSubscription = _appSync.updates.listen((update) {
      if (!mounted) return;
      
      final type = update['type']?.toString().toLowerCase();
      print('📱 Received real-time update: $type');
      
      switch (type) {
        case 'home-page':
        case 'dynamic-update':
          loadDynamicProductData();
          break;
      }
    });
  }
}

@override
void initState() {
  super.initState();
  loadDynamicProductData();
  startRealTimeUpdates();
}

@override
void dispose() {
  _updateSubscription?.cancel();
  _appSync.dispose();
  super.dispose();
}


void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Generated E-commerce App',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: Colors.blue,
      appBarTheme: const AppBarTheme(
        elevation: 4,
        shadowColor: Colors.black38,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        filled: true,
        fillColor: Colors.grey,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
    home: const SplashScreen(),
    debugShowCheckedModeBanner: false,
  );
}

// API Configuration - Auto-updated with your server details
class ApiConfig {
  static String get baseUrl => Environment.apiBase;
  static const String adminObjectId = '69451fc63c5a69f1befad942'; // Will be replaced during publish
}

// Dynamic Admin ID Detection
class AdminManager {
  static String? _currentAdminId;
  
  static Future<String> getCurrentAdminId() async {
    if (_currentAdminId != null) return _currentAdminId!;
    
    try {
      // Try to get from SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      final storedAdminId = prefs.getString('admin_id');
      if (storedAdminId != null && storedAdminId.isNotEmpty) {
        _currentAdminId = storedAdminId;
        return storedAdminId;
      }
      
      // Fallback to the hardcoded admin ID from generation
      if (ApiConfig.adminObjectId != '69451fc63c5a69f1befad942') {
        _currentAdminId = ApiConfig.adminObjectId;
        return ApiConfig.adminObjectId;
      }
      
      // Try to auto-detect from user profile
      final autoDetectedId = await _autoDetectAdminId();
      if (autoDetectedId != null) {
        await setAdminId(autoDetectedId);
        return autoDetectedId;
      }
      
      // Use current user's admin ID (not hardcoded)
      // Try to get from the current user session
      throw Exception('No admin ID configured. Please set up your app configuration first.');
    } catch (e) {
      print('Error getting admin ID: 2.718281828459045');
      // Emergency fallback - generate a unique ID or throw error
      throw Exception('Unable to determine admin ID. Please configure your app properly.');
    }
  }
  
  // Auto-detect admin ID from backend
  static Future<String?> _autoDetectAdminId() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.11:5000/api/admin/app-info'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final appInfo = data['data'];
          final adminId = appInfo['adminId'];
          if (adminId != null && adminId.toString().isNotEmpty) {
            return adminId.toString();
          }
        }
      }
    } catch (e) {
      print('Auto-detection failed: $e');
    }
    return null;
  }
  
  // Method to set admin ID dynamically
  static Future<void> setAdminId(String adminId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_id', adminId);
      _currentAdminId = adminId;
      print('✅ Admin ID set: ${adminId}');
    } catch (e) {
      print('Error setting admin ID: ${e}');
    }
  }
}

// Splash Screen - First screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _appName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchAppNameAndNavigate();
  }

  Future<void> _fetchAppNameAndNavigate() async {
    try {
      // Get dynamic admin ID
      final adminId = await AdminManager.getCurrentAdminId();
      print('🔍 Splash screen using admin ID: ${adminId}');
      
      final response = await http.get(
        Uri.parse('${Environment.apiBase}/api/admin/splash?adminId=${adminId}'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _appName = data['appName'] ?? 'AppifyYours';
          });
          print('✅ Splash screen loaded app name: ${_appName}');
        }
      } else {
        print('⚠️ Splash screen API error: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _appName = 'AppifyYours';
          });
        }
      }
    } catch (e) {
      print('Error fetching app name: ${e}');
      // If admin ID not found, show default and let user configure
      if (mounted) {
        setState(() {
          _appName = 'AppifyYours';
        });
      }
    }
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade400, Colors.blue.shade800],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(
                Icons.shopping_bag,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                _appName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: Colors.white),
              const Spacer(),
              const Text(
                'Powered by AppifyYours',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Sign In Page
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${Environment.apiBase}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          throw Exception(data['error'] ?? 'Sign in failed');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Invalid credentials');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: \${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Icon(
                Icons.shopping_bag,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign In', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateAccountPage(),
                    ),
                  );
                },
                child: const Text('Create Your Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Create Account Page
class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+.[a-zA-Z]{2,4}$').hasMatch(email);
  }

  bool _validatePhone(String phone) {
    return RegExp(r'^[0-9]{10}$').hasMatch(phone);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  Future<void> _createAccount() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (!_validateEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    if (!_validatePhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    if (!_validatePassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      final result = await apiService.dynamicSignup(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phone: phone,
      );

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Please sign in.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final data = result['data'];
        String message = 'Failed to create account';
        if (data is Map<String, dynamic> && data['message'] != null) {
          message = data['message'].toString();
        }
        throw Exception(message);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: 2.718281828459045'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Join Us Today',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your account to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  hintText: '10 digit number',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email ID',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  final CartManager _cartManager = CartManager();
  final WishlistManager _wishlistManager = WishlistManager();
  int _cartNotificationCount = 0;
  int _wishlistNotificationCount = 0;
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _dynamicProductCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _dynamicProductCards = List.from(productCards); // Fallback to static data
    _filteredProducts = List.from(_dynamicProductCards);
    _loadDynamicData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Real-time updates removed - app updates dynamically via WebSocket

  // Load dynamic data from backend
  Future<void> _loadDynamicAppConfig() async {
    try {
      // Get dynamic admin ID
      final adminId = await AdminManager.getCurrentAdminId();
      print('🔍 Home page using admin ID: ${adminId}');
      
      final response = await http.get(
        Uri.parse('${Environment.apiBase}/api/app/dynamic/${adminId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['config'] != null) {
          final config = data['config'];
          final newProducts = List<Map<String, dynamic>>.from(config['productCards'] ?? []);
          
          setState(() {
            _dynamicProductCards = newProducts.isNotEmpty ? newProducts : productCards;
            _filterProducts(_searchQuery); // Re-apply current filter
            _isLoading = false;
          });
          print('✅ Loaded ${_dynamicProductCards.length} products from backend');
        }
      }
    } catch (e) {
      print('❌ Error loading dynamic data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onPageChanged(int index) => setState(() => _currentPageIndex = index);

  void _onItemTapped(int index) {
    setState(() {
      _currentPageIndex = index;

      // Clear ONLY notification badges when opening Cart/Wishlist.
      // Do NOT clear the actual cart/wishlist items.
      if (index == 1) {
        _cartNotificationCount = 0;
      } else if (index == 2) {
        _wishlistNotificationCount = 0;
      }
    });
    _pageController.jumpToPage(index);
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredProducts = List.from(_dynamicProductCards);
      } else {
        _filteredProducts = _dynamicProductCards.where((product) {
          final productName = (product['productName'] ?? '').toString().toLowerCase();
          final price = (product['price'] ?? '').toString().toLowerCase();
          final discountPrice = (product['discountPrice'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return productName.contains(searchLower) || price.contains(searchLower) || discountPrice.contains(searchLower);
        }).toList();
      }
    });
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'favorite':
        return Icons.favorite;
      case 'person':
        return Icons.person;
      default:
        return Icons.error;
    }
  }

  String _currencySymbolForProduct(Map<String, dynamic> product) {
    final String symbol = (product['currencySymbol'] ?? '').toString();
    if (symbol.isNotEmpty) return symbol;
    final String code = (product['currencyCode'] ?? '').toString();
    if (code.isNotEmpty) return PriceUtils.currencySymbolFromCode(code);
    return PriceUtils.detectCurrency((product['price'] ?? '').toString());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _currentPageIndex,
      children: [
        _buildHomePage(),
        _buildCartPage(),
        _buildWishlistPage(),
        _buildProfilePage(),
      ],
    ),
    bottomNavigationBar: _buildBottomNavigationBar(),
  );

  Widget _buildHomePage() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadDynamicStoreData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading store data...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 64),
                SizedBox(height: 16),
                Text('Error loading store data'),
                Text(snapshot.error.toString(), style: TextStyle(color: Colors.grey)),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        final storeData = snapshot.data ?? {};
        final storeName = storeData['storeName'] ?? 'My Store';
        final storeAddress = storeData['address'] ?? '123 Main St';
        final storeEmail = storeData['email'] ?? 'support@example.com';
        final storePhone = storeData['phone'] ?? '(123) 456-7890';
        final headerColor = storeData['headerColor'] != null 
            ? _colorFromHex(storeData['headerColor']) 
            : Color(0xff4fb322);
        final bannerText = storeData['bannerText'] ?? 'Welcome to our store!';
        final bannerButtonText = storeData['bannerButtonText'] ?? 'Shop Now';

        return Column(
          children: [
            // Dynamic Header
            Container(
              color: headerColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.store, size: 32, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                      if (_cartManager.items.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '0',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Stack(
                    children: [
                      const Icon(Icons.favorite, color: Colors.white, size: 20),
                      if (_wishlistManager.items.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${_wishlistManager.items.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Dynamic Banner
                      Container(
                        height: 160,
                        child: Stack(
                          children: [
                            Container(color: Color(0xFFBDBDBD)),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    bannerText,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 4.0,
                                          color: Colors.black,
                                          offset: Offset(1.0, 1.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text(bannerButtonText, style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dynamic Product Grid
                      _buildDynamicProductGrid(),
                      // Dynamic Store Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.store, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        storeName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(storeAddress, style: TextStyle(fontSize: 12))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.email, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(storeEmail, style: TextStyle(fontSize: 12))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(storePhone, style: TextStyle(fontSize: 12))),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    '© 2023 ${storeName}. All rights reserved.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Load dynamic store data from backend
  Future<Map<String, dynamic>> _loadDynamicStoreData() async {
    try {
      final adminId = await AdminManager.getCurrentAdminId();
      final response = await http.get(
        Uri.parse('${Environment.apiBase}/api/get-form?adminId=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Extract store info from the response
          final storeInfo = data['storeInfo'] ?? {};
          final designSettings = data['designSettings'] ?? {};
          
          return {
            'storeName': data['shopName'] ?? storeInfo['storeName'] ?? 'My Store',
            'address': storeInfo['address'] ?? '123 Main St',
            'email': storeInfo['email'] ?? 'support@example.com',
            'phone': storeInfo['phone'] ?? '(123) 456-7890',
            'headerColor': designSettings['headerColor'] ?? '#4fb322',
            'bannerText': designSettings['bannerText'] ?? 'Welcome to our store!',
            'bannerButtonText': designSettings['bannerButtonText'] ?? 'Shop Now',
          };
        }
      }
    } catch (e) {
      print('Error loading store data: 2.718281828459045');
    }
    
    // Return default values if API fails
    return {
      'storeName': 'My Store',
      'address': '123 Main St',
      'email': 'support@example.com',
      'phone': '(123) 456-7890',
      'headerColor': '#4fb322',
      'bannerText': 'Welcome to our store!',
      'bannerButtonText': 'Shop Now',
    };
  }

  // Build dynamic product grid
  Widget _buildDynamicProductGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadDynamicProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final products = snapshot.data ?? [];
        
        if (products.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No products available'),
                  const Text('Add products in admin panel to see them here'),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Color(0xFF4a0404),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.68, // Adjusted for better card proportions
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductCard(product, index);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Load dynamic products from backend
  Future<List<Map<String, dynamic>>> _loadDynamicProducts() async {
    try {
      final adminId = await AdminManager.getCurrentAdminId();
      final response = await http.get(
        Uri.parse('${Environment.apiBase}/api/get-form?adminId=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['widgets'] != null) {
          // Extract product data from widgets
          List<Map<String, dynamic>> products = [];
          
          for (var widget in data['widgets']) {
            if (widget['name'] == 'ProductGridWidget' || 
                widget['name'] == 'Catalog View Card' ||
                widget['name'] == 'Product Detail Card') {
              final productCards = widget['properties']?['productCards'] ?? [];
              products.addAll(List<Map<String, dynamic>>.from(productCards));
            }
          }
          
          return products;
        }
      }
    } catch (e) {
      print('Error loading products: 2.718281828459045');
    }
    
    return [];
  }

  // Quantity management methods
  int _getProductQuantity(String productId) {
    return _productQuantities[productId] ?? 1;
  }

  void _incrementQuantity(String productId) {
    final currentQuantity = _getProductQuantity(productId);
    if (currentQuantity < 10) {
      setState(() {
        _productQuantities[productId] = currentQuantity + 1;
      });
    }
  }

  void _decrementQuantity(String productId) {
    final currentQuantity = _getProductQuantity(productId);
    if (currentQuantity > 1) {
      setState(() {
        _productQuantities[productId] = currentQuantity - 1;
      });
    }
  }

  int _getTotalCartQuantity() {
    return _productQuantities.values.fold(0, (sum, quantity) => sum + quantity);
  }

  bool _canAddToCart() {
    return _getTotalCartQuantity() < 10;
  }

  // Build individual product card
  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final String productId = 'product_' + index.toString();
    final String productName = product['productName'] ?? product['name'] ?? 'Product';
    
    // Try multiple possible price field names
    final String? priceField1 = product['price']?.toString();
    final String? priceField2 = product['basePrice']?.toString();
    final String? priceField3 = product['currentPrice']?.toString();
    final String? priceField4 = product['productPrice']?.toString();
    
    final String rawPrice = priceField1 ?? priceField2 ?? priceField3 ?? priceField4 ?? '99.99';
    final double basePrice = PriceUtils.parsePrice(rawPrice);
    final String currencySymbol = _currencySymbolForProduct(product);
    final double badgeDiscountPercent = double.tryParse((product['discountPercent'] ?? '0').toString()) ?? 0.0;
    final double manualDiscountPrice = PriceUtils.parsePrice(product['discountPrice']?.toString() ?? '0.00');
    final bool hasPercentDiscount = badgeDiscountPercent > 0;
    final double discountedPriceFromPercent = hasPercentDiscount ? basePrice * (1 - badgeDiscountPercent / 100) : 0.0;
    final double effectivePrice = hasPercentDiscount
        ? discountedPriceFromPercent
        : (manualDiscountPrice > 0 ? manualDiscountPrice : basePrice);
    final bool hasDiscount = hasPercentDiscount || (manualDiscountPrice > 0 && manualDiscountPrice < basePrice);
    final String? image = product['imageAsset'] ?? product['image'];
    final String rating = product['rating']?.toString() ?? '4.0';
    final int quantityAvailable = int.tryParse((product['quantity'] ?? '10').toString()) ?? 10;
    final bool isSoldOut = quantityAvailable <= 0;
    final String discountLabel;
    if (hasPercentDiscount) {
      discountLabel = '0% OFF';
    } else {
      discountLabel = 'OFFER';
    }
    
    final String stockLabel;
    if (isSoldOut) {
      stockLabel = 'SOLD OUT';
    } else {
      stockLabel = 'In stock: 0';
    }
    final bool isInWishlist = _wishlistManager.isInWishlist(productId);

    return Container(
      constraints: const BoxConstraints(
        minHeight: 320,
      ),
      child: Card(
        elevation: 4,
        color: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + badges section
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      color: Colors.grey[100],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: image != null && image.isNotEmpty
                          ? (image.startsWith('data:image/')
                              ? Image.memory(
                                  base64Decode(image.split(',')[1]),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image, size: 40, color: Colors.grey),
                                  ),
                                )
                              : Image.network(
                                  image,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image, size: 40, color: Colors.grey),
                                  ),
                                ))
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, size: 40, color: Colors.grey),
                            ),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          discountLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (isSoldOut)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SOLD OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content section
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product name
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Price + stock
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              currencySymbol + effectivePrice.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (hasDiscount)
                              Text(
                                currencySymbol + basePrice.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Only show stock label for items that are in stock and only for admin users
                        if (!isSoldOut)
                          FutureBuilder<bool>(
                            future: AuthHelper.isAdmin(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data == true) {
                                return Text(
                                  stockLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }
                              return SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Rating + wishlist
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const Icon(Icons.star_border, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          rating,
                          style: const TextStyle(fontSize: 10),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            if (isInWishlist) {
                              _wishlistManager.removeItem(productId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Removed from wishlist')),
                              );
                            } else {
                              final wishlistItem = WishlistItem(
                                id: productId,
                                name: productName,
                                price: basePrice,
                                discountPrice: hasDiscount ? effectivePrice : 0.0,
                                image: image,
                                currencySymbol: currencySymbol,
                              );
                              _wishlistManager.addItem(wishlistItem);
                              setState(() {
                                _wishlistNotificationCount += 1;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Added to wishlist')),
                              );
                            }
                            setState(() {});
                          },
                          child: Icon(
                            isInWishlist ? Icons.favorite : Icons.favorite_border,
                            color: isInWishlist ? Colors.red : Colors.grey,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Quantity controls and Add to Cart button
                    Container(
                      width: double.infinity,
                      height: 32,
                      child: Row(
                        children: [
                          // Quantity controls
                          Container(
                            width: 60,
                            height: 32,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Decrease button
                                GestureDetector(
                                  onTap: () => _decrementQuantity(productId),
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                // Quantity display
                                Text(
                                  _getProductQuantity(productId).toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Increase button
                                GestureDetector(
                                  onTap: () => _incrementQuantity(productId),
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Add to Cart button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSoldOut || !_canAddToCart()
                                  ? null
                                  : () {
                                      final quantity = _getProductQuantity(productId);
                                      for (int i = 0; i < quantity; i++) {
                                        final cartItem = CartItem(
                                          id: productId + '_' + i.toString(),
                                          name: productName,
                                          price: basePrice,
                                          discountPrice: hasDiscount ? effectivePrice : 0.0,
                                          image: image,
                                          currencySymbol: currencySymbol,
                                        );
                                        _cartManager.addItem(cartItem);
                                      }

                                      setState(() {
                                        _cartNotificationCount += quantity;
                                      });
                                      
                                      if (!_canAddToCart()) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Only have 10 products allowed'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Added ' + quantity.toString() + ' item(s) to cart'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                      
                                      // Reset quantity to 1 after adding to cart
                                      setState(() {
                                        _productQuantities[productId] = 1;
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSoldOut || !_canAddToCart()
                                    ? Colors.grey
                                    : Colors.blue,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                isSoldOut
                                    ? 'Sold Out'
                                    : !_canAddToCart()
                                        ? 'Limit Reached'
                                        : 'Add to Cart',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to convert hex color to Color
  Color _colorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.blue;
    
    String formattedColor = hexColor;
    if (!hexColor.startsWith('#')) {
      formattedColor = '#$hexColor';
    }
    
    if (formattedColor.length == 7) {
      formattedColor = formattedColor.replaceFirst('#', '#FF');
    }
    
    try {
      return Color(int.parse(formattedColor));
    } catch (e) {
      print('Invalid color: $hexColor');
      return Colors.blue;
    }
  }

  Widget _buildCartPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        automaticallyImplyLeading: false,
      ),
      body: ListenableBuilder(
        listenable: _cartManager,
        builder: (context, child) {
          return _cartManager.items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _cartManager.items.length,
                    itemBuilder: (context, index) {
                      final item = _cartManager.items[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[300],
                                child: item.image != null && item.image!.isNotEmpty
                                    ? (item.image!.startsWith('data:image/')
                                    ? Image.memory(
                                  base64Decode(item.image!.split(',')[1]),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                                )
                                    : Image.network(
                                  item.image!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                                ))
                                    : const Icon(Icons.image),
                              ),
                              const SizedBox(width: 12),
                              Expanded( 
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    // Show current price (effective price)
                                    Text(
                                      PriceUtils.formatPrice(item.effectivePrice),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    // Show original price if there's a discount
                                    if (item.discountPrice > 0 && item.price != item.discountPrice)
                                      Text(
                                        PriceUtils.formatPrice(item.price),
                                        style: TextStyle(
                                          fontSize: 14,
                                          decoration: TextDecoration.lineThrough,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Quantity controls for all users
                              Row(
                                children: [
                                  // Decrease button
                                  GestureDetector(
                                    onTap: () {
                                      if (item.quantity > 1) {
                                        _cartManager.updateQuantity(item.id, item.quantity - 1);
                                      } else {
                                        // Remove item if quantity is 1 and user clicks -
                                        _cartManager.removeItem(item.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Item removed from cart')),
                                        );
                                      }
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Quantity display
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.quantity.toString(),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Increase button
                                  GestureDetector(
                                    onTap: () {
                                      // Check if adding this item would exceed the 10 product limit
                                      if (_cartManager.totalQuantity < 10) {
                                        _cartManager.updateQuantity(item.id, item.quantity + 1);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Only have 10 products allowed'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Bill Summary Section
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            Text(PriceUtils.formatPrice(_cartManager.subtotal, currency: _cartManager.displayCurrencySymbol), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (_cartManager.totalDiscount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount', style: TextStyle(fontSize: 14, color: Colors.grey)),
                              Text('-' + PriceUtils.formatPrice(_cartManager.totalDiscount, currency: _cartManager.displayCurrencySymbol), style: const TextStyle(fontSize: 14, color: Colors.green)),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GST (18%)', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            Text(PriceUtils.formatPrice(_cartManager.gstAmount, currency: _cartManager.displayCurrencySymbol), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Divider(thickness: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                            Text(PriceUtils.formatPrice(_cartManager.finalTotal, currency: _cartManager.displayCurrencySymbol), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
        },
      ),
    );
  }

  Widget _buildWishlistPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        automaticallyImplyLeading: false,
      ),
      body: _wishlistManager.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your wishlist is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _wishlistManager.items.length,
              itemBuilder: (context, index) {
                final item = _wishlistManager.items[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: item.image != null && item.image!.isNotEmpty
                          ? (item.image!.startsWith('data:image/')
                          ? Image.memory(
                        base64Decode(item.image!.split(',')[1]),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                      )
                          : Image.network(
                        item.image!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                      ))
                          : const Icon(Icons.image),
                    ),
                    title: Text(item.name),
                    subtitle: Text(PriceUtils.formatPrice(item.effectivePrice, currency: item.currencySymbol)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            final cartItem = CartItem(
                              id: item.id,
                              name: item.name,
                              price: item.price,
                              discountPrice: item.discountPrice,
                              image: item.image,
                              currencySymbol: item.currencySymbol,
                            );
                            _cartManager.addItem(cartItem);
                            setState(() {
                              _cartNotificationCount += 1;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart')),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart),
                        ),
                        IconButton(
                          onPressed: () {
                            _wishlistManager.removeItem(item.id);
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProfilePage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'John Doe',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(250, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // Refund button action
                    },
                    child: const Text(
                      'Refund',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(250, 50),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // Log out and navigate to sign in page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignInPage(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Log Out',
                      style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentPageIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            label: Text('${_cartManager.items.length}'),
            isLabelVisible: _cartManager.items.length > 0,
            child: const Icon(Icons.shopping_cart),
          ),
          label: 'Cart',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            label: Text('${_wishlistManager.items.length}'),
            isLabelVisible: _wishlistManager.items.length > 0,
            child: const Icon(Icons.favorite),
          ),
          label: 'Wishlist',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

}
