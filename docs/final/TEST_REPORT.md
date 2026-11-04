# LibFlow — финалдық тест есебі

Күні: 2026-11-04. Орта: Windows host, Flutter/Dart SDK, уақытша JSON кэш,
оқшауланған PostgreSQL тест схемалары, Android Pixel 7 эмуляторы.

## Автоматты нәтиже

Flutter Unit/Widget: **62 PASS**, **0 failed**.
Жиын толық аяқталды: **True**. Қадамдары бар **31 Test Case**.
Бұл кесте нақты `flutter-tests.jsonl` оқиғаларынан жасалды; бір параметрленген
немесе кешенді тест бірнеше талапты тексере алады, олар жеке run деп саналмайды.
Нақты нәтиже — тесттегі expect/assert арқылы расталған мән.

| Test Case | Қадам | Күтілетін нәтиже | Нақты нәтиже | Күй |
|---|---|---|---|---|
| TC-01 Тіркелу | Жаңа email, аты-жөні, 8+ таңбалы парольмен submit. | true; профиль аты сақталады; пароль ашық сақталмайды. | true; профиль аты сақталады; пароль ашық сақталмайды. | PASS |
| TC-02 Қайталанған аккаунт | Сол email-мен екінші рет тіркелу. | false; қайталанған email қабылданбайды. | false; қайталанған email қабылданбайды. | PASS |
| TC-03 Қате пароль | Бар аккаунтқа қате парольмен кіру. | false; authenticated=false. | false; authenticated=false. | PASS |
| TC-04 Login | Бар аккаунтқа дұрыс парольмен, email регистрін өзгертіп кіру. | true; email регистрі қалыпқа келеді. | true; email регистрі қалыпқа келеді. | PASS |
| TC-05 Logout | Кірген аккаунтта logout орындау. | session жойылады; қорғалған экран жабылады. | session жойылады; қорғалған экран жабылады. | PASS |
| TC-06 Сессияны қалпына келтіру | Сол store-пен жаңа AuthProvider құрып restore. | Мерзімі өтпесе authenticated=true. | Мерзімі өтпесе authenticated=true. | PASS |
| TC-07 Сессия мерзімі | expiresAt өткен күнмен restore орындау. | authenticated=false. | authenticated=false. | PASS |
| TC-08 Кірусіз навигация | Бос store-пен қолданбаны ашу, бос форманы жіберу. | AuthScreen; каталог жоқ; валидация қатесі. | AuthScreen; каталог жоқ; валидация қатесі. | PASS |
| TC-09 Локалды Create | Тест кітабын insertBook арқылы қосу. | true; getBookById атауы сәйкес. | true; getBookById атауы сәйкес. | PASS |
| TC-10 Локалды Read | Кітаптарды оқу және Абай бойынша іздеу. | Тізім бос емес; сәйкес атау/автор табылады. | Тізім бос емес; сәйкес атау/автор табылады. | PASS |
| TC-11 Локалды Update | Кітап атауы мен favorite күйін өзгерту. | true; жаңа атау және isFavorite=true. | true; жаңа атау және isFavorite=true. | PASS |
| TC-12 Локалды Delete | Қосылған тест кітабын жою. | true; ID бойынша кітап null. | true; ID бойынша кітап null. | PASS |
| TC-13 REST GET / JSON | HTTP JSON жауабын Book объектілеріне түрлендіру. | UTF-8 мәтін мен өрістер дұрыс оқылады. | UTF-8 мәтін мен өрістер дұрыс оқылады. | PASS |
| TC-14 REST және UI CRUD | Mock HTTP арқылы қосу → өңдеу → жою. | Каталогта жаңа атау көрінеді, ескі/жойылған атау жоқ. | Каталогта жаңа атау көрінеді, ескі/жойылған атау жоқ. | PASS |
| TC-15 Offline REST | SocketException кезінде каталогты жүктеу және жазу. | false/Error; бұрынғы кэш сақталады. | false/Error; бұрынғы кэш сақталады. | PASS |
| TC-16 Форма қатесі/қайта сақтау | Save pending → false → қайта Save → true. | Loading; форма мен енгізу сақталады; кейін форма жабылады. | Loading; форма мен енгізу сақталады; кейін форма жабылады. | PASS |
| TC-17 Негізгі навигация | Басты → Каталог → Таңдаулы → Профиль → Таңдаулылар. | Қойынды индексі 2; сүйікті кітап көрсетіледі. | Қойынды индексі 2; сүйікті кітап көрсетіледі. | PASS |
| TC-18 Профиль маршруттары | QR, сандық билет, баптаулар, хабарламаларды ашу/қайту. | Тиісті экрандар ашылады; theme callback=true. | Тиісті экрандар ашылады; theme callback=true. | PASS |
| TC-19 Кітап маршруттары | Detail → editor → back → reader → back → audio sheet. | BookFormScreen, EReaderScreen, AudioPlayerSheet ашылады. | BookFormScreen, EReaderScreen, AudioPlayerSheet ашылады. | PASS |
| TC-20 Хабарлама навигациясы | Мерзімі 1 күнде бітетін loan; mark-read; хабарды басу. | Дедлайн хабары; My Books callback; хабар экраны жабылады. | Дедлайн хабары; My Books callback; хабар экраны жабылады. | PASS |
| TC-21 Camera granted | Permission mock granted беріп ask орындау. | CameraAccess.granted; restart-та unknown. | CameraAccess.granted; restart-та unknown. | PASS |
| TC-22 Camera denied/blocked | Permission mock denied/permanentlyDenied беріп ask. | Denied және blocked күйлері сәйкес. | Denied және blocked күйлері сәйкес. | PASS |
| TC-23 Бронь QR валидациясы | Белсенді, белгісіз және ескірген кодты тексеру. | Расталды / табылмады / мерзімі аяқталған. | Расталды / табылмады / мерзімі аяқталған. | PASS |
| TC-24 WebSocket sync | Local WebSocket серверге қосылу. | Бір sync; Online; catalogue_changed callback. | Бір sync; Online; catalogue_changed callback. | PASS |
| TC-25 Offline → reconnect | Серверді тоқтатып қосылу, сол портта қайта іске қосу. | Offline → Online; sync қайта жіберіледі. | Offline → Online; sync қайта жіберіледі. | PASS |
| TC-26 Қате realtime JSON | Серверден {invalid жіберу. | Error тіркеледі; жаңа байланыстан кейін Online. | Error тіркеледі; жаңа байланыстан кейін Online. | PASS |
| TC-27 Жүктеудегі оқиға | GET-ті кідірту; WS оқиғасын жіберу; GET-ті аяқтау. | Екінші GET; соңғы атау; жеке күй сақталған. | Екінші GET; соңғы атау; жеке күй сақталған. | PASS |
| TC-28 Броньді жою | Бронь коды/уақыты бар кітапта isReserved=false. | reservationCode=null; reservationTime=null. | reservationCode=null; reservationTime=null. | PASS |
| TC-29 Соңғы дана | availableCopies=0; кейін 1 қайтару. | isAvailable=false; кейін true. | isAvailable=false; кейін true. | PASS |
| TC-30 Кэш қатесі | Кэш каталогының орнына файл беріп refresh/add. | false/Error; жалған Success жоқ. | false/Error; жалған Success жоқ. | PASS |
| TC-31 Бос профиль аты | Бос name бар профильді ашу. | Аватар ?; exception жоқ. | Аватар ?; exception жоқ. | PASS |

## Сервер және Android

PostgreSQL + API + WebSocket + Docker пакет тесттері: **18 PASS**.
Android native интеграциялық сценарийі: **1 PASS**.
Тексеру ортасы: Flutter 3.47.9 / Dart 3.13.7; Android 17 API 37 эмуляторы.
Соңғы нақты нәтиже
`evidence/backend-tests.log` ішінде. TestClient REST/WS тесттері real PostgreSQL
схемаларына жазады; тек тест схемалары тест аяқталғанда жойылады.

Android интеграциялық сценарийі `integration_test/app_smoke_test.dart`:
native secure storage арқылы тіркелу/кіру/шығу, профиль/сканер навигациясы,
нақты серверде POST/PUT/DELETE және WebSocket оқиғасынан кейін экранның
өздігінен жаңаруы. Соңғы күй `evidence/android-integration-final.log` ішінде.
Өтпеген немесе құрылғыда орындалмаған сценарий PASS деп саналмайды.

Терминалдан APK орнату/іске қосу дәлелі `device-launch.log`; build нәтижесі
`apk-build.log`; analyzer нәтижесі `analyze.log` ішінде.

## Қамту шегі

- Камера permission логикасы unit mock-пен, QR код сәйкестігі таза функциямен тексерілді.
- Физикалық камерамен қағаз QR-ын оқу және телефондағы ОС рұқсат терезесі:
  **қолмен тексеру қажет**, автоматты PASS берілмейді.
- Физикалық Wi-Fi/ұялы желіні өшіру-қосу: **қолмен тексеру қажет**.
  Автотесттер socket үзілуін, сервердің қайтуын және heartbeat timeout-ты тексереді.
- Сыртқы Google Books/Open Library қызметтерінің қолжетімділігі кепілдендірілмейді;
  модель парсингі тексеріледі, финалдық native тест жергілікті API-ді қолданады.
- Аудио панелі — UI прототипі; нақты аудио playback нәтижесі берілмейді.

## Қайталап орындау

```powershell
flutter analyze --no-pub
flutter test --no-pub --machine
backend/.venv/Scripts/python.exe -m pytest backend -q --tb=short
flutter test --no-pub integration_test/app_smoke_test.dart -d emulator-5554
flutter build apk --debug --no-pub
```

Біріктірілген команда: `powershell -File scripts/verify.ps1 -DeviceId emulator-5554`.
Жаңа компьютерде алдымен README бойынша SDK, тәуелділіктер және серверді баптаңыз.
