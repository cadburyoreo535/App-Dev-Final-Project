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
  String _selectedDifficulty = 'All'; // Add this
  List<Map<String, dynamic>> _availableIngredients = [];
  bool _isInitialized = false;
  bool _isGenerating = false;
  List<Map<String, dynamic>> _generatedRecipes = [];
  List<Map<String, dynamic>> _savedRecipes = []; // Add this

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedRecipes(); // Add this
  }

  // Load saved recipes from Firestore
  void _loadSavedRecipes() {
    _firestore
        .collection('savedRecipes')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _savedRecipes = snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          });
        });
  }

  // Save recipe to Firestore
  Future<void> _saveRecipe(Map<String, dynamic> recipe) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _firestore.collection('savedRecipes').add({
        ...recipe,
        'userId': user.uid,
        'savedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${recipe['name']} saved successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Delete saved recipe
  Future<void> _deleteSavedRecipe(String recipeId) async {
    try {
      await _firestore.collection('savedRecipes').doc(recipeId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

      // Update prompt based on difficulty filter
      final difficultyFilter = _selectedDifficulty == 'All'
          ? ''
          : '\n- Focus on $_selectedDifficulty difficulty recipes';

      final prompt =
          '''
You are a professional chef assistant. Generate 3 creative and practical recipes using the following ingredients from the user's inventory. Prioritize using ingredients that are expiring soon.$difficultyFilter

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
                    return _buildRecipeCard(recipe, index, isGenerated: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSavedRecipeDialog(Map<String, dynamic> recipe) {
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
                    const Icon(Icons.bookmark, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recipe['name'] ?? 'Recipe',
                        style: const TextStyle(
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildRecipeCard(recipe, 0, isGenerated: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeCard(
    Map<String, dynamic> recipe,
    int index, {
    required bool isGenerated,
  }) {
    // Check if recipe is already saved
    final isSaved = _savedRecipes.any(
      (saved) =>
          saved['name'] == recipe['name'] &&
          saved['description'] == recipe['description'],
    );

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
        title: Row(
          children: [
            Expanded(
              child: Text(
                recipe['name'] ?? 'Untitled Recipe',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isGenerated)
              IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? const Color(0xFF469E9C) : Colors.grey[600],
                ),
                onPressed: isSaved
                    ? null
                    : () {
                        _saveRecipe(recipe);
                        Navigator.pop(context); // Close dialog after saving
                      },
                tooltip: isSaved ? 'Already saved' : 'Save recipe',
              ),
          ],
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
                  backgroundColor: _getDifficultyColor(recipe['difficulty']),
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

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return Colors.green.shade100;
      case 'medium':
        return Colors.orange.shade100;
      case 'hard':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
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
          if (_savedRecipes.isEmpty) _buildNoRecipesCard(),
          const SizedBox(height: 16),
          if (_savedRecipes.isNotEmpty) _buildSavedRecipesSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSelectIngredientsCard(
    List<Map<String, dynamic>> availableIngredients,
  ) {
    final Set<String> categoriesSet = {'All'};
    for (var ing in availableIngredients) {
      categoriesSet.add(ing['category']);
    }
    final categories = categoriesSet.toList();

    List<Map<String, dynamic>> filteredIngredients = availableIngredients;
    if (_selectedCategory != 'All') {
      filteredIngredients = availableIngredients
          .where((ing) => ing['category'] == _selectedCategory)
          .toList();
    }

    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredIngredients = filteredIngredients
          .where(
            (ing) => ing['name'].toString().toLowerCase().contains(searchQuery),
          )
          .toList();
    }

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
          // Category filter
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
          const SizedBox(height: 10),
          // Difficulty filter
          const Text(
            'Recipe Difficulty:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2D3D),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: ['All', 'Easy', 'Medium', 'Hard']
                .map(
                  (d) => ChoiceChip(
                    label: Text(d, style: const TextStyle(fontSize: 12)),
                    selected: _selectedDifficulty == d,
                    onSelected: (selected) {
                      setState(() {
                        _selectedDifficulty = d;
                      });
                    },
                    selectedColor: const Color(0xFF469E9C),
                    backgroundColor: _getDifficultyColor(d),
                    labelStyle: TextStyle(
                      color: _selectedDifficulty == d
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: _selectedDifficulty == d
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
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
                final id = ing['id'];
                final name = ing['name'];
                final quantity = ing['quantity'];
                final unit = ing['unit'];
                final status = ing['status'];
                final daysUntilExpiry = ing['daysUntilExpiry'];
                final selected = _selected.contains(id);

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
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
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
            'No Saved Recipes Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D3D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select ingredients and generate recipes to get started!',
            style: TextStyle(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRecipesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saved Recipes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D2D3D),
                ),
              ),
              Text(
                '${_savedRecipes.length} recipe${_savedRecipes.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _savedRecipes.length,
            itemBuilder: (context, index) {
              final recipe = _savedRecipes[index];
              return InkWell(
                onTap: () => _showSavedRecipeDialog(recipe),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF469E9C).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              size: 24,
                              color: Color(0xFF469E9C),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text('Delete Recipe'),
                                  content: const Text(
                                    'Are you sure you want to delete this recipe?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                _deleteSavedRecipe(recipe['id']);
                              }
                            },
                            color: Colors.red[700],
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe['name'] ?? 'Untitled',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(
                                recipe['difficulty'] ?? 'Medium',
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: _getDifficultyColor(
                                recipe['difficulty'],
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showSavedRecipeDialog(recipe),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF469E9C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
              if (index == 4) Navigator.pushNamed(context, '/profile');
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
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
