# Финалдық тапсырманың орындалуы

| № | Талап | Орындалуы / дәлел |
|---|---|---|
| 1 | Модульдерді біріктіру | Бір Flutter main/Auth gate/Repository; FastAPI сервері |
| 2 | Экрандар мен навигация | TC-N01–N05; негізгі табтар, profile/card/settings/notifications/scanner, detail/form/reader/audio |
| 3 | Registration/Login/Logout | Unit/Widget және Android native интеграциялық сценарий PASS |
| 4 | Локалды CRUD | database_service_test.dart Create/Read/Update/Delete PASS |
| 5 | REST API | PostgreSQL интеграциялық тесттер және Android-та нақты POST/PUT/DELETE PASS |
| 6 | Күрделі құрылғы функциясы | QR permission mock/валидация PASS; Android-та scanner route PASS; физикалық QR оқу қолмен тексеріледі |
| 7 | Realtime | Local sockets, екі WS клиенті, native Android live update PASS |
| 8 | Кемінде 15 Test Case | TEST_REPORT.md: 31 Test Case |
| 9 | Қадам/expected/actual | TEST_REPORT.md кестесі |
| 10 | Bug Report | BUG_REPORT.md |
| 11 | Атау/қадам/expected/actual | Әр Bug Report жазбасында бар |
| 12 | Маңызды ақауларды түзету | Docker package, бронь тазарту, қор күйі, навигация, responsive UI, compiler typo түзетілді |
| 13 | Финалдық тест | 62 Unit/Widget + 18 backend + 1 Android integration PASS; analyzer таза |
| 14 | APK | apk/LibFlow-1.0.0.apk; build дәлелі apk-build.log |
| 15 | README | source/README.md және тапсыру папкасының README.md |
| 16 | Архитектура | ARCHITECTURE.md, architecture.png, architecture.svg |
| 17 | Пайдаланушы нұсқаулығы | USER_GUIDE.md |
| 18 | Demo Video | Пайдаланушы өзі жасайды; келісілген ауқымнан шығарылған |
| 19 | Презентация | Пайдаланушы өзі жасайды; келісілген ауқымнан шығарылған |
| 20 | Презентация мазмұны | Пайдаланушы өзі жасайды; техникалық деректер құжаттарда бар |
| 21 | Бір папкаға жинау | delivery/LibFlow_Final_2026-11-04: source/APK/documents/evidence/manifest |
| 22 | Іске қосу/демонстрация/қорғау | Android emulator native сценарийі орындалды; APK терминалдан орнатылады/ашылады; қорғауды пайдаланушы жүргізеді |

Тест PASS нәтижелерін физикалық камера/ұялы желі сынағының орнына қолдануға болмайды.
APK — оқу/демоға арналған debug build;
Play Store production signing бұл тапсырмада жасалмайды.
