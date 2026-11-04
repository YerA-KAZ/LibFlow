# LibFlow: realtime және тұрақтылық

Тексеру күні: 2026-11-04.

## Таңдалған сценарий

Кітап каталогын және қолжетімді дана санын нақты уақытта жаңарту.
Бір клиент кітапты қосқанда, өңдегенде немесе жойғанда, басқа клиенттердің
каталогы автоматты өзгереді. Жеке таңдаулылар мен бронь коды синхрондау
кезінде құрылғыда сақталады.

Бұл гибридті байланыс: кітап деректерін жіберу/алу үшін қолданыстағы REST API,
өзгеріс туралы жедел хабарлау үшін WebSocket пайдаланылады.

```text
Flutter A → POST / PUT / DELETE → PostgreSQL commit
                                 ↓
                    WebSocket: catalogue_changed
                                 ↓
Flutter A, B → GET /api/books → жеке күйлерді біріктіру → кэш → UI
```

WebSocket: `/ws/catalogue`. Клиент `{"type":"sync"}` жібереді,
сервер `{"type":"catalogue_changed"}` қайтарады. Бұл бірінші қосылуда
және әр қайта қосылуда толық синхрондауды бастайды. Клиент
`{"type":"ping"}` жібереді; сервер `{"type":"pong"}` қайтарады.
Оқиға жүктеу кезінде келсе, repository оны белгілеп, ағымдағы операциядан
кейін тағы бір GET жасайды. Бірнеше оқиға бір кейінгі жаңартуға бірігеді.

## Іске қосу

```powershell
flutter pub get
python -m venv backend/.venv
python -m pip --python backend/.venv/Scripts/python.exe install -r backend/requirements-dev.txt
powershell -NoProfile -ExecutionPolicy Bypass -File backend/start.ps1
```

Бар `.venv` ортасын қайта құру қажет емес. `start.ps1` әдепкіде
`C:\Program Files\PostgreSQL\18\bin` орнын пайдаланады; басқа орынды
`-PostgresBin` параметрімен беріңіз. Серверді бір worker арқылы іске қосыңыз.

Басқа терминалда:

```powershell
# Android эмуляторы: әдепкі API_BASE_URL — http://10.0.2.2:8000
flutter run
# Нақты телефон: компьютердің телефонға қолжетімді LAN мекенжайы
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Desktop әдепкі мекенжайы — `http://127.0.0.1:8000`.
WebSocket мекенжайы API мекенжайынан құралады; HTTPS үшін WSS қолданылады.
Нақты телефонда компьютер мен телефон бір желіде болуы және сервердің
8000 портына рұқсат болуы қажет.

## Байланыс күйлері

- Connecting: байланыс орнату мәтіні; қосылу шегі — 10 секунд.
- Online: нақты уақыттағы байланыс қосылғанын көрсетеді.
- Offline: желі немесе сервер қолжетімсіз екенін, кэштегі кітаптар
  көрсетілетінін және автоматты қайта қосылуды түсіндіреді.
- Error: протокол дерегіндегі қате не REST/кэш қатесі түсінікті мәтінмен беріледі.

Қайта қосылу аралығы — 2 секунд. Heartbeat әр 15 секундта жүреді;
келесі тексеруге дейін pong келмесе, байланыс қайта орнатылады.
Қосымша алдыңғы жоспарға оралғанда да қайта қосылады.
Жаңарту батырмасы қолмен қайталауға мүмкіндік береді.
Жүйеден шығуда socket, handshake/heartbeat/retry таймерлері және listener-лер босатылады.
Offline кезіндегі серверге жазу сәтсіз болса, өзгеріс сәтті деп көрсетілмейді;
серверге жазуға арналған offline кезек бұл нұсқада қарастырылмаған.

## Refactoring және логтар

- `ConnectionBanner` байланыс интерфейсін негізгі навигациядан бөлді.
- REST және WebSocket бір `resolvedBaseUrl` мекенжайын қолданады.
- Repository-дегі ортақ `_run` Loading/Success/Error өңдеуін біріктіреді;
  `_cacheBook` қайталанатын кэш сақтау тексерісін біріктіреді.
- Негізгі экрандағы артық бастапқы dummy-көшірме мен қайталанатын жүктеу
  әдісі алынды. Қолданыстағы офлайн seed деректері сақталды.
- `AppLog` CRUD/refresh нәтижелерін, байланыс күйлерін, протокол және кэш
  қателерін `dart:developer` арқылы жазады. Сыртқы кітап іздеудегі
  қайталанатын `print`/debug-блоктары осы логқа көшірілді.
- Логтарда пароль, токен немесе кітап payload-ы жазылмайды; exception түрі
  ғана беріледі. Сервер логтары `uvicorn.error.libflow.realtime` арқылы өтеді.
- `lib/`, `test/`, backend, тәуелділіктер және платформалық баптаулар
  қаралды; бүкіл Flutter жобасына analyzer және барлық бар тесттер орындалады.
  `pubspec.yaml` ішінде пайдаланылмайтын asset декларациялары жоқ.

## Жаңа тесттер: күтілетін және нақты нәтижелер

Тесттерде `expect`/`assert` күтілетін мәнді нақты мәнмен салыстырады.
Flutter socket тесттері localhost-та шынайы WebSocket қосылымын қолданады;
сервер тесттері уақытша PostgreSQL схемаларын пайдаланады.

| Тест | Күтілетін нәтиже | Нақты нәтиже |
|---|---|---|
| Қосылу және sync | Online, бір sync, бір оқиға | PASS — күтілетін мәнмен сәйкес |
| Сервер push | Қосымша сұраусыз callback саны 2 | PASS — күтілетін мәнмен сәйкес |
| Сервер бастапқыда өшірулі | Offline → сервер оралғанда Online және sync | PASS — күтілетін мәнмен сәйкес |
| Қосылым үзілуі | Жаңа socket және екінші sync | PASS — күтілетін мәнмен сәйкес |
| Қате JSON | Error → қайта қосылу → Online | PASS — күтілетін мәнмен сәйкес |
| Үнсіз байланыс | Pong жоқ болса Offline | PASS — күтілетін мәнмен сәйкес |
| Heartbeat | Pong барда бір socket, Online | PASS — күтілетін мәнмен сәйкес |
| Қайталанатын connect | Бір ғана socket және sync | PASS — күтілетін мәнмен сәйкес |
| Қолмен retry | Жаңа socket және sync | PASS — күтілетін мәнмен сәйкес |
| Dispose | Жаңа retry/callback жоқ | PASS — күтілетін мәнмен сәйкес |
| GET кезінде realtime оқиға | Екі GET, соңғы атау, жеке күй сақталған | PASS — күтілетін мәнмен сәйкес |
| Repository dispose | Сұрау жоқ, операция false | PASS — күтілетін мәнмен сәйкес |
| Кэшке жазу қатесі | false және Error, жалған success жоқ | PASS — күтілетін мәнмен сәйкес |
| Offline виджеті | Кэш/қайта қосылу мәтіні, retry жұмыс істейді | PASS — күтілетін мәнмен сәйкес |
| Error виджеті | Түсінікті қате және қалпына келу мәтіні | PASS — күтілетін мәнмен сәйкес |
| Online виджеті | Online мәтіні, сау socket ауыстырылмайды | PASS — күтілетін мәнмен сәйкес |

Backend: sync/pong; екі клиентке POST/PUT/DELETE хабарлары; commit-тен
кейін қолжетімділікті оқу; offline аралығындағы өзгерісті қайта алу;
үш қате протокол хабарында тек қате клиентті жабу тексеріледі.
Бұрынғы REST, модель, авторизация, QR, CRUD және форма тесттері де сақталған.

## Қателер, себептері және түзетулері

| Қате | Анықтау | Себеп | Түзету / қайта тексеру |
|---|---|---|---|
| Экран жабылғанда pending timer | Авторизация widget тесті орындалмады | Future.timeout таймерін dispose тоқтата алмады | Бөлек handshake Timer, cleanup-та cancel; бастапқы widget тесті қайта өтті |
| Жүктеу үстіндегі оқиға жоғалуы | Repository кодының шолуы | Loading кезіндегі операция guard жаңартуды қабылдамайды | Pending refresh белгісі; кешіктірілген GET регрессиялық тесті |
| Кэшке жазылмаса да success | Кэш кодының шолуы және қате жолмен регрессиялық тест | _persistDatabase exception-ды жұтады, repository bool-ды елемейді | Exception тарату және bool тексеру; Error тексеріледі |
| Offline түсіндірмесінің жабылып қалуы | Баннер логикасын шолу | REST error Offline мәтінінен басым болды | Offline түсіндірмесіне басымдық; widget тесті |
| Тест сервері жабық socket-ке pong жібереді | Толық тест жиынында StreamSink is closed | Retry мен кешіккен heartbeat жарысы | Тест peer readyState тексеруі; heartbeat аралығы тұрақтандырылды |
| Analyzer ескертулері | flutter analyze | Артық import және if жақшасы | Import алынды, жақша қосылды; analyzer: No issues found |

Алғашқы PostgreSQL тексерісіндегі Permission denied — sandbox желі шектеуі;
рұқсат етілген ортада сол тесттер өтті. Бұл қолданба қатесі емес.
Backend тесттерінде Starlette/AnyIO-дан бір DeprecationWarning бар;
ол тесттердің орындалуына кедергі жасамайды.

## Қорытынды тексеру

- `flutter analyze`: No issues found.
- `flutter test --reporter expanded`: **55 тест өтті**, 0 failed.
- `pytest backend -q`: **17 тест өтті**, 0 failed; бір upstream deprecation warning.
- Жаңа Flutter тесттері: 10 realtime + 3 repository + 3 widget = **16 тест**.
- Android debug APK құрастырылды: `build/app/outputs/flutter-apk/app-debug.apk`.

## Тапсырма талаптарына сәйкестік

| Талаптар | Жобадағы орындалуы |
|---|---|
| 1–2: realtime сценарий | Кітап каталогы және қолжетімді дана саны |
| 3–4: технология және байланыс | `web_socket_channel` 3.0.3, FastAPI `/ws/catalogue`, `websockets` 15.0.1 |
| 5–6: жіберу, қабылдау, UI | REST арқылы өзгеріс → commit → WS broadcast → GET → cache → listener → UI; WS sync/ping жіберу |
| 7–9: үзілу, қалпына келу, күйлер | Heartbeat, connect timeout, автоматты retry/resync, lifecycle resume, ConnectionBanner |
| 10–12: шолу және refactoring | Analyzer, ортақ URL/лог/кэш helper, бөлінген баннер, артық dummy-көшірме/import/debug-блоктарды алу |
| 13: логтар | `AppLog`, CRUD/refresh нәтижелері, realtime және сервер байланыс оқиғалары |
| 14–15: ≥5 тест, expected/actual | 16 жаңа Flutter тесті, `expect`/`assert`, жоғарыдағы нәтижелер кестесі |
| 16–19: қате, себеп, түзету, ретест | Қателер кестесі және түзетулерден кейінгі толық тест жиыны |
| 20: тұрақтылық | 55 Flutter тесті, 17 backend тесті, analyzer, Android debug build |

## Тексеру командалары

```powershell
flutter analyze
flutter test --reporter expanded
backend/.venv/Scripts/python.exe -m pytest backend -q
flutter build apk --debug
```

Физикалық телефонда Wi-Fi/ұялы желіні өшіру-қосу бұл ортада орындалған жоқ.
Автотесттер серверді өшіру/қайта іске қосу, socket жабылуы және heartbeat
жауапсыздығы арқылы желі үзілуін тексереді. Құрылғыда қосымша тексеру:
екі клиент ашу → бірінде кітап өзгерту → екіншісінде автоматты жаңаруды көру →
желіні өшіру → Offline хабарын көру → желіні қосу → Online және жаңа каталогты көру.

Шектеу: notification hub бір сервер процесінің жадында. Бірнеше worker
немесе бірнеше сервер үшін ортақ Redis/PostgreSQL pub/sub қажет.
PostgreSQL-ге API-дан тыс тікелей жасалған өзгерістер broadcast жібермейді.

Негізгі ресми анықтамалар:
[Flutter WebSocket](https://docs.flutter.dev/cookbook/networking/web-sockets),
[web_socket_channel](https://pub.dev/documentation/web_socket_channel/latest/index.html),
[FastAPI WebSocket](https://fastapi.tiangolo.com/advanced/websockets/).
