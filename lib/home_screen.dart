import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeScreen extends StatelessWidget {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _scanBarcode(BuildContext context) async {
    try {
      var result = await BarcodeScanner.scan();
      String barcode = result.rawContent;

      // Fetch product details
      var url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      var response = await http.get(url);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 1) {
          String productName = data['product']['product_name'] ?? 'Unknown Product';
          String imageUrl = data['product']['image_url'] ?? '';
          var nutrients = data['product']['nutriments'] ?? {};
          String energy = nutrients['energy-kcal_100g'] != null
              ? '${nutrients['energy-kcal_100g']} kcal'
              : 'N/A';
          String proteins = nutrients['proteins_100g'] != null
              ? '${nutrients['proteins_100g']} g'
              : 'N/A';
          String fats = nutrients['fat_100g'] != null
              ? '${nutrients['fat_100g']} g'
              : 'N/A';
          String carbs = nutrients['carbohydrates_100g'] != null
              ? '${nutrients['carbohydrates_100g']} g'
              : 'N/A';

          // Save history
          _saveHistory(barcode, productName);

          // Show product details neatly
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(productName),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(imageUrl, height: 150)
                      : Text('No Image Available'),
                  SizedBox(height: 10),
                  Text('**Barcode:** $barcode', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text('Nutritional Values (per 100g):'),
                  Text('Energy: $energy'),
                  Text('Proteins: $proteins'),
                  Text('Fats: $fats'),
                  Text('Carbohydrates: $carbs'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            ),
          );
        } else {
          _showErrorDialog(context, 'Product not available in the database.');
        }
      } else {
        _showErrorDialog(context, 'Failed to fetch product details.');
      }
    } catch (e) {
      print('Error scanning barcode: $e');
    }
  }


  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveHistory(String barcode, String productName) async {
    final user = _auth.currentUser; // Get the logged-in user
    if (user != null) {
      final userDocRef = _firestore.collection('Users').doc(user.uid);

      try {
        // Update Firestore with a new history entry
        await userDocRef.update({
          'history': FieldValue.arrayUnion([
            {
              'barcode': barcode,
              'productName': productName,
              'timestamp': FieldValue.serverTimestamp(),
            }
          ])
        });
        print('History saved successfully!');
      } catch (e) {
        if (e.toString().contains('NOT_FOUND')) {
          // Create the document if it doesn't exist
          await userDocRef.set({
            'history': [
              {
                'barcode': barcode,
                'productName': productName,
                'timestamp': FieldValue.serverTimestamp(),
              }
            ]
          });
          print('History document created and saved successfully!');
        } else {
          print('Error saving history: $e');
        }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OpenFoodFacts Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Scan a barcode to see product details', textAlign: TextAlign.center),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _scanBarcode(context),
                  child: Text('Scan Barcode'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/history'),
                  child: Text('History'),
                ),
                ElevatedButton(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
