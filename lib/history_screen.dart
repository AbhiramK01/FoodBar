import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<Map<String, dynamic>> _history = []; // Local storage for history

  // Function to save history locally
  void _saveHistory(String barcode, String productName) {
    final newEntry = {
      'barcode': barcode,
      'productName': productName,
      'timestamp': DateTime.now(),
    };

    setState(() {
      _history.add(newEntry);
    });

    debugPrint("History saved: $newEntry");
  }

  // Function to clear the history
  void _clearHistory() {
    setState(() {
      _history.clear();
    });

    debugPrint("History cleared.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearHistory, // Clear history when the button is pressed
          ),
        ],
      ),
      body: _history.isEmpty
          ? const Center(child: Text('No history available.'))
          : ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final entry = _history[index];
          return ListTile(
            title: Text(entry['productName']),
            subtitle: Text('Barcode: ${entry['barcode']}'),
            trailing: Text(
              entry['timestamp'] != null
                  ? entry['timestamp'].toString()
                  : '',
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Simulate scanning a product
          final barcode = "1234567890"; // Replace with actual barcode
          final productName = "Sample Product"; // Replace with actual product name

          _saveHistory(barcode, productName);
        },
        child: const Icon(Icons.add),
        tooltip: 'Add History Entry',
      ),
    );
  }
}
