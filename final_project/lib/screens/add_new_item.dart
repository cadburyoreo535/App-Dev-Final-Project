import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddNewItemScreen extends StatefulWidget {
  const AddNewItemScreen({super.key});

  @override
  State<AddNewItemScreen> createState() => _AddNewItemScreenState();
}

class _AddNewItemScreenState extends State<AddNewItemScreen> {
  final _formKey = GlobalKey<FormState>();
  int _selectedIndex = 1; // opened from Inventory
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  DateTime? _expirationDate;
  String _category = 'Vegetables';
  bool _isSaving = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  Future<void> _saveIngredient() async {
    if (!_formKey.currentState!.validate()) return;

    if (_expirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiration date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Save ingredient to Firestore
      await _firestore.collection('ingredients').add({
        'name': _nameController.text.trim(),
        'category': _category,
        'quantity': double.parse(_quantityController.text.trim()),
        'price': double.parse(_priceController.text.trim()),
        'expirationDate': Timestamp.fromDate(_expirationDate!),
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingredient saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving ingredient: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving ingredient: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('lib/assets/logo.png', fit: BoxFit.contain),
        ),
        title: const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Add New Item',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color.fromARGB(255, 207, 207, 218),
          ),
        ),
      ),

      // BODY: make content expand and place Save button below content (above nav bar)
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content that expands to available space
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ingredient Details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA0D4CF).withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ingredient Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              enabled: !_isSaving,
                              decoration: InputDecoration(
                                hintText: 'e.g., Fresh Tomatoes',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter name'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _category,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Vegetables',
                                  child: Text('Vegetables'),
                                ),
                                DropdownMenuItem(
                                  value: 'Dairy',
                                  child: Text('Dairy'),
                                ),
                                DropdownMenuItem(
                                  value: 'Meat',
                                  child: Text('Meat'),
                                ),
                                DropdownMenuItem(
                                  value: 'Grains',
                                  child: Text('Grains'),
                                ),
                                DropdownMenuItem(
                                  value: 'Fruits',
                                  child: Text('Fruits'),
                                ),
                              ],
                              onChanged: _isSaving
                                  ? null
                                  : (v) => setState(() => _category = v!),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Inventory & Pricing
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA0D4CF).withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inventory & Pricing',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _quantityController,
                                  enabled: !_isSaving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., 5',
                                    suffixText: 'kg',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Enter quantity';
                                    }
                                    if (double.tryParse(v.trim()) == null) {
                                      return 'Enter valid number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _priceController,
                                  enabled: !_isSaving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.left,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., 100',
                                    suffixText: '₱',
                                    suffixStyle: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Enter price';
                                    }
                                    if (double.tryParse(v.trim()) == null) {
                                      return 'Enter valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Expiration Date
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA0D4CF).withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expiration Date',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _isSaving ? null : _pickDate,
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _expirationDate == null
                                      ? 'Select date'
                                      : '${_expirationDate!.year}-${_expirationDate!.month.toString().padLeft(2, '0')}-${_expirationDate!.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: _expirationDate == null
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveIngredient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF469E9C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Ingredient',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(
            height: 1,
            thickness: 1,
            color: Color.fromARGB(255, 207, 207, 218),
          ),
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
              if (index == 0) Navigator.pushNamed(context, '/');
              if (index == 1) Navigator.pushNamed(context, '/inventory');
              if (index == 2) Navigator.pushNamed(context, '/recipes');
              if (index == 3) Navigator.pushNamed(context, '/spoilage');
              if (index == 4) Navigator.pushNamed(context, '/procurement');
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF469E9C),
            unselectedItemColor: Colors.grey[600],
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Inventory',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_outlined),
                activeIcon: Icon(Icons.receipt),
                label: 'Recipes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.show_chart),
                activeIcon: Icon(Icons.show_chart),
                label: 'Spoilage',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_grocery_store_outlined),
                activeIcon: Icon(Icons.local_grocery_store),
                label: 'Procurement',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
