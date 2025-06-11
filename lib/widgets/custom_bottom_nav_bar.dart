import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.black54,
      showUnselectedLabels: true,
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '予約'),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: '注文'),
        BottomNavigationBarItem(icon: Icon(Icons.store), label: '在庫'),
        BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'メニュー管理'),
      ],
    );
  }
}
