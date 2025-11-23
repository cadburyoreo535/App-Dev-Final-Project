import 'package:flutter/material.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  int _selectedIndex = 2;
  final TextEditingController _searchController = TextEditingController();
  // final TextEditingController _addController = TextEditingController();

  final List<Map<String, String>> _ingredients = [
    {'name': 'Chicken Breast', 'qty': '500g'},
    {'name': 'Bell Peppers', 'qty': '2 pcs'},
    {'name': 'Onions', 'qty': '1 pc'},
    {'name': 'Garlic', 'qty': '3 cloves'},
    {'name': 'Soy Sauce', 'qty': '100ml'},
    {'name': 'Broccoli', 'qty': '1 head'},
  ];

  final Set<String> _selected = {};

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
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildSelectIngredientsCard(),
            const SizedBox(height: 12),
            _buildNoRecipesCard(),
            const SizedBox(height: 16),
            _buildSavedRecipesSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildSelectIngredientsCard() {
    final categories = [
      'Meats',
      'Vegetables',
      'Dairy',
      'Grains',
      'Spices',
      'Sauces',
    ];
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
                  (c) => Chip(
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFFF0EDFF),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          // Ingredient list
          Column(
            children: _ingredients.map((ing) {
              final name = ing['name']!;
              final qty = ing['qty']!;
              final selected = _selected.contains(name);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 28,
                  child: Checkbox(
                    value: selected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(name);
                        } else {
                          _selected.remove(name);
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
                trailing: Text(qty, style: TextStyle(color: Colors.grey[700])),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generateRecipes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF469E9C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Generate Recipes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    // placeholder: implement recipe generation
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generate'),
        content: Text('Selected: ${_selected.join(', ')}'),
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
          // subtle line under title / above the nav bar
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
