import 'package:flutter/material.dart';
import 'profile_tab.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'chat_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeTab(),
    SearchTab(),
    ChatTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows content to go behind the bottom nav bar
      extendBodyBehindAppBar: true, // Allows content to go behind the app bar
      appBar: AppBar(
        title: Image.asset(
          'assets/logo.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          color: const Color(
            0xFF0F172A,
          ).withValues(alpha: 0.9), // Slightly more opaque, no expensive blur
        ),
      ),
      body: Stack(
        children: [
          // Subtle background gradient for main screen
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ], // Slate 900 to Slate 800
              ),
            ),
          ),
          IndexedStack(index: _currentIndex, children: _pages),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(
            0xFF0F172A,
          ).withValues(alpha: 0.9), // Translucent dark without blur
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor:
              Colors.transparent, // Let the container color show through
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.white54,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// Re-styled dummy page to fit the dark theme better
class _DummyPageWithState extends StatefulWidget {
  final String title;
  final IconData icon;

  const _DummyPageWithState({required this.title, required this.icon});

  @override
  State<_DummyPageWithState> createState() => _DummyPageWithStateState();
}

class _DummyPageWithStateState extends State<_DummyPageWithState> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Test state retention...',
                prefixIcon: Icon(Icons.edit, color: Colors.white54),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: 16,
                bottom: 100,
              ), // padding for the glass bottom nav
              itemCount: 50,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  title: Text(
                    'Item $index',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'In ${widget.title} Tab',
                    style: const TextStyle(color: Colors.white54),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
