import 'package:flutter/material.dart';

class FloatingNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const FloatingNavBar({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _item(context, 0, Icons.home_outlined, Icons.home),
              const SizedBox(width: 28),
              _item(context, 1, Icons.qr_code_2, Icons.qr_code_2),
              const SizedBox(width: 28),
              _item(context, 2, Icons.dashboard_outlined, Icons.dashboard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData icon, IconData filled) {
    final selected = i == index;
    return InkWell(
      onTap: () => onChanged(i),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Icon(
          selected ? filled : icon,
          key: ValueKey(selected),
          color: Colors.white,
          size: selected ? 30 : 28,
        ),
      ),
    );
  }
}
