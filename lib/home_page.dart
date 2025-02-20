import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _scanResult = 'Scan a barcode to see product details';
  String? _productName;
  String? _productImageUrl;
  String? _nutritionalValues;
  List<Map<String, String>> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Load user-specific history from Firestore
  Future<void> _loadHistory() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('Users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _searchHistory =
          List<Map<String, String>>.from(doc['history'] ?? []);
        });
      }
    }
  }

  Future<void> _saveHistory() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('Users').doc(user.uid).set({
          'history': _searchHistory,
        }, SetOptions(merge: true));
        print('History saved successfully');
      } catch (e) {
        print('Error saving history: $e');
      }
    } else {
      print('User is not authenticated');
    }
  }


  // Clear the search history for the user
  Future<void> _clearHistory() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('Users').doc(user.uid).update(
          {'history': []});
      setState(() {
        _searchHistory.clear();
      });
    }
  }

  // Logout the user and return to the login screen
  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }

  // Scan a barcode using the device camera
  Future<void> _scanBarcode() async {
    try {
      final scanResult = await BarcodeScanner.scan();
      setState(() {
        _scanResult = scanResult.rawContent;
      });
      if (_scanResult.isNotEmpty) {
        await _fetchProductDetails(_scanResult);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning barcode: $e')),
      );
    }
  }

  // Fetch product details from OpenFoodFacts API
  Future<void> _fetchProductDetails(String barcode) async {
    final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['product'] != null) {
          final product = data['product'];
          setState(() {
            _productName = product['product_name'] ?? 'Unknown Product';
            _productImageUrl = product['image_url'];
            _nutritionalValues = product['nutriments'] != null
                ? product['nutriments'].toString()
                : 'No nutritional values available';

            // Add to search history
            _searchHistory.add({
              'barcode': barcode,
              'product_name': _productName!,
            });

            // Save updated history
            _saveHistory();
          });
        } else {
          _handleProductNotFound();
        }
      } else {
        _handleProductNotFound();
      }
    } catch (e) {
      _handleProductNotFound();
    }
  }

  void _handleProductNotFound() {
    setState(() {
      _productName = 'Product not found in the database.';
      _productImageUrl = null;
      _nutritionalValues = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OpenFoodFacts Scanner'),
        automaticallyImplyLeading: false, // Remove default back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Scan a barcode to see product details',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Scan Barcode Button
                ElevatedButton(
                  onPressed: _scanBarcode,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Scan Barcode'),
                ),

                // History Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/history');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('History'),
                ),

                // Logout Button
                ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text('Logout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
