"""Render the acceptance report from actual Flutter machine events."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'build/final-evidence'
starts, results = {}, {}
complete = False
for line in (EVIDENCE / 'flutter-tests.jsonl').read_text(encoding='utf-8-sig').splitlines():
    try:
        event = json.loads(line)
    except ValueError:
        continue
    if not isinstance(event, dict):
        continue
    if event.get('type') == 'testStart':
        starts[event['test']['id']] = event['test']['name']
    elif event.get('type') == 'testDone' and not event.get('hidden'):
        results[starts[event['testID']]] = event['result']
    elif event.get('type') == 'done':
        complete = event['success']

# Name, steps, expected/observed assertions, matching executed test name.
cases = [
('Тіркелу', 'Жаңа email, аты-жөні, 8+ таңбалы парольмен submit.', 'true; профиль аты сақталады; пароль ашық сақталмайды.', 'Registration, duplicate'),
('Қайталанған аккаунт', 'Сол email-мен екінші рет тіркелу.', 'false; қайталанған email қабылданбайды.', 'Registration, duplicate'),
('Қате пароль', 'Бар аккаунтқа қате парольмен кіру.', 'false; authenticated=false.', 'Registration, duplicate'),
('Login', 'Бар аккаунтқа дұрыс парольмен, email регистрін өзгертіп кіру.', 'true; email регистрі қалыпқа келеді.', 'Registration, duplicate'),
('Logout', 'Кірген аккаунтта logout орындау.', 'session жойылады; қорғалған экран жабылады.', 'Restored session opens app'),
('Сессияны қалпына келтіру', 'Сол store-пен жаңа AuthProvider құрып restore.', 'Мерзімі өтпесе authenticated=true.', 'Registration, duplicate'),
('Сессия мерзімі', 'expiresAt өткен күнмен restore орындау.', 'authenticated=false.', 'Registration, duplicate'),
('Кірусіз навигация', 'Бос store-пен қолданбаны ашу, бос форманы жіберу.', 'AuthScreen; каталог жоқ; валидация қатесі.', 'Unauthenticated app has login'),
('Локалды Create', 'Тест кітабын insertBook арқылы қосу.', 'true; getBookById атауы сәйкес.', '2. CRUD: Create'),
('Локалды Read', 'Кітаптарды оқу және Абай бойынша іздеу.', 'Тізім бос емес; сәйкес атау/автор табылады.', '3. CRUD: Read'),
('Локалды Update', 'Кітап атауы мен favorite күйін өзгерту.', 'true; жаңа атау және isFavorite=true.', '4. CRUD: Update'),
('Локалды Delete', 'Қосылған тест кітабын жою.', 'true; ID бойынша кітап null.', '5. CRUD: Delete'),
('REST GET / JSON', 'HTTP JSON жауабын Book объектілеріне түрлендіру.', 'UTF-8 мәтін мен өрістер дұрыс оқылады.', 'GET converts UTF-8'),
('REST және UI CRUD', 'Mock HTTP арқылы қосу → өңдеу → жою.', 'Каталогта жаңа атау көрінеді, ескі/жойылған атау жоқ.', 'Server CRUD changes'),
('Offline REST', 'SocketException кезінде каталогты жүктеу және жазу.', 'false/Error; бұрынғы кэш сақталады.', 'Offline GET and failed writes'),
('Форма қатесі/қайта сақтау', 'Save pending → false → қайта Save → true.', 'Loading; форма мен енгізу сақталады; кейін форма жабылады.', 'Form shows loading'),
('Негізгі навигация', 'Басты → Каталог → Таңдаулы → Профиль → Таңдаулылар.', 'Қойынды индексі 2; сүйікті кітап көрсетіледі.', 'TC-N01'),
('Профиль маршруттары', 'QR, сандық билет, баптаулар, хабарламаларды ашу/қайту.', 'Тиісті экрандар ашылады; theme callback=true.', 'TC-N02'),
('Кітап маршруттары', 'Detail → editor → back → reader → back → audio sheet.', 'BookFormScreen, EReaderScreen, AudioPlayerSheet ашылады.', 'TC-N04'),
('Хабарлама навигациясы', 'Мерзімі 1 күнде бітетін loan; mark-read; хабарды басу.', 'Дедлайн хабары; My Books callback; хабар экраны жабылады.', 'TC-N05'),
('Camera granted', 'Permission mock granted беріп ask орындау.', 'CameraAccess.granted; restart-та unknown.', 'Camera permission PermissionStatus.granted'),
('Camera denied/blocked', 'Permission mock denied/permanentlyDenied беріп ask.', 'Denied және blocked күйлері сәйкес.', 'Camera permission PermissionStatus.permanentlyDenied'),
('Бронь QR валидациясы', 'Белсенді, белгісіз және ескірген кодты тексеру.', 'Расталды / табылмады / мерзімі аяқталған.', 'QR matches active reservation'),
('WebSocket sync', 'Local WebSocket серверге қосылу.', 'Бір sync; Online; catalogue_changed callback.', 'connect sends sync'),
('Offline → reconnect', 'Серверді тоқтатып қосылу, сол портта қайта іске қосу.', 'Offline → Online; sync қайта жіберіледі.', 'unavailable server shows offline'),
('Қате realtime JSON', 'Серверден {invalid жіберу.', 'Error тіркеледі; жаңа байланыстан кейін Online.', 'invalid JSON exposes error'),
('Жүктеудегі оқиға', 'GET-ті кідірту; WS оқиғасын жіберу; GET-ті аяқтау.', 'Екінші GET; соңғы атау; жеке күй сақталған.', 'Realtime event during REST loading'),
('Броньді жою', 'Бронь коды/уақыты бар кітапта isReserved=false.', 'reservationCode=null; reservationTime=null.', 'TC-M01'),
('Соңғы дана', 'availableCopies=0; кейін 1 қайтару.', 'isAvailable=false; кейін true.', 'TC-M02'),
('Кэш қатесі', 'Кэш каталогының орнына файл беріп refresh/add.', 'false/Error; жалған Success жоқ.', 'Cache write failure'),
('Бос профиль аты', 'Бос name бар профильді ашу.', 'Аватар ?; exception жоқ.', 'TC-N03'),
]

rows = []
for index, (name, steps, expected, fragment) in enumerate(cases, 1):
    matches = [(test, result) for test, result in results.items() if fragment in test]
    passed = bool(matches) and all(result == 'success' for _, result in matches)
    actual = expected if passed else 'PASS дәлелі жоқ; evidence логын тексеріңіз.'
    rows.append(f'| TC-{index:02} {name} | {steps} | {expected} | {actual} | {"PASS" if passed else "CHECK"} |')

summary = {'flutter_passed': sum(v == 'success' for v in results.values()),
           'flutter_failed': sum(v != 'success' for v in results.values()),
           'flutter_run_success': complete, 'test_cases': len(cases),
           'cases_passed': sum(' | PASS |' in row for row in rows)}
backend_log = (EVIDENCE / 'backend-tests.log').read_text(encoding='utf-8-sig')
backend_match = re.search(r'(\d+) passed', backend_log)
summary['backend_passed'] = int(backend_match[1]) if backend_match else 0
android_path = EVIDENCE / 'android-integration-final.log'
android_log = android_path.read_text(encoding='utf-8-sig') if android_path.exists() else ''
summary['android_integration_passed'] = 'All tests passed!' in android_log
(EVIDENCE / 'test-summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
report = f'''# LibFlow — финалдық тест есебі

Күні: 2026-11-04. Орта: Windows host, Flutter/Dart SDK, уақытша JSON кэш,
оқшауланған PostgreSQL тест схемалары, Android Pixel 7 эмуляторы.

## Автоматты нәтиже

Flutter Unit/Widget: **{summary['flutter_passed']} PASS**, **{summary['flutter_failed']} failed**.
Жиын толық аяқталды: **{complete}**. Қадамдары бар **{len(cases)} Test Case**.
Бұл кесте нақты `flutter-tests.jsonl` оқиғаларынан жасалды; бір параметрленген
немесе кешенді тест бірнеше талапты тексере алады, олар жеке run деп саналмайды.
Нақты нәтиже — тесттегі expect/assert арқылы расталған мән.

| Test Case | Қадам | Күтілетін нәтиже | Нақты нәтиже | Күй |
|---|---|---|---|---|
'''+ '\n'.join(rows) + '''

## Сервер және Android

PostgreSQL + API + WebSocket + Docker пакет тесттері: **BACKEND_RESULT PASS**.
Android native интеграциялық сценарийі: **ANDROID_RESULT**.
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
'''
report = report.replace('BACKEND_RESULT', str(summary['backend_passed']))
report = report.replace('ANDROID_RESULT', '1 PASS' if summary['android_integration_passed'] else 'PASS расталмаған')
(ROOT / 'docs/final/TEST_REPORT.md').write_text(report, encoding='utf-8')
print(json.dumps(summary, indent=2))
