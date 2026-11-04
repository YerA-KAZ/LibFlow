# Registration + Login + Profile + Provider + QR Scanner

Авторизация осы құрылғыда орындалады: аккаунттар мен 30 күндік сессия
flutter_secure_storage арқылы сақталады. Құпиясөз ашық күйде сақталмайды:
PBKDF2-HMAC-SHA256, 210000 итерация, әр аккаунтқа кездейсоқ salt қолданылады.
Бұл серверлік авторизация емес; бұрынғы FastAPI каталог API-і өзгермейді.

## Қолдану

1. `flutter pub get`, содан соң Android/iOS құрылғысында `flutter run`.
2. «Аккаунт жасау» арқылы аты-жөні, email, 8+ таңбалы құпиясөз және қайталауын енгізу.
3. Қосымшаны толық жауып ашу: мерзімі өтпеген сессия қалпына келеді.
4. Профильде тіркелген адамның аты, email және оқырман билеті көрсетіледі.
5. Профильден шығу: сессия өшіріліп, кіру экраны ашылады.
6. Кітапты брондау, QR кодын басқа экранға көрсету немесе қағазға шығару.
7. Профиль → «Бронь QR кодын тексеру» → «Камераға рұқсат беру».
8. Камераға кодты көрсету: жергілікті белсенді бронь және 24 сағаттық мерзімі тексеріледі.

Камера рұқсаты қайта іске қосқанда автоматты түрде берілді деп саналмайды:
операциялық жүйеден қайта сұралады. Рұқсат берілмесе түсіндірме және қайталау,
біржола тыйым салынса құрылғы баптауларын ашу батырмасы бар.
QR арқылы кітапты беру немесе өшіру орындалмайды, тек бронь тексеріледі.
Қазіргі кітапхана кэші құрылғыға ортақ: жеке аккаунттарға бөлек кітап қорын
немесе серверлік көппайдаланушылық бронь басқаруын бұл жұмыс қоспайды.

## 17 талаптың орындалуы

| № | Іске асыру |
|---|---|
| 1–2 | auth_screen.dart: тіркелу, Form, email/name/password/confirm validation |
| 3–4 | AuthProvider.submit: аккаунт пен парольді тексеру, қате хабарламасы |
| 5–6 | AuthProvider.restore: қауіпсіз сақтау және сессия мерзімі |
| 7 | AuthProvider.logout: сессияны өшіру |
| 8 | ProfileScreen және LibraryCardScreen: нақты локалды аккаунт |
| 9–10 | Provider, ChangeNotifierProvider, Consumer, watch/read |
| 11–12 | mobile_scanner + qr_flutter: камера және оқылатын QR |
| 13–14 | ScannerAccess + QrScannerScreen: permission және бронь тексерісі |
| 15 | auth_and_scanner_test.dart: granted/denied/permanentlyDenied |
| 16 | Auth gate: кірусіз каталог ашылмайды; сканерде де auth тексерісі |
| 17 | Жаңа AuthProvider арқылы restart және қайта permission сұрау тесттері |

## Тексеру

`flutter analyze --no-pub` және `flutter test --no-pub`.
Автоматты тесттер қауіпсіз сақтауды және permission нәтижесін алмастырғыштармен тексереді.
Нақты камера, ОС permission терезесі және телефондағы толық restart қолмен тексеріледі.
Алдыңғы кезеңде құрылғы тексерілмеген. Соңғы APK және Android эмуляторы тексерісінің күйі docs/final/TEST_REPORT.md ішінде көрсетілген.

Android: INTERNET және CAMERA manifest ішінде. iOS: NSCameraUsageDescription
Info.plist ішінде. Swift Package Manager permission_handler камераны осы plist
кілтінен қосады. CocoaPods қолданылса permission_handler үшін PERMISSION_CAMERA=1
макросын Podfile post_install ішінде қосу керек.

Ресми нұсқаулықтар:
- https://pub.dev/packages/provider
- https://pub.dev/packages/mobile_scanner
- https://pub.dev/packages/permission_handler
- https://pub.dev/packages/flutter_secure_storage
- https://pub.dev/packages/cryptography
