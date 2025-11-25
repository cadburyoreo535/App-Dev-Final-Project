import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

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

  final Set<String> _selected = {};
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _availableIngredients = [];
  bool _isInitialized = false;
  bool _isGenerating = false;
  List<Map<String, dynamic>> _generatedRecipes = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _generateRecipes() async {
    final selectedIngredients = _availableIngredients
        .where((ing) => _selected.contains(ing['id']))
        .toList();

    if (selectedIngredients.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not found in .env file');
      }

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final ingredientList = selectedIngredients
          .map(
            (ing) =>
                '- ${ing['name']} (${ing['quantity']} ${ing['unit']}) - ${ing['status'] == 'expiring_soon' ? 'EXPIRING SOON (${ing['daysUntilExpiry']} days left)' : 'Fresh'}',
          )
          .join('\n');

      final prompt =
          '''
You are a professional chef assistant. Generate 3 creative and practical recipes using the following ingredients from the user's inventory. Prioritize using ingredients that are expiring soon.

Available Ingredients:
$ingredientList

For each recipe, provide:
1. Recipe name
2. Brief description (1-2 sentences)
3. Difficulty level (Easy/Medium/Hard)
4. Cooking time (in minutes)
5. Ingredients used from the available list (with quantities)
6. Step-by-step instructions (numbered)
7. Nutritional highlight (brief)

Format the response as JSON array:
[
  {
    "name": "Recipe Name",
    "description": "Brief description",
    "difficulty": "Easy",
    "cookingTime": 30,
    "ingredients": [
      {"name": "ingredient name", "quantity": "amount", "unit": "unit"}
    ],
    "instructions": [
      "Step 1: ...",
      "Step 2: ..."
    ],
    "nutritionalHighlight": "High in protein and fiber"
  }
]

IMPORTANT: 
- Return ONLY valid JSON, no markdown formatting or extra text
- Use ingredients that are expiring soon first
- Make recipes practical and easy to follow
- Ensure quantities are realistic
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text == null) {
        throw Exception('No response from AI');
      }

      String jsonText = response.text!.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText
            .replaceFirst('```json', '')
            .replaceFirst('```', '')
            .trim();
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText
            .replaceFirst('```', '')
            .replaceFirst('```', '')
            .trim();
      }

      final List<dynamic> recipesJson = json.decode(jsonText);

      setState(() {
        _generatedRecipes = recipesJson.cast<Map<String, dynamic>>();
        _isGenerating = false;
      });

      _showRecipesDialog();
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating recipes: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showRecipesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF469E9C),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Generated Recipes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _generatedRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _generatedRecipes[index];
                    return _buildRecipeCard(recipe, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF469E9C),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          recipe['name'] ?? 'Untitled Recipe',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              recipe['description'] ?? '',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    recipe['difficulty'] ?? 'Medium',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.orange.shade100,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(
                    '${recipe['cookingTime'] ?? 0} min',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.blue.shade100,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ingredients:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          ...((recipe['ingredients'] as List?) ?? []).map(
            (ing) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Color(0xFF469E9C)),
                  const SizedBox(width: 8),
                  Text(
                    '${ing['quantity']} ${ing['unit']} ${ing['name']}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Instructions:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          ...((recipe['instructions'] as List?) ?? []).asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF469E9C),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value.toString().replaceFirst(
                        RegExp(r'^Step \d+:\s*'),
                        '',
                      ),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (recipe['nutritionalHighlight'] != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.eco, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recipe['nutritionalHighlight'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
      body: _isGenerating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF469E9C)),
                  const SizedBox(height: 16),
                  Text(
                    'Generating recipes with AI...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a few seconds',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
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

                  final List<Map<String, dynamic>> newIngredients = [];

                  for (var doc in ingredients) {
                    final data = doc.data() as Map<String, dynamic>;
                    final expirationDate =
                        (data['expirationDate'] as Timestamp?)?.toDate();

                    if (expirationDate != null) {
                      final daysUntilExpiry = expirationDate
                          .difference(now)
                          .inDays;

                      if (daysUntilExpiry >= 0) {
                        newIngredients.add({
                          'id': doc.id,
                          'name': data['name'] ?? '',
                          'quantity': (data['quantity'] ?? 0).toDouble(),
                          'unit': data['unit'] ?? 'kg',
                          'category': data['category'] ?? 'Other',
                          'daysUntilExpiry': daysUntilExpiry,
                          'status': daysUntilExpiry <= 3
                              ? 'expiring_soon'
                              : 'fresh',
                        });
                      }
                    }
                  }

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
