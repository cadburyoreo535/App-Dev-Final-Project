import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SpoilageScreen extends StatefulWidget {
  const SpoilageScreen({super.key});

  @override
  State<SpoilageScreen> createState() => _SpoilageScreenState();
}

class _SpoilageScreenState extends State<SpoilageScreen> {
  int _selectedIndex = 3;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Spoilage History & Analytics',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
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

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ingredients = snapshot.data?.docs ?? [];
          final now = DateTime.now();

          // Filter spoiled ingredients and calculate statistics
          List<Map<String, dynamic>> spoiledItems = [];
          Map<String, int> categoryCount = {};
          Map<String, double> categoryCost = {};
          int totalSpoiled = 0;
          double totalCost = 0;

          for (var doc in ingredients) {
            final data = doc.data() as Map<String, dynamic>;
            final expirationDate = (data['expirationDate'] as Timestamp?)
                ?.toDate();

            if (expirationDate != null) {
              final daysUntilExpiry = expirationDate.difference(now).inDays;

              if (daysUntilExpiry < 0) {
                // Item is spoiled
                final category = data['category'] ?? 'Other';
                final totalPrice = (data['price'] ?? 0).toDouble();
                final quantity = (data['quantity'] ?? 0).toDouble();
                final itemCost = totalPrice;

                spoiledItems.add({
                  'id': doc.id,
                  'name': data['name'] ?? '',
                  'quantity': quantity,
                  'unit': data['unit'] ?? 'kg',
                  'price': totalPrice,
                  'category': category,
                  'expirationDate': expirationDate,
                  'daysOverdue': daysUntilExpiry.abs(),
                });

                // Update category statistics
                categoryCount[category] = (categoryCount[category] ?? 0) + 1;
                categoryCost[category] =
                    (categoryCost[category] ?? 0) + itemCost;

                totalSpoiled++;
                totalCost += itemCost;
              }
            }
          }

          // Sort spoiled items by most recently expired
          spoiledItems.sort(
            (a, b) => (b['expirationDate'] as DateTime).compareTo(
              a['expirationDate'] as DateTime,
            ),
          );

          // Calculate spoilage rate
          final spoilageRate = ingredients.isEmpty
              ? 0.0
              : (totalSpoiled / ingredients.length * 100);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRecentlySpoiledSection(spoiledItems),
                const SizedBox(height: 20),
                _buildSpoilageOverviewSection(
                  totalSpoiled,
                  totalCost,
                  spoilageRate,
                  spoiledItems,
                ),
                const SizedBox(height: 20),
                _buildHighCostContributorsSection(spoiledItems),
                const SizedBox(height: 20),
                _buildSpoilageByCategorySection(categoryCount, categoryCost),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildRecentlySpoiledSection(List<Map<String, dynamic>> spoiledItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recently Spoiled Ingredients',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (spoiledItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Colors.green[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No spoiled ingredients!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep up the good work!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...spoiledItems
              .take(5)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSpoiledItem(
                    item['name'],
                    '${item['quantity'].toStringAsFixed(1)} ${item['unit']}',
                    '${item['expirationDate'].year}-${item['expirationDate'].month.toString().padLeft(2, '0')}-${item['expirationDate'].day.toString().padLeft(2, '0')}',
                    item['daysOverdue'],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildSpoiledItem(
    String name,
    String quantity,
    String date,
    int daysOverdue,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  quantity,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Spoiled',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                '$daysOverdue days ago',
                style: TextStyle(fontSize: 11, color: Colors.red.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpoilageOverviewSection(
    int totalSpoiled,
    double totalCost,
    double spoilageRate,
    List<Map<String, dynamic>> spoiledItems,
  ) {
    // Get the most recent spoilage date
    String lastSpoilageText = 'N/A';
    if (spoiledItems.isNotEmpty) {
      final mostRecentExpiry = spoiledItems.first['expirationDate'] as DateTime;
      final now = DateTime.now();
      final daysAgo = now.difference(mostRecentExpiry).inDays;

      if (daysAgo == 0) {
        lastSpoilageText = 'Today';
      } else if (daysAgo == 1) {
        lastSpoilageText = '1 day ago';
      } else {
        lastSpoilageText = '$daysAgo days ago';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spoilage Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  '🛒',
                  'Total Items Spoiled',
                  '$totalSpoiled items',
                  Colors.blue.shade100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  '💰',
                  'Total Cost Impact',
                  '₱${totalCost.toStringAsFixed(2)}',
                  Colors.orange.shade100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  '%',
                  'Spoilage Rate',
                  '${spoilageRate.toStringAsFixed(1)}%',
                  Colors.purple.shade100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  '📅',
                  'Last Spoilage',
                  lastSpoilageText,
                  Colors.pink.shade100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    String icon,
    String label,
    String value,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighCostContributorsSection(
    List<Map<String, dynamic>> spoiledItems,
  ) {
    if (spoiledItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by price (highest cost first)
    final sortedByPrice = List<Map<String, dynamic>>.from(spoiledItems)
      ..sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));

    // Take top 5 highest cost items
    final topCostItems = sortedByPrice.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_down,
                color: Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'High Cost Contributors',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Items that lost the most money',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ...topCostItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final name = item['name'];
            final price = (item['price'] as double);
            final quantity = (item['quantity'] as double);
            final unit = item['unit'];
            final category = item['category'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: index == 0
                      ? Colors.red.shade300
                      : Colors.grey.shade200,
                  width: index == 0 ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? Colors.red.shade100
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: index == 0
                              ? Colors.red.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$category • ${quantity.toStringAsFixed(1)} $unit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'lost',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSpoilageByCategorySection(
    Map<String, int> categoryCount,
    Map<String, double> categoryCost,
  ) {
    if (categoryCount.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No spoilage data to display',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Define colors for each category (updated with new categories)
    final Map<String, Color> categoryColors = {
      'Vegetables': Colors.green.shade400,
      'Dairy': Colors.blue.shade300,
      'Meat': Colors.red.shade400,
      'Grains': Colors.amber.shade400,
      'Fruits': Colors.orange.shade400,
      'Seafood': Colors.cyan.shade400,
      'Poultry': Colors.brown.shade300,
      'Pantry Items': Colors.grey.shade400,
      'Spices & Seasonings': Colors.deepOrange.shade300,
      'Beverages': Colors.purple.shade300,
      'Other': Colors.grey.shade400,
    };

    // Calculate total for percentages
    final totalCount = categoryCount.values.reduce((a, b) => a + b);

    // Build pie chart sections
    List<PieChartSectionData> sections = [];
    categoryCount.forEach((category, count) {
      final percentage = (count / totalCount * 100);
      sections.add(
        PieChartSectionData(
          color: categoryColors[category] ?? Colors.grey,
          value: count.toDouble(),
          title: '${percentage.toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          radius: 60,
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spoilage by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...categoryCount.entries.map((entry) {
            final category = entry.key;
            final count = entry.value;
            final cost = categoryCost[category] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: categoryColors[category] ?? Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$count items • ₱${cost.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }),
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
