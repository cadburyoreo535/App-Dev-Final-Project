import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
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
        title: const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        centerTitle: false,
        actions: const [],
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

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ingredients = snapshot.data?.docs ?? [];
          final now = DateTime.now();

          // Calculate counts
          int expiringSoonCount = 0;
          int spoiledCount = 0;
          List<Map<String, dynamic>> criticalItems = [];

          for (var doc in ingredients) {
            final data = doc.data() as Map<String, dynamic>;
            final expirationDate = (data['expirationDate'] as Timestamp?)
                ?.toDate();

            if (expirationDate != null) {
              final daysUntilExpiry = expirationDate.difference(now).inDays;

              if (daysUntilExpiry < 0) {
                spoiledCount++;
                criticalItems.add({
                  'id': doc.id,
                  'name': data['name'] ?? '',
                  'quantity': (data['quantity'] ?? 0).toDouble(),
                  'expirationDate': expirationDate,
                  'status': 'spoiled',
                  'daysUntilExpiry': daysUntilExpiry,
                });
              } else if (daysUntilExpiry <= 3) {
                expiringSoonCount++;
                criticalItems.add({
                  'id': doc.id,
                  'name': data['name'] ?? '',
                  'quantity': (data['quantity'] ?? 0).toDouble(),
                  'expirationDate': expirationDate,
                  'status': 'expiring_soon',
                  'daysUntilExpiry': daysUntilExpiry,
                });
              }
            }
          }

          // Sort critical items by expiry date (most urgent first)
          criticalItems.sort(
            (a, b) => a['daysUntilExpiry'].compareTo(b['daysUntilExpiry']),
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(),
                _buildSpoilageStatusCard(
                  totalItems: ingredients.length,
                  expiringSoonCount: expiringSoonCount,
                  spoiledCount: spoiledCount,
                ),
                const SizedBox(height: 20),
                _buildCriticalAlertsSection(criticalItems),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildWelcomeHeader() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(_auth.currentUser?.uid).get(),
      builder: (context, snapshot) {
        String firstName = 'User';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          firstName = data?['firstName'] ?? 'User';
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $firstName',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D2D3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back!',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFA0D4CF).withOpacity(0.35),
                child: Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF469E9C),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpoilageStatusCard({
    required int totalItems,
    required int expiringSoonCount,
    required int spoiledCount,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFA0D4CF).withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Spoilage Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D2D3D),
                ),
              ),
              Icon(Icons.notifications_outlined, color: Colors.grey[700]),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$totalItems Items',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D3D),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Text(
                'Expiring Soon: $expiringSoonCount',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Text(
                'Spoiled: $spoiledCount',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (totalItems > 0)
                FractionallySizedBox(
                  widthFactor: expiringSoonCount / totalItems,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/spoilage');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF469E9C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'View All Alerts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalAlertsSection(List<Map<String, dynamic>> criticalItems) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Critical Alerts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D2D3D),
            ),
          ),
          const SizedBox(height: 12),
          if (criticalItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No critical alerts!',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...criticalItems.map((item) => _buildFoodItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildFoodItemCard(Map<String, dynamic> item) {
    final status = item['status'];
    final isSpoiled = status == 'spoiled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSpoiled ? const Color(0xFFFFE5E5) : const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSpoiled ? Icons.error_outline : Icons.access_time,
                color: isSpoiled ? Colors.red[700] : Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D3D),
                      ),
                    ),
                    Text(
                      '${item['quantity'].toStringAsFixed(1)} kg',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSpoiled ? Colors.red : const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSpoiled ? 'Spoiled' : 'Expiring Soon',
                  style: TextStyle(
                    color: isSpoiled ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Expires: ${item['expirationDate'].year}-${item['expirationDate'].month.toString().padLeft(2, '0')}-${item['expirationDate'].day.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/inventory');
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'View in Inventory',
              style: TextStyle(
                color: Color(0xFF2D2D3D),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
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
