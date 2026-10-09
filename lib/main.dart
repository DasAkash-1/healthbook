import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ), //
      home: IntroScreen(),
    ); //
  }
}

// intro screen
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

// state
class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentIdx = 0;

  final List<Widget> _pages = [
    IntroComponent(
      title: "Your Health Hub",
      description: "Manage your medical records and appointments all in one secure place.",
      imagePath: "assets/img_1.png",
    ),

    IntroComponent(
      title: "Book with Ease",
      description: "Find specialists, check availability, and schedule your next visit instantly.",
      imagePath: "assets/img_2.png",
    ),

    IntroComponent(
      title: "Track Your Records",
      description: "Access your test results, prescriptions, and full health history on the go.",
      imagePath: "assets/img_3.png",
    ),

    IntroComponent(
      title: "Ready to Start?",
      description: "Create your account and take control of your healthcare journey today.",
      imagePath: "assets/img_4.png",
    ),
  ];

  // skip er logic
  void _skip() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  // next
  void _next() {
    if (_currentIdx < _pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else {
      _onFinish();
    }
  }

  // finish - opens the registration screen
  void _onFinish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  // login link on the last intro page
  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          // wrap menu - option + return
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentIdx = idx;
                });
              },
              itemBuilder: (context, idx) => _pages[idx],
            ),

            // skip butn, last page e skip show korar dorkar nai
            _currentIdx == _pages.length - 1
                ? SizedBox.shrink()
                : Positioned(
                    bottom: 40,
                    left: 20,
                    child: TextButton(
                      onPressed: _skip,
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

            // next button
            Positioned(
              bottom: 40,
              right: 20,
              child: TextButton(
                onPressed: _next,
                child: Text(
                  _currentIdx == _pages.length - 1 ? "Finish" : "Next",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // dots - navigate
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: WormEffect(
                    dotHeight: 12,
                    dotWidth: 12,
                    dotColor: Colors.blueGrey,
                    activeDotColor: Colors.blueAccent,
                  ),
                ),
              ),
            ),

            // logo - only on first screen
            _currentIdx == 0
                ? Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    child: Center(child: Logo(height: 32)),
                  )
                : SizedBox.shrink(),

            // login link - only on last page
            _currentIdx == _pages.length - 1
                ? Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: TextButton(
                        onPressed: _openLogin,
                        child: const Text("Already have an account? Log in"),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

// screen components class ekhane
class IntroComponent extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;

  const IntroComponent({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,

      children: [
        // img first, space diye title, then desc
        Image.asset(imagePath, height: 300),
        SizedBox(height: 30),

        Text(
          title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 30), // eta space

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

class Logo extends StatelessWidget {
  final double height;

  const Logo({super.key, this.height = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/logo.png', height: height);
  }
}