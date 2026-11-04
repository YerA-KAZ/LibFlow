import 'package:flutter/material.dart';

import 'models/book_model.dart';
import 'screens/auth_screen.dart';

import 'package:provider/provider.dart';

import 'services/auth_provider.dart';
import 'screens/catalog_screen.dart';
import 'screens/home_screen.dart';
import 'screens/my_books_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/library_database_service.dart';
import 'services/library_repository.dart';
import 'utils/constants.dart';
import 'widgets/connection_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Практикалық жұмыс №4: Деректер қорын қосымша басталар алдында инициализациялау
  await LibraryDatabaseService().initializeDatabase();
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
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..restore(),
      child: MaterialApp(
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
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.initialized) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!auth.authenticated) return AuthScreen(onLoginSuccess: () {});
            return MainNavigationContainer(
              key: ValueKey(auth.user!['email']),
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeToggle: _toggleTheme,
            );
          },
        ),
      ),
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  final LibraryRepository? repository;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeToggle;

  const MainNavigationContainer({
    super.key,
    this.repository,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<MainNavigationContainer> createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer>
    with WidgetsBindingObserver {
  bool _showSplash = true;
  int _currentIndex = 0;
  int _myBooksTabIndex = 0;
  List<Book> _books = [];
  late final LibraryRepository _repository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository ?? LibraryRepository();
    _repository.addListener(_repositoryChanged);
    _books = _repository.books;
    _repository.refresh();
    if (widget.repository == null) _repository.startRealtime();
  }

  void _repositoryChanged() {
    if (mounted) setState(() => _books = _repository.books);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repository.removeListener(_repositoryChanged);
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _repository.retryRealtime();
  }

  Future<bool> _handleBookUpdate(Book book) => _repository.update(book);

  Future<bool> _handleBookAdd(Book book) => _repository.add(book);

  Future<bool> _handleBookDelete(String id) => _repository.delete(id);

  void _openMyBooks(int tab) => setState(() {
    _myBooksTabIndex = tab;
    _currentIndex = 2;
  });

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

    final screens = [
      HomeScreen(
        readerName:
            context.watch<AuthProvider>().user?['name'] as String? ?? 'Оқырман',
        books: _books,
        onBookUpdated: _handleBookUpdate,
        onNavigateToCatalog: () => setState(() => _currentIndex = 1),
        onNavigateToMyBooks: () => _openMyBooks(0),
      ),
      CatalogScreen(
        books: _books,
        onBookUpdated: _handleBookUpdate,
        onBookAdded: _handleBookAdd,
        onBookDeleted: _handleBookDelete,
      ),
      MyBooksScreen(
        books: _books,
        onBookUpdated: _handleBookUpdate,
        initialTabIndex: _myBooksTabIndex,
      ),
      ProfileScreen(
        onNavigateToFavorites: () => _openMyBooks(2),
        onNavigateToMyBooks: () => _openMyBooks(0),
        isDarkMode: widget.isDarkMode,
        onThemeToggle: widget.onThemeToggle,
        onLogout: () async {
          final auth = context.read<AuthProvider>();
          await auth.logout();
          if (context.mounted && auth.error != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(auth.error!)));
          }
        },
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          ConnectionBanner(repository: _repository),
          if (_repository.status == LibraryStatus.loading)
            const LinearProgressIndicator(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: widget.isDarkMode
            ? AppColors.surfaceDark
            : Colors.white,
        indicatorColor: AppColors.primary.withAlpha(
          widget.isDarkMode ? 60 : 30,
        ),
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
            selectedIcon: Icon(
              Icons.grid_view_rounded,
              color: AppColors.primary,
            ),
            label: 'Каталог',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(
              Icons.favorite_rounded,
              color: AppColors.primary,
            ),
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
