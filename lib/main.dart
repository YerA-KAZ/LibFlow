import 'package:flutter/material.dart';
import 'models/book_model.dart';
import 'screens/auth_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/home_screen.dart';
import 'screens/my_books_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/dummy_books.dart';
import 'utils/constants.dart';

void main() {
  runApp(const LibFlowApp());
}

class LibFlowApp extends StatefulWidget {
  const LibFlowApp({super.key});

  @override
  State<LibFlowApp> createState() => _LibFlowAppState();
}

class _LibFlowAppState extends State<LibFlowApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surfaceLight,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primaryLight,
          secondary: AppColors.accent,
          surface: AppColors.surfaceDark,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.textPrimaryDark,
          elevation: 0,
        ),
      ),
      home: MainNavigationContainer(
        isDarkMode: _themeMode == ThemeMode.dark,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeToggle;

  const MainNavigationContainer({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<MainNavigationContainer> createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  bool _showSplash = true;
  bool _isAuthenticated = true; // Set to true by default for immediate prototype viewing
  int _currentIndex = 0;
  late List<Book> _books;

  @override
  void initState() {
    super.initState();
    _books = DummyDataService.getInitialBooks();
  }

  void _handleBookUpdate(Book updatedBook) {
    setState(() {
      final index = _books.indexWhere((b) => b.id == updatedBook.id);
      if (index != -1) {
        _books[index] = updatedBook;
      }
    });
  }

  void _handleBookAdd(Book newBook) {
    setState(() {
      _books.insert(0, newBook);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onFinish: () {
          setState(() {
            _showSplash = false;
          });
        },
      );
    }

    if (!_isAuthenticated) {
      return AuthScreen(
        onLoginSuccess: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    final screens = [
      HomeScreen(
        books: _books,
        onBookUpdated: _handleBookUpdate,
        onNavigateToCatalog: () => setState(() => _currentIndex = 1),
        onNavigateToMyBooks: () => setState(() => _currentIndex = 2),
      ),
      CatalogScreen(
        books: _books,
        onBookUpdated: _handleBookUpdate,
        onBookAdded: _handleBookAdd,
      ),
      MyBooksScreen(
        books: _books,
        onBookUpdated: _handleBookUpdate,
      ),
      ProfileScreen(
        isDarkMode: widget.isDarkMode,
        onThemeToggle: widget.onThemeToggle,
        onLogout: () {
          setState(() {
            _isAuthenticated = false;
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: widget.isDarkMode ? AppColors.surfaceDark : Colors.white,
        indicatorColor: AppColors.primary.withAlpha(widget.isDarkMode ? 60 : 30),
        elevation: 3,
        height: 68,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Басты',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.primary),
            label: 'Каталог',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: AppColors.primary),
            label: 'Таңдаулы',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
