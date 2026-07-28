import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:managely/Auth/auth_provider.dart';
import 'package:managely/View/login_screen.dart';
import 'package:managely/Widget/profile_item_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _error = '';

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phone = '';
  String _department = '';
  String _jobTitle = '';
  String _role = '';
  String _id = '';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.fetchProfileIfNeeded();

      final user = authProvider.userProfile;

      if (user != null) {
        final fullName = user['name'] ?? '';

        setState(() {
          _firstName = fullName.split(' ').isNotEmpty
              ? fullName.split(' ').first
              : '';
          _lastName = fullName.split(' ').length > 1
              ? fullName.split(' ').last
              : '';

          _email = user['email'] ?? '';
          _phone = user['phone'] ?? '';
          _department = user['department'] ?? '';
          _jobTitle = user['job_title'] ?? '';
          _role = user['role'] ?? '';
          _id = user['id']?.toString() ?? '';

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Profile data is unavailable';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('PROFILE ERROR: $e');
      setState(() {
        _error = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      final token = context.read<AuthProvider>().token;

      await http.post(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );
    } catch (_) {}

    if (!mounted) return;

    await context.read<AuthProvider>().logout();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, left: 20, bottom: 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff3b82f6), Color(0xff2563eb)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Manage your account",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: LoadingWidget(),
              )
            else if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 10),
                    Text(_error, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2563eb),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              /// PROFILE CARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xff3b82f6), Color(0xff2563eb)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 35,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_firstName $_lastName',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _jobTitle,
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 3),
                               Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xff2563eb,
                                      ).withOpacity(.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _role,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xff2563eb),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_id.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffeff6ff),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xff3b82f6).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'ID: #$_id',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xff3b82f6),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(),

                      if (_id.isNotEmpty) ...[
                        ProfileItem(
                          icon: Icons.badge_outlined,
                          title: "Employee ID",
                          value: "#$_id",
                          color: Colors.orange,
                        ),
                        const Divider(),
                      ],
                      ProfileItem(
                        icon: Icons.email,
                        title: "Email",
                        value: _email,
                        color: Colors.blue,
                      ),
                      const Divider(),
                      ProfileItem(
                        icon: Icons.phone,
                        title: "Phone",
                        value: _phone,
                        color: Colors.green,
                      ),
                      const Divider(),
                      ProfileItem(
                        icon: Icons.apartment,
                        title: "Department",
                        value: _department,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 25),

            /// LOGOUT BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    overlayColor: Colors.red,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 6,
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    "Log Out",
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
