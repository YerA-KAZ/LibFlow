# LibFlow: REST API + PostgreSQL

Flutter → `LibraryRepository` → `LibraryApiService` (`http`) → FastAPI → PostgreSQL.
Бұл жобаға өзінің REST API-і қосылды: сыртқы Google Books және Open Library
API-лері каталогқа іздеу үшін қосымша дереккөз ретінде сақталды.

## Осы компьютерде іске қосу (Windows)

PostgreSQL 18 орнатылған. Скрипт жүйелік базаны өзгертпей, `backend/.postgres/data`
ішінде бөлек кластер жасайды. Порт: **55432**, база және пайдаланушы: **libflow**.
Кездейсоқ құпиясөз `backend/.env` файлына жазылады; бұл файл Git-ке кірмейді.

Жоба түбірінен, бірінші рет:

```powershell
python -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -r backend/requirements-dev.txt
```

Егер venv ішінде pip құрылмаса:

```powershell
python -m pip --python backend/.venv/Scripts/python.exe install -r backend/requirements-dev.txt
```

Серверді іске қосу:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File backend/start.ps1
```

Басқа PostgreSQL жолы болса, `-PostgresBin 'D:\PostgreSQL\18\bin'` беріңіз.
Скриптті қайта іске қосу деректерді сақтайды. API-ді тоқтату: сол терминалда Ctrl+C.
Жоба PostgreSQL-ін тоқтату: `powershell -File backend/stop.ps1`.

- API: http://127.0.0.1:8000
- Swagger (сұрауларды орындауға болатын құжаттама): http://127.0.0.1:8000/docs
- OpenAPI JSON: http://127.0.0.1:8000/openapi.json
- Сервер мен база күйі: http://127.0.0.1:8000/health

PostgreSQL бұрыннан жұмыс істесе, `backend/.env.example` файлын `.env` ретінде
көшіріп, `DATABASE_URL` орнатыңыз. Содан кейін кластер скриптінсіз іске қосыңыз:

```powershell
backend/.venv/Scripts/python.exe -m uvicorn backend.app:app --host 0.0.0.0 --port 8000
```

## Docker арқылы балама іске қосу

Docker Desktop іске қосулы болуы керек. Бір уақытта native API мен Docker API-ді
8000 портында іске қоспаңыз.

```powershell
docker compose up --build -d
docker compose logs -f api
```

PostgreSQL деректері Docker volume ішінде сақталады. `docker compose down`
деректерді жоймайды. Жоба оқу/жергілікті пайдалану үшін дайындалған;
Интернетке жариялау үшін авторизация мен HTTPS қажет.

## Flutter-ді қосу

HTTP кітапханасы `pubspec.yaml` ішінде бұрыннан бар: `http: ^1.6.0`.
Офлайн файлды мобильді құрылғының жазуға болатын каталогында сақтау үшін
`path_provider` қосылды. Android INTERNET және cleartext рұқсаттары бар.

```powershell
flutter pub get
flutter run
```

Әдепкі мекенжай Android эмуляторында `http://10.0.2.2:8000`, desktop/iOS
симуляторында `http://127.0.0.1:8000`. Нақты телефонда телефон мен компьютер бір
Wi-Fi желісінде болсын; компьютердің жергілікті IP мекенжайын беріңіз:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

IP-ді өз компьютеріңіздің IP мекенжайына ауыстырыңыз. Firewall сервердің 8000
портына жеке желіден қосылуға рұқсат беруі керек. Нақты iOS құрылғысына HTTPS
сервер мекенжайын пайдаланыңыз. Flutter Web қолдауы бұрыннан бар `dart:io`
офлайн сақтау қабатына байланысты бұл жұмыстың ауқымына кірмейді.
Windows desktop құрастырғанда plugin symlink қатесі шықса, Windows Developer
Mode қосу қажет; Android құрастыруына бұл Windows desktop талабы қолданылмайды.

## Endpoint тізімі

| HTTP | Endpoint | Операция | Сәтті жауап |
|---|---|---|---|
| GET | `/health` | Сервер және PostgreSQL байланысын тексеру | 200, күй JSON |
| GET | `/api/books` | Барлық кітаптарды алу | 200, JSON массив |
| GET | `/api/books?q=Абай` | Атау, автор, ISBN бойынша іздеу | 200, JSON массив |
| GET | `/api/books/{id}` | Бір кітапты алу | 200, Book JSON |
| POST | `/api/books` | Жаңа кітап қосу | 201, сақталған Book |
| PUT | `/api/books/{id}` | Кітапты толық жаңарту | 200, сақталған Book |
| DELETE | `/api/books/{id}` | Кітапты өшіру | 204, бос жауап |

Қате кодтары: **404** — кітап жоқ, **409** — ID қайталанған,
**422** — JSON/өрістер дұрыс емес, **503** — PostgreSQL қолжетімсіз.
PUT сұрауында URL мен JSON ішіндегі ID сәйкес болуы керек.
DELETE қайталанса 404 қайтарады. SQL сұраулары параметрленген.

POST/PUT мысалы (толық өрістер Swagger схемасында):

```json
{
  "id": "book_demo",
  "title": "Қара сөздер",
  "author": "Абай Құнанбайұлы",
  "category": "Классика",
  "description": "Абайдың философиялық қара сөздері.",
  "pages": 180,
  "publishYear": 2020,
  "isbn": "978-601-demo",
  "rating": 4.8,
  "totalCopies": 5,
  "availableCopies": 5,
  "isAvailable": true,
  "hasEBook": true
}
```

## Flutter-дегі күйлер және жергілікті деректер

- Қосымша ашылғанда жергілікті кітаптар бірден көрінеді; содан соң GET жасалады.
- Loading: жоғарғы progress жолағы; сақтау формасында progress және өшірілген сақтау батырмалары.
- Success: сервер растаған дерек кэшке жазылып, басты экран/каталог/таңдаулылар жаңарады.
- Error: қазақша хабарлама, жоғарғы қайта жаңарту батырмасы. Форма қате кезінде жабылмайды.
- Интернет/сервер қолжетімсіз болса бұрынғы кэш көрсетіледі. Қате POST/PUT/DELETE жергілікті каталогты өзгертпейді.
- Сұрау мен жауап денесін толық алу үшін **10 секунд** timeout қолданылады.
- SocketException, ClientException, TimeoutException, қате JSON және HTTP қателері өңделеді.
- GET JSON `Book.fromMap()` арқылы Dart модельдеріне түрленеді; async/await қолданылады.
- `isFavorite`, `isReserved`, `reservationTime`, `reservationCode`, `isBorrowed`, `dueDate` құрылғыда сақталады және сервер кітаптарымен ID бойынша біріктіріледі.
- Сервер каталогы негізгі дереккөз: серверден өшірілген кітап келесі GET кезінде кэштен де алынады. Басқа жергілікті кестелер сақталады.
- Офлайн өзгерістерді серверге автоматты жіберу кезегі жоқ: байланыс қалпына келгенде әрекетті қайталау керек.
- Ескі desktop `libflow_offline_database.json` файлы алғашқы іске қосуда жаңа сақтау орнына көшіріледі; түпнұсқа өзгермейді.
- Сыртқы іздеу нәтижесі алғашқы сақтауда POST арқылы өз каталогымызға енгізіледі.
- Жеке бронь күйі жергілікті: бірнеше пайдаланушы арасында брондауды транзакциялық басқару бұл каталог CRUD API-іне кірмейді.

## Тексеру

```powershell
flutter analyze --no-pub
flutter test --no-pub
backend/.venv/Scripts/python.exe -m pytest backend/test_api.py -q
```

Backend тесттері нақты PostgreSQL ішінде бірегей уақытша схеманы құрып,
соңында тек сол схеманы өшіреді. Жобаның негізгі кітаптары өзгермейді.
`backend/.env` немесе `TEST_DATABASE_URL` арқылы жұмыс істейтін база қажет.

| Талаптар | Іске асырылған жер / тексеріс |
|---|---|
| 1–3. REST API, endpoint, HTTP әдістері | Осы құжат және `/docs` OpenAPI |
| 4. HTTP кітапханасы | `pubspec.yaml`: http |
| 5–7. GET, JSON → Model, UI | LibraryApiService, LibraryRepository, MainNavigationContainer |
| 8. POST | Қосу формасы → repository.add → createBook |
| 9. PUT | Өңдеу формасы → repository.update → updateBook |
| 10. DELETE | Өшіруді растау → repository.delete |
| 11. async/await | API, repository, форма және өшіру callback-тері |
| 12–14. Loading/Success/Error | LibraryStatus, progress, хабарламалар, қайта көру |
| 15–17. Offline/timeout/exception | library_api_service_test.dart |
| 18. Локалды деректермен байланыстыру | library_repository_test.dart: merge және тұрақты кэш |
| 19. Әр CRUD операциясын жеке тексеру | backend/test_api.py және library_api_service_test.dart |
| 20. UI дұрыс жаңаруы | library_ui_test.dart: қосу → өзгерту → өшіру және форма нәтижелері |

Қолмен тексеру: каталогта кітап қосыңыз → сервер `/api/books/{id}` ішінде бар
екенін қараңыз → атауын өзгертіңіз → қайта жүктеңіз → кітапты өшіріңіз.
Серверді тоқтатып, жаңарту/сақтау жасаңыз: қате көрініп, кэш сақталуы тиіс.

Қолданылған ресми құжаттама:
- FastAPI testing: https://fastapi.tiangolo.com/tutorial/testing/
- FastAPI lifespan testing: https://fastapi.tiangolo.com/advanced/testing-events/
- Psycopg transactions: https://www.psycopg.org/psycopg3/docs/basic/transactions.html
