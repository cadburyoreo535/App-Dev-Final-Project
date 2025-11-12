import 'package:flutter/material.dart';

class ProcurementItem {
  final String name;
  final double quantity;
  final String unit;
  final String status; // 'Pending', 'Urgent', 'Procured'

  ProcurementItem({
    required this.name,
    required this.quantity,
    required this.unit,
    this.status = 'Pending',
  });
}

class ProcurementScreen extends StatefulWidget {
  const ProcurementScreen({super.key});

  @override
  State<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen> {
  int _selectedIndex = 4;
  final TextEditingController _addController = TextEditingController();

  final List<ProcurementItem> _items = [
    ProcurementItem(
      name: 'Chicken Breast',
      quantity: 2.5,
      unit: 'kg',
      status: 'Pending',
    ),
    ProcurementItem(
      name: 'Fresh Tomatoes',
      quantity: 1,
      unit: 'kg',
      status: 'Urgent',
    ),
    ProcurementItem(
      name: 'Onions',
      quantity: 500,
      unit: 'g',
      status: 'Procured',
    ),
    ProcurementItem(
      name: 'Garlic',
      quantity: 200,
      unit: 'g',
      status: 'Pending',
    ),
    ProcurementItem(
      name: 'Cooking Oil',
      quantity: 1,
      unit: 'Liter',
      status: 'Pending',
    ),
  ];

  int get _procuredCount => _items.where((i) => i.status == 'Procured').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(12.0),
          child: Icon(Icons.food_bank, color: Color(0xFF2D2D3D)),
        ),
        title: const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Procurement List',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
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
            _buildProgressCard(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAddBar(),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Items to Procure',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _items
                    .map((item) => _buildProcurementCard(item))
                    .toList(),
              ),
            ),
            const SizedBox(height: 80), // space above bottom bar
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPressed,
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildProgressCard() {
    final double progress = _items.isEmpty
        ? 0.0
        : _procuredCount / _items.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Procurement Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D3D),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$_procuredCount of ${_items.length} Items Procured',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% Complete',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF2D2D3D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _addController,
              decoration: const InputDecoration(
                hintText: 'Add new ingredient to procure...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: _onAddPressed,
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcurementCard(ProcurementItem item) {
    Color bg;
    Color badgeColor;
    if (item.status == 'Procured') {
      bg = const Color(0xFFE8F5E9);
      badgeColor = Colors.green;
    } else if (item.status == 'Urgent') {
      bg = const Color(0xFFFFEAEA);
      badgeColor = Colors.redAccent;
    } else {
      bg = Colors.white;
      badgeColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (bg == Colors.white)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Checkbox(
            value: item.status == 'Procured',
            onChanged: (v) {
              setState(() {
                final idx = _items.indexOf(item);
                _items[idx] = ProcurementItem(
                  name: item.name,
                  quantity: item.quantity,
                  unit: item.unit,
                  status: v == true ? 'Procured' : 'Pending',
                );
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2D3D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.quantity} ${item.unit}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.status,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAddPressed() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.insert(
        0,
        ProcurementItem(
          name: text,
          quantity: 1,
          unit: 'unit',
          status: 'Pending',
        ),
      );
      _addController.clear();
    });
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
            selectedItemColor: const Color(0xFF6366F1),
            unselectedItemColor: Colors.grey[600],
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '',
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
