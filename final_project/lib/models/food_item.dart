class FoodItem {
  final String name;
  final double weight;
  final DateTime expiryDate;
  final bool isExpiringSoon;
  final bool isSpoiled;

  FoodItem({
    required this.name,
    required this.weight,
    required this.expiryDate,
    this.isExpiringSoon = false,
    this.isSpoiled = false,
  });

  int get daysUntilExpiry {
    return expiryDate.difference(DateTime.now()).inDays;
  }
}
