# Аккаунттың қайта ашылғанда сақталуы

Аккаунттар әлі де сол Android құрылғысындағы flutter_secure_storage ішінде
сақталады; PostgreSQL users кестесі қосылған жоқ.

## Анықталған жағдай

Пайдаланушы сол Pixel_7 эмуляторында `run.bat` арқылы қайта ашқаннан кейін
аккаунт жоғалғанын хабарлады. Диагностика басталғанда негізгі аккаунт дерегі
жазылатын SharedPreferences файлы болған жоқ. Оның бұрын нақты қай әрекетте
жойылғанын ескі орнату логы болмағандықтан дәлелдеу мүмкін болмады.

Өзгеріс енгізілгенге дейін бөлек тест кілттерімен тіркелу → Android процесін
`am force-stop` арқылы тоқтату → сол орнатылымды қайта ашу орындалды:
session restore және logout-тан кейін Login **екеуі де өтті**. Бұл кәдімгі
process restart-тың өзінен дерек жоғалмағанын көрсетеді.

Тексерілген Flutter SDK-ның Android installApp жолы: install сәтсіз болса,
`Uninstalling old version...` арқылы қолданбаны жойып қайта орнатуға көшеді.
Бұл — деректі жоюы мүмкін анықталған жол, бірақ пайдаланушының бұрынғы
оқиғасында дәл сол жол орындалды деп бекітілмейді.

## Түзетулер

- `run.bat`: build → тікелей `adb install -r` → launch; `-Attach` берілсе ғана `flutter attach`.
  Автоматты uninstall/clear data жоқ; сәтсіз install кезінде логпен тоқтайды.
- Secure storage Android `resetOnError: false`: кілт/шифр қатесінде аккаунттарды
  үнсіз жоюға жол берілмейді. Бұрынғы namespace пен шифр алгоритмдері сақталды.
- Android backup өшірілді: басқа KeyStore кілтімен шифрланған preferences-тің
  автоматты қалпына келу мәселесін болдырмау үшін (`allowBackup=false`).
- Тіркелу және сессия жазылуы read-back арқылы тексеріледі. Жазу сақталмаса,
  UI сәтті тіркелді деп айтпайды. Оқылмайтын аккаунт JSON-ы бос қор ретінде
  қайта жазылмайды; пайдаланушыға сақтау қатесі көрсетіледі.
- Auth логтары операция/exception түрлерін ғана жазады; email, пароль және
  хэштер логқа шығарылмайды.

## Пайдалану

1. Сол жоба түбірінен `run.bat` іске қосыңыз.
2. Аккаунт бұрын жоғалып кеткен болса, бір рет қайта тіркеліңіз.
3. Келесі жолы сол email/құпиясөзбен «Кіру» пайдаланыңыз.
4. Қолданбаны жою, Clear storage немесе AVD Wipe Data локалды аккаунттарды
   жояды. `flutter clean` build файлдарын ғана тазалайды.
5. Сақтау/орнату қатесі болса, деректерді жоймай логты тексеріңіз:
   `build/launcher/install.log`.

Жойылып кеткен локалды аккаунтты бұл түзету қалпына келтірмейді.
Әртүрлі құрылғылар арасында аккаунтпен кіру үшін бөлек серверлік авторизация қажет.

## Қайта тексеру

`test/auth_persistence_test.dart`: жоғалған жазу, бүлінген JSON, оқу қатесі,
қайта ашу/Login және мерзімі біткен сессия. Бұрынғы auth/scanner тесттері де орындалады.
`tool/auth_restart_probe.dart` — әзірлеушіге арналған екі фазалы cold-process
сынағы. Тек `restart_probe_*` кілттерін пайдаланады және соңында соларды өшіреді;
негізгі `accounts`/`session` кілттеріне тимейді. Нәтиже — app-support каталогындағы
`auth_restart_probe_result.json`, тек boolean мәртебелер.

Осы тексерістің нәтижесі: 78 Flutter тесті PASS; analyzer — No issues found.
Native сынақта `registered`, `readBack`, process restart-тен кейін `restored`,
`loginAfterLogout` және launcher жаңартуынан кейінгі `launcherUpdateKeptInstallIdentity`
мәндері true болды. Жаңа қалыпты APK қауіпсіз орнатылып, қайта ашылды.
Нақты нәтижелер `build/auth-evidence/` ішінде.

Ресми анықтамалар: [AndroidOptions](https://pub.dev/documentation/flutter_secure_storage/latest/flutter_secure_storage/AndroidOptions-class.html),
[secure storage Android backup](https://pub.dev/packages/flutter_secure_storage),
[Android emulator cold boot](https://developer.android.com/studio/run/emulator-commandline).
