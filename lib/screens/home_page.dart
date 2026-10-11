import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'doctor_directory_screen.dart';
import 'feature_screen.dart';
import 'login_screen.dart';
import 'my_appointments_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _dashboardItems = [
    {
      'title': 'Doctors',
      'subtitle': 'Add & view details',
      'icon': CupertinoIcons.person_2_fill,
      'empty': 'No doctors added yet.',
    },
    {
      'title': 'Prescriptions',
      'subtitle': 'Upload & manage',
      'icon': CupertinoIcons.doc_text_fill,
      'empty': 'No prescriptions added yet.',
    },
    {
      'title': 'Test Results',
      'subtitle': 'Add & view history',
      'icon': CupertinoIcons.search,
      'empty': 'No test results added yet.',
    },
    {
      'title': 'Appointments',
      'subtitle': 'Schedule & track visits',
      'icon': CupertinoIcons.calendar,
      'empty': 'No appointments scheduled yet.',
    },
  ];

  void _openFeature(Map<String, dynamic> item) {
    final title = item['title'] as String;
    final Widget screen = switch (title) {
      'Doctors' => const DoctorDirectoryScreen(),
      'Appointments' => const MyAppointmentsScreen(),
      _ => FeatureScreen(
          title: title,
          icon: item['icon'] as IconData,
          emptyMessage: item['empty'] as String,
        ),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 1:
        return _buildRecordsTab();
      case 2:
        return const MyAppointmentsScreen();
      default:
        return _buildProfileTab();
    }
  }

  Widget _buildProfileTab() {
    final user = authService.currentUser;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFDCE6FF),
              child: Icon(Icons.person, size: 40, color: Color(0xFF102A66)),
            ),
            const SizedBox(height: 16),
            Text(
              user?.name ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(user?.id ?? '', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    authService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _buildRecordsTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Records',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(height: 16),
          _recordTile('Prescriptions', CupertinoIcons.doc_text_fill,
              'No prescriptions added yet.'),
          _recordTile(
              'Test Results', CupertinoIcons.search, 'No test results added yet.'),
        ],
      ),
    );
  }

  Widget _recordTile(String title, IconData icon, String emptyMessage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        tileColor: const Color(0xFFF4F7FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: const Color(0xFF102A66)),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D1B2A),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeatureScreen(
              title: title,
              icon: icon,
              emptyMessage: emptyMessage,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _currentIndex == 0
          ? SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF0D1B2A), size: 28),
                    onPressed: () {},
                  ),
                  const Text(
                    'Healthbook',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1B2A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0D1B2A), width: 1.5),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Color(0xFF0D1B2A), size: 22),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hero Illustration Banner Placeholder
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CustomPaint(
                          painter: _HeroBackgroundPainter(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Your Health Hub',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1B2A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Manage records & appointments securely.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCE6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.heart_fill,
                              color: Color(0xFF102A66),
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Dashboard Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _dashboardItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final item = _dashboardItems[index];
                  return GestureDetector(
                    onTap: () => _openFeature(item),
                    child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: const Color(0xFF102A66),
                          size: 28,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D1B2A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      )
          : _buildTab(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF102A66),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.profile_circled),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HeroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x11416EB5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double spacing = 15;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i < size.width ? i : size.width, i < size.width ? 0 : i - size.width),
        Offset(i < size.height ? 0 : i - size.height, i < size.height ? i : size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
