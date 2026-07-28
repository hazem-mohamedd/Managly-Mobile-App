import 'package:flutter/material.dart';
import 'package:managely/View/attendance_screen.dart';
import 'package:managely/View/home_screen.dart';
import 'package:managely/View/leave_screen.dart';
import 'package:managely/View/profile_screen.dart';
import 'package:managely/View/tasks_screen.dart';
import 'package:provider/provider.dart';
import 'package:managely/Auth/auth_provider.dart';

class HomeTap extends StatefulWidget {
  HomeTap({super.key, required this.initialIndex});
  final int initialIndex;

  @override
  State<HomeTap> createState() => _HomeTapState();
}

class _HomeTapState extends State<HomeTap> {
  late final PageController _pageController;
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isHr = authProvider.isHr;
    final isSupervisor = authProvider.isSupervisor;

    // 🔥 لو المستخدم مش HR ومش Supervisor، يبقى موظف عادي ويشوف 4 تابات
    final isEmployee = !isHr && !isSupervisor;

    final List<Widget> tabs = [
      const HomeScreen(),
      const AttendanceScreen(),
      if (isEmployee) const TasksScreen(),
      const LeaveScreen(),
      const ProfileScreen(),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Attendance'),
      if (isEmployee) const BottomNavigationBarItem(icon: Icon(Icons.task_outlined), label: 'Tasks'),
      const BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: 'Leave'),
      const BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: 'Profile'),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        iconSize: 25,
        onTap: _onTabTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }
}
