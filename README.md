# LibFlow — Flutter кітапхана қосымшасы

Кітаптарды іздеу, каталог CRUD, локалды аккаунт, бронь QR-ын тексеру және
realtime каталог жаңартуы бір Flutter жобасына біріктірілген.
Нұсқа: **1.0.0+1**. Соңғы тапсыру құжаттары: [docs/final](docs/final/DELIVERY_README.md).

Финалдық тексеру: **78 Unit/Widget**, **24 backend**, **1 Android integration**
сценарийі өтті. Қадам/expected/actual көрсетілген **31 Test Case** бар.

## Мүмкіндіктері

- Registration/Login/Logout, қауіпсіз локалды сақтау және 30 күндік сессия.
- Home, Catalog, My Books, Profile; detail, form, reader, card, notifications, scanner маршруттары.
- PostgreSQL/FastAPI каталог CRUD, JSON файлындағы тұрақты офлайн кэш.
- WebSocket change events, heartbeat, автоматты retry/resync, Offline/Error мәтіндері.
- Камера permission және QR арқылы жергілікті белсенді броньды тексеру.
- Іздеу/сүзгі/сұрыптау, таңдаулылар, тараулармен оқу және түнгі тақырып.
- MP3 Play/Pause/seek/speed/resume; Басты экранда офлайн демо кітап.
- [Оқу және аудио нұсқаулығы](docs/READING_AUDIO.md).
- Google Books/Open Library іздеу интеграциясы.

Авторизация құрылғыда орындалады; backend API-де login/token/RBAC жоқ.
Кэш аккаунттарға ортақ. Тараулармен оқу, прогресті сақтау және нақты MP3 ойнату қосылды;
пікірлер экран жадында сақталады. Хабарламалар — жергілікті loan/reservation
ескертулері; ОС push қызметі қосылмаған. Бұл оқу/демо жобасы.

## Құрылымы

```text
lib/models/              Book және байланысты модельдер
lib/screens/             Экрандар мен маршруттар
lib/services/            Auth, REST, repository, JSON cache, WebSocket, scanner, log
lib/widgets/             Қайта пайдаланылатын UI
backend/                 FastAPI + PostgreSQL + WebSocket, тесттер
test/                    Unit және Widget тесттер
integration_test/        Android құрылғысындағы end-to-end smoke
scripts/                 Тексеру, диаграмма, есеп және пакет жинау
docs/final/              Архитектура, нұсқаулық, Test Report, Bug Report
```

## Қажетті орта

Flutter SDK (Dart **^3.13.2**, нақты SDK нұсқасы evidence/environment.log ішінде),
Android SDK/platform-tools, Java/Gradle, Python 3.13 және PostgreSQL.
Windows-та desktop plugin symlink үшін Developer Mode қажет болуы мүмкін.
Ол параметр автоматты өзгертілмейді. Android эмуляторын іске қосар алдында
жеткілікті RAM/commit memory барын тексеріңіз.

```powershell
flutter --version
flutter doctor -v
flutter devices
flutter emulators
flutter pub get
```

## Серверді іске қосу

```powershell
python -m venv backend/.venv
python -m pip --python backend/.venv/Scripts/python.exe install -r backend/requirements-dev.txt
powershell -NoProfile -ExecutionPolicy Bypass -File backend/start.ps1
```

Бар `.venv` ортасын қайта құру қажет емес. start.ps1 PostgreSQL 18-ді
`C:\Program Files\PostgreSQL\18\bin` ішінен іздейді; басқа жол үшін
`-PostgresBin` беріңіз. Скрипт осы жобаның жеке кластерін және базасын қолданады;
құпия URL ignored `backend/.env` ішінде сақталады.

Бар серверді қолдансаңыз, `.env.example` негізінде `DATABASE_URL` орнатыңыз:

```powershell
backend/.venv/Scripts/python.exe -m uvicorn backend.app:app --host 0.0.0.0 --port 8000
```

Диагностика: [Health](http://127.0.0.1:8000/health),
[Swagger](http://127.0.0.1:8000/docs). Сервер бір worker арқылы жұмыс істейді.
Docker баламасы: `docker compose up --build -d`.

## Аккаунттар және рөлдер

Қолданба сервер арқылы тіркеледі. Жаңа аккаунттың рөлі — оқырман.
Кітапханашы каталог пен броньдарды басқарады. Әкімші аккаунттар бөлімінде
рөл мен бұғаттау күйін өзгертеді. Құқық өзгерсе, бұрынғы сессиялар жабылады.
Бұрынғы жергілікті оқырман аккаунты алғашқы сәтті кіру кезінде серверде бос
email болған жағдайда тіркеледі. Құрылғыдағы ескі бронь кодтары серверге көшірілмейді.

Бірінші әкімшіні PostgreSQL іске қосылғаннан кейін жоба түбірінен жасаңыз:

```powershell
.\backend\.venv\Scripts\python.exe -m backend.create_admin admin@libflow.local
```

Команда құпиясөзді жасырын енгізуді сұрайды және бірінші әкімшіні ғана құрады.
Қолданба дерекқорында әкімші бар болса, келесі рөлдерді сол әкімші тағайындайды.
Әзірлеуден тыс ортада API-ды HTTPS арқылы ашыңыз.
## Терминалдан іске қосу және APK

Осы компьютерде бәрін бір командамен іске қосу:

```powershell
.\run.bat
```

PostgreSQL/API фондық режимде, Pixel_7 эмуляторы терезесімен ашылады;
соңынан Flutter қосылады. Терезесіз қосылған осы эмулятор автоматты қайта
ашылады, сақталған деректері жойылмайды. Іске қосылған сау сервер мен
терезесі бар эмулятор қайта пайдаланылады. Android Studio ашық тұруы міндетті емес.
Алғашқы SDK/venv/PostgreSQL орнатылымы жоғарыдағы нұсқаулық бойынша дайын болуы керек.

Тек баптауды тексеру: `.\run.bat -CheckOnly`.
Басқа эмулятор: `.\run.bat -AvdName YOUR_AVD`.
Тәуелділіктер өзгерсе: `.\run.bat -UpdateDependencies`.
Диагностикалық логтар: `build/launcher/`. Команда аяқталғанда терминалды жабуға
болады; қолданба, сервер және эмулятор ашық қалады.

Launcher APK-ны `adb install -r` арқылы деректерді сақтап жаңартады; жаңарту
сәтсіз болса, қолданбаны автоматты жоймай тоқтайды. Hot reload керек болса,
`.\run.bat -Attach` пайдаланыңыз (`q` debugger жұмысын тоқтатады).
Аккаунттың қайта ашылғанда сақталуы: [диагностика](docs/AUTH_PERSISTENCE.md).

```powershell
flutter emulators --launch Pixel_7
flutter devices
flutter run -d emulator-5554
flutter build apk --debug
```

Әдепкі API: Android-та `http://10.0.2.2:8000`, desktop-та `http://127.0.0.1:8000`.
Нақты телефон үшін компьютердің жергілікті IP мекенжайын беріңіз:

```powershell
flutter run -d DEVICE_ID --dart-define=API_BASE_URL=http://192.168.1.10:8000
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.10:8000
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.libflow.libflow/.MainActivity
adb logcat -s flutter AndroidRuntime
```

IP-ді өз желіңізге сәйкестендіріңіз. WebSocket URL осы API URL-дан жасалады.
APK: `build/app/outputs/flutter-apk/app-debug.apk`. Бұл debug APK оқу және демонстрация үшін жасалады; дүкенге жариялауға жеке signing қажет.
Тәуелділіктер бұрын шешілген болса, командаларға `--no-pub` қосуға болады.

## Тексеру және тапсыру

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
backend/.venv/Scripts/python.exe -m pytest backend -q --tb=short
flutter test --no-pub integration_test/app_smoke_test.dart -d emulator-5554
```

Қадамдар/expected/actual: [Test Report](docs/final/TEST_REPORT.md).
Қайталау қадамдары мен түзетулер: [Bug Report](docs/final/BUG_REPORT.md).
Пайдалану: [User Guide](docs/final/USER_GUIDE.md).
[Архитектура](docs/final/ARCHITECTURE.md), [PNG диаграмма](docs/final/architecture.png).

```powershell
powershell -File scripts/verify.ps1 -SkipPubGet -DeviceId emulator-5554
python scripts/package_final.py
```

Тапсыру папкасы: `delivery/LibFlow_Final_2026-11-04/`.
Оның ішінде APK, source, source ZIP, құжаттар, терминал дәлелдері және SHA-256 manifest бар.
Құпия файлдар мен build кэштері пакетке кірмейді. Презентация мен видеоны
пайдаланушы өзі жасайды.

Әзірлеуші: YerA-KAZ. Жоба: LibFlow — Smart Library Solution, 2026.
