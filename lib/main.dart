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
import 'services/library_api_service.dart';
import 'screens/operations_screen.dart';
import 'utils/constants.dart';
import 'utils/library_theme.dart';
import 'widgets/connection_banner.dart';
import 'services/demo_book_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DemoBookService.initialize();
  // Практикалық жұмыс №4: Деректер қорын қосымша басталар алдында инициализациялау
  await LibraryDatabaseService().initializeDatabase();
  runApp(const LibFlowApp());
}

class LibFlowApp extends StatefulWidget {
  const LibFlowApp({super.key, this.authApi});
  final LibraryApiService? authApi;

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
      create: (_) =>
          AuthProvider(api: widget.authApi ?? LibraryApiService())..restore(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: libraryTheme(Brightness.light),
        darkTheme: libraryTheme(Brightness.dark),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.initialized) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!auth.authenticated) return AuthScreen(onLoginSuccess: () {});
            if (auth.isStaff) {
              return OperationsScreen(
                key: ValueKey(auth.user!['email']),
                isDarkMode: _themeMode == ThemeMode.dark,
                onThemeToggle: _toggleTheme,
              );
            }
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
  int _myBooksTabIndex = 1;
  int _myBooksRequest = 0;
  int _searchRequest = 0;
  List<Book> _books = [];
  late final LibraryRepository _repository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final token = context.read<AuthProvider>().api?.sessionToken;
    _repository =
        widget.repository ??
        LibraryRepository(api: LibraryApiService()..sessionToken = token);
    _repository.addListener(_repositoryChanged);
    _books = _visibleBooks;
    _repository.refresh();
    if (widget.repository == null) _repository.startRealtime();
  }

  List<Book> get _visibleBooks =>
      _repository.api.sessionToken != null && !_repository.hasLoadedAccount
      ? const []
      : _repository.books;

  void _repositoryChanged() {
    if (mounted) setState(() => _books = _visibleBooks);
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

  Future<bool> _handleBookUpdate(Book book) async {
    final current = _repository.cache.getBookById(book.id);
    if (current == null) return false;
    if (current.isReserved != book.isReserved ||
        current.reservationCode != book.reservationCode) {
      if (!book.hasActiveReservation ||
          current.isReserved ||
          current.isBorrowed ||
          !current.isAvailable ||
          current.availableCopies <= 0 ||
          book.availableCopies != current.availableCopies - 1) {
        return false;
      }
      return _repository.update(
        current.copyWith(
          isReserved: true,
          reservationTime: book.reservationTime,
          reservationCode: book.reservationCode,
          availableCopies: book.availableCopies,
        ),
      );
    }
    return _repository.update(book);
  }

  Future<bool> _finishReservation(Book updated) async {
    final current = _repository.cache.getBookById(updated.id);
    if (current == null || !current.isReserved || updated.isReserved) {
      return false;
    }
    final user = context.read<AuthProvider>().user;
    final readerId = user?['ticket'] as String?;
    final started = current.reservationTime;
    final now = DateTime.now();
    final history = readerId == null || readerId.isEmpty || started == null
        ? null
        : Loan(
            id: 'reservation:$readerId:${current.id}:${started.toIso8601String()}',
            bookId: current.id,
            readerId: readerId,
            bookTitle: current.title,
            readerName: user?['name'] as String? ?? '',
            borrowDate: started,
            dueDate: updated.dueDate ?? started.add(const Duration(hours: 24)),
            returnDate: now,
            status: updated.isBorrowed && !current.isBorrowed
                ? 'collected'
                : current.hasActiveReservation
                ? 'cancelled'
                : 'expired',
            qrCode: '',
          );
    return _repository.update(updated, reservationHistory: history);
  }

  void _openMyBooks(int tab) => setState(() {
    _myBooksTabIndex = tab;
    _myBooksRequest++;
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
        demoBook: DemoBookService.book,
        loading: _repository.status == LibraryStatus.loading,
        onSearch: () => setState(() {
          _currentIndex = 1;
          _searchRequest++;
        }),
        readerName:
            context.watch<AuthProvider>().user?['name'] as String? ?? 'Оқырман',
        books: _books,
        onBookUpdated: _handleBookUpdate,
        savedBook: _repository.cache.getBookById,
        onNavigateToCatalog: () => setState(() => _currentIndex = 1),
        onNavigateToMyBooks: () => _openMyBooks(1),
      ),
      CatalogScreen(
        books: _books,
        onBookUpdated: _handleBookUpdate,
        savedBook: _repository.cache.getBookById,
        searchRequest: _searchRequest,
        loading: _repository.status == LibraryStatus.loading,
      ),
      MyBooksScreen(
        key: ValueKey(_myBooksRequest),
        books: _books,
        onBookUpdated: _handleBookUpdate,
        savedBook: _repository.cache.getBookById,
        initialTabIndex: _myBooksTabIndex,
        onReservationFinished: _finishReservation,
        serverHistory: _repository.api.sessionToken == null
            ? null
            : _repository.reservations,
        reservationHistory: _repository.cache.loans
            .where(
              (loan) =>
                  loan.id.startsWith('reservation:') &&
                  loan.readerId ==
                      context.watch<AuthProvider>().user?['ticket'],
            )
            .toList(),
      ),
      ProfileScreen(
        books: _books,
        onNavigateToFavorites: () => _openMyBooks(2),
        onNavigateToMyBooks: () => _openMyBooks(1),
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ConnectionBanner(repository: _repository),
            if (_repository.status == LibraryStatus.loading)
              const LinearProgressIndicator(),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: screens),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Басты',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Каталог',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number_rounded),
            label: 'Броньдар',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
