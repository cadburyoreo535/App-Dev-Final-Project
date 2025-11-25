import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  int _selectedIndex = 2;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Set<String> _selected =
      {}; // Changed from Set<String> to Set<String> for IDs
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _availableIngredients = [];
  bool _isInitialized = false; // Add this flag

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
            'Recipe Maker',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('ingredients')
            .where('userId', isEqualTo: _auth.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !_isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            final ingredients = snapshot.data!.docs;
            final now = DateTime.now();

            // Update available ingredients WITHOUT calling setState
            final List<Map<String, dynamic>> newIngredients = [];

            for (var doc in ingredients) {
              final data = doc.data() as Map<String, dynamic>;
              final expirationDate = (data['expirationDate'] as Timestamp?)
                  ?.toDate();

              if (expirationDate != null) {
                final daysUntilExpiry = expirationDate.difference(now).inDays;

                if (daysUntilExpiry >= 0) {
                  newIngredients.add({
                    'id': doc.id,
                    'name': data['name'] ?? '',
                    'quantity': (data['quantity'] ?? 0).toDouble(),
                    'unit': data['unit'] ?? 'kg',
                    'category': data['category'] ?? 'Other',
                    'daysUntilExpiry': daysUntilExpiry,
                    'status': daysUntilExpiry <= 3 ? 'expiring_soon' : 'fresh',
                  });
                }
              }
            }

            // Only update if ingredients changed
            if (!_isInitialized || _ingredientsChanged(newIngredients)) {
              _availableIngredients = newIngredients;
              _isInitialized = true;
            }
          }

          return _buildContent();
        },
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Helper method to check if ingredients actually changed
  bool _ingredientsChanged(List<Map<String, dynamic>> newIngredients) {
    if (_availableIngredients.length != newIngredients.length) return true;

    for (int i = 0; i < newIngredients.length; i++) {
      if (_availableIngredients.length <= i ||
          _availableIngredients[i]['id'] != newIngredients[i]['id'] ||
          _availableIngredients[i]['quantity'] !=
              newIngredients[i]['quantity']) {
        return true;
      }
    }
    return false;
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildSelectIngredientsCard(_availableIngredients),
          const SizedBox(height: 12),
          _buildNoRecipesCard(),
          const SizedBox(height: 16),
          _buildSavedRecipesSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSelectIngredientsCard(
    List<Map<String, dynamic>> availableIngredients,
  ) {
    // Get unique categories
    final Set<String> categoriesSet = {'All'};
    for (var ing in availableIngredients) {
      categoriesSet.add(ing['category']);
    }
    final categories = categoriesSet.toList();

    // Filter by category
    List<Map<String, dynamic>> filteredIngredients = availableIngredients;
    if (_selectedCategory != 'All') {
      filteredIngredients = availableIngredients
          .where((ing) => ing['category'] == _selectedCategory)
          .toList();
    }

    // Filter by search query
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredIngredients = filteredIngredients
          .where(
            (ing) => ing['name'].toString().toLowerCase().contains(searchQuery),
          )
          .toList();
    }

    // Sort: expiring soon first, then by name
    filteredIngredients.sort((a, b) {
      if (a['status'] != b['status']) {
        return a['status'] == 'expiring_soon' ? -1 : 1;
      }
      return a['name'].toString().compareTo(b['name'].toString());
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFA0D4CF).withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Ingredients',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D2D3D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose what you have on hand from your inventory.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          // Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search ingredients...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Categories
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: categories
                .map(
                  (c) => ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    selected: _selectedCategory == c,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = c;
                      });
                    },
                    selectedColor: const Color(0xFF469E9C),
                    backgroundColor: const Color(0xFFF0EDFF),
                    labelStyle: TextStyle(
                      color: _selectedCategory == c
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: _selectedCategory == c
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          // Ingredient list
          if (filteredIngredients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      availableIngredients.isEmpty
                          ? 'No fresh ingredients available'
                          : 'No ingredients match your search',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: filteredIngredients.map((ing) {
                final id = ing['id']; // Use ID instead of name
                final name = ing['name'];
                final quantity = ing['quantity'];
                final unit = ing['unit'];
                final status = ing['status'];
                final daysUntilExpiry = ing['daysUntilExpiry'];
                final selected = _selected.contains(id); // Check by ID

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: status == 'expiring_soon'
                        ? Colors.orange.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: status == 'expiring_soon'
                          ? Colors.orange.shade200
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 28,
                      child: Checkbox(
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(id); // Add ID instead of name
                            } else {
                              _selected.remove(id); // Remove by ID
                            }
                          });
                        },
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D3D),
                      ),
                    ),
                    subtitle: status == 'expiring_soon'
                        ? Text(
                            'Expires in $daysUntilExpiry day${daysUntilExpiry != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${quantity.toStringAsFixed(1)} $unit',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        if (status == 'expiring_soon')
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.orange[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isEmpty ? null : _generateRecipes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF469E9C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                _selected.isEmpty
                    ? 'Select ingredients to continue'
                    : 'Generate Recipes (${_selected.length} selected)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecipesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.ramen_dining, size: 36, color: Colors.grey[700]),
          const SizedBox(height: 12),
          const Text(
            'No Recipes Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D3D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select ingredients and click \'Generate\' to see suggestions.',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRecipesSection() {
    final saved = [
      {'title': 'Hearty Beef Stew'},
      {'title': 'Lentil Soup'},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Saved Recipes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D2D3D),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: saved
                .map(
                  (r) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bookmark,
                            size: 28,
                            color: Colors.grey[800],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            r['title']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'View',
                              style: TextStyle(color: Color(0xFF469E9C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _generateRecipes() {
    // Get selected ingredient names for display
    final selectedIngredients = _availableIngredients
        .where((ing) => _selected.contains(ing['id']))
        .map((ing) => ing['name'] as String)
        .toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Generate Recipes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected ingredients:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(selectedIngredients.join(', ')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
