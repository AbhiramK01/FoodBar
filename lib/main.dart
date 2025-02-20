import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_signup_page.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  if(kIsWeb) {
    await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: "AIzaSyC6gFOv-ywT8pwdF3wmDieoVOKNYf6WjNc",
        authDomain: "uiflutter-75803.firebaseapp.com",
        projectId: "uiflutter-75803",
        storageBucket: "uiflutter-75803.firebasestorage.app",
        messagingSenderId: "21123554400",
        appId: "1:21123554400:web:444227c3831672e6923705",
        measurementId: "G-20TDXWVM6J"));
  }
  else{
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OpenFoodFacts Scanner',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.teal.shade900),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.teal,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginSignupPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _scanResult = 'Scan a barcode to see product details';
  List<Map<String, String>> _searchHistory = [];
  String? _productImageUrl;
  String _ingredients = 'No ingredients available';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('searchHistory');
    if (historyJson != null) {
      final List<dynamic> historyList = json.decode(historyJson);
      setState(() {
        _searchHistory = List<Map<String, String>>.from(historyList.map((item) => Map<String, String>.from(item)));
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = json.encode(_searchHistory);
    prefs.setString('searchHistory', historyJson);
  }

  Future<void> _scanBarcode() async {
    try {
      var scanResult = await BarcodeScanner.scan();
      if (scanResult.rawContent.isNotEmpty) {
        await _fetchProductDetails(scanResult.rawContent);
      }
    } catch (e) {
      setState(() {
        _scanResult = 'Error scanning barcode: $e';
      });
    }
  }

  Future<void> _fetchProductDetails(String barcode) async {
    final apiUrl = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('product')) {
          final product = data['product'];
          final productName = product['product_name'] ?? 'Unknown Product';
          final formattedDetails = _formatProductDetails(product);

          setState(() {
            _productImageUrl = product['image_url'];
            _ingredients = product['ingredients_text'] ?? 'No ingredients available';
            _searchHistory.add({'barcode': barcode, 'name': productName});
            if (_searchHistory.length > 10) {
              _searchHistory.removeAt(0);
            }
            _saveHistory();  // Save the history after adding the new item
            _scanResult = formattedDetails;
          });
        } else {
          setState(() {
            _scanResult = 'Product not available in the OpenFoodFacts database.';
            _productImageUrl = null;
            _ingredients = 'No ingredients available';
          });
        }
      } else {
        setState(() {
          _scanResult =
          'Failed to fetch product details. Status code: ${response.statusCode}';
          _productImageUrl = null;
          _ingredients = 'No ingredients available';
        });
      }
    } catch (e) {
      setState(() {
        _scanResult = 'Error fetching product details: $e';
        _productImageUrl = null;
        _ingredients = 'No ingredients available';
      });
    }
  }

  String _formatProductDetails(Map<String, dynamic> product) {
    final productName = product['product_name'] ?? 'Unknown Product';
    final barcode = product['code'] ?? 'Unknown Barcode';
    final nutritionData = product['nutriments'] ?? {};

    final energy = nutritionData['energy-kcal_100g'] ?? 'N/A';
    final protein = nutritionData['proteins_100g'] ?? 'N/A';
    final fat = nutritionData['fat_100g'] ?? 'N/A';
    final carbohydrates = nutritionData['carbohydrates_100g'] ?? 'N/A';

    return '''
Product Name: $productName
Barcode: $barcode

Nutritional Values (per 100g):
- Energy: $energy kcal
- Protein: $protein g
- Fat: $fat g
- Carbohydrates: $carbohydrates g
    ''';
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
      _saveHistory(); // Save after clearing history
    });
  }

  void _showSearchHistory() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          children: [
            ListTile(
              title: const Text('Search History',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _clearHistory,
                tooltip: 'Clear History',
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _searchHistory.length,
                itemBuilder: (context, index) {
                  final entry = _searchHistory[index];
                  return ListTile(
                    title: Text(entry['name']!),
                    subtitle: Text('Barcode: ${entry['barcode']}'),
                    onTap: () {
                      Navigator.pop(context);
                      _fetchProductDetails(entry['barcode']!);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Function to handle logout
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginSignupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FoodBar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_productImageUrl != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _productImageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _scanResult,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Ingredients:',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          _ingredients,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _scanBarcode,
                  child: const Text('Scan Barcode'),
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: _showSearchHistory,
                  tooltip: 'Show Search History',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
