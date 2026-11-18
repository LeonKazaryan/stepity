# Stepity — правила для Claude

iOS-приложение, где шаги — путешествие по настоящей карте: линия пути по 3D-глобусу от дома к мечте, горы по этажам, цель недели, а после каждой прогулки — сцена «С прошлого раза». Второе приложение Leon после Nomaded. Глобус, дизайн-система и инструменты перенесены из Nomaded копированием.

## Перед задачей

- Прочитай нужные документы в `docs/`:
  - `01-product.md` — что это и скоуп;
  - `02-design.md` — палитра, движение, вибрация, вау-моменты;
  - `03-architecture.md` — слои, данные, ADR;
  - `04-roadmap.md` — задачи.
- Полный концепт и вся история обсуждения: `~/projects/ideas/next-app-2026-11/` (`README.md`, `daleko-concept.md`).

## Общение

- Отвечай Leon по-русски. Код, идентификаторы, комментарии и сообщения коммитов — на английском.
- Leon новичок в iOS: новую концепцию iOS/Swift/Metal объясни в 1–2 фразах, по делу.
- Продуктовое или дизайн-решение — один вариант с рекомендацией, а не список.

## Сборка и проверка

После изменений кода **всегда** проверяй сборку и тесты:

```bash
xcodebuild -project Stepity.xcodeproj -scheme Stepity \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' -quiet build

xcodebuild -project Stepity.xcodeproj -scheme Stepity \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' -quiet test
```

- `OS=18.6` обязателен. На iOS 26 — `name=iPhone 17 Pro`, на iOS 27 — `name=iPhone 18 Pro`.
- Сборка без ошибок и без новых warnings.
- Анимации, вибрацию и ощущения проверить не можешь: скажи Leon, что именно посмотреть на iPhone. Симулятор рисует не больше 60 fps и не вибрирует.

## Правила

- **Не коммить.** Коммитит Leon. Можно предложить текст коммита (Conventional Commits, на английском).
- **Сторонние зависимости** — только с согласия Leon и с ADR в `03-architecture.md`. Сервер для гонок с друзьями (Supabase) — отдельное решение, ещё не принято.
- **Файлы проекта:** `Stepity/` и `StepityTests/` — синхронизированные папки (Xcode 16+). Новые файлы просто создавай в нужной подпапке, `project.pbxproj` не трогай. Ручная правка — только build settings, осознанно.
- **Swift 6, iOS 18.** Strict concurrency. API новее iOS 18 — под `if #available`.
- **Данные здоровья.** Только чтение из HealthKit. Никогда не храним их ни в iCloud (App Review 5.1.3(ii)), ни на диске: на устройстве лежит только `SeenProgress` (что пользователь видел в прошлый раз) и дата начала пути (`JourneyStore`). Без рекламы и аналитики на этих данных (5.1.3(i)).
- **Путь считается с момента установки** (с полуночи того дня). Вся история «Здоровья» нужна только для пролога и для подбора лёгких первых целей. Кнопки «засчитать прошлое» нет — решение Leon.
- **Честные километры.** Никаких множителей: линия на глобусе — ровно пройденное расстояние.
- **Domain-логику покрывай тестами** (Swift Testing, `StepityTests/`). `Domain/` — чистый Swift без UI.
- **DesignSystem-токены** (`Palette`, `Typography`, `Motion`, `Haptics`, `HapticPlayer`, `.glassCard()`, `.capsule()`, `HeroNumber`) вместо магических чисел.
- **Строки:** английский ключ в `Text("…")` и сразу перевод в `Stepity/Resources/Localizable.xcstrings` (ru, плюс формы множественного числа, где есть число). Названия мест — из справочника (`nameRu`) или `Routes`.
- **Reduce Motion** — в каждой новой анимации (сцена «С прошлого раза» при нём сразу показывает итог).
- **Обновляй доки:** галочки в роадмапе, решения — в журнал ADR.

## Глобус

- Движок — копия `GlobeEngine` из Nomaded (Metal, 120 fps, рисует только когда что-то движется). Новое в Stepity: слой линии пути (`Trail.swift`, `GlobeController+Trail.swift`, шейдеры `trailVertex/trailFragment`, маркеры путника и остановок в `markerFragment`).
- Параметры ощущений — в `GlobeEngine/GlobeTuning.swift`; цвета глобуса — `GlobeStyle+Stepity.swift`.
- `Resources/Geo/*.nmgeo` и `cities.nmcity` скопированы из Nomaded, руками не редактируются. Перегенерировать — `Tools/GeoPipeline` в репозитории Nomaded.
- Иконка рисуется кодом: `Tools/AppIcon` (команда в его README).

## Проверка без касаний (DEBUG launch-аргументы)

```bash
xcrun simctl launch --terminate-running-process "iPhone 16 Pro" com.leonkazaryan.stepity \
  -StepityDebugReset YES -StepityDebugInstalledDaysAgo 40 -StepityDebugSeenKmAgo 6 -StepityDebugScreen journey
xcrun simctl io "iPhone 16 Pro" screenshot shot.png
```

- В симуляторе всегда придуманная история шагов с 2021 года (`DemoActivitySource`), одинаковая при каждом запуске. На iPhone — настоящее «Здоровье»; демо там включает `-StepityDebugDemo YES`.
- `-StepityDebugReset YES` — забыть начало пути и «что видел», как после установки.
- `-StepityDebugInstalledDaysAgo N` — путь начался N дней назад (онбординг пропускается).
- `-StepityDebugSeenKmAgo X` — в прошлый раз пользователь видел на X км меньше: играет сцена «С прошлого раза».
- `-StepityDebugScreen welcome|prologue|today|week|journey` — сразу на экран. `prologue` проигрывает пролог.
- `-StepityDebugExtraSteps N` — добавить N шагов к сегодняшнему дню демо.
- `-StepityDebugWorldview rus` — границы по витрине (как в Nomaded).
- Язык: `-AppleLanguages "(ru)" -AppleLocale ru_RU`.

## Окружение

- Xcode 27.2 (iOS 27.2 SDK), симуляторы iOS 18.6 (iPhone 16 Pro, основной), 26.3, 27.2.
- Bundle ID: `com.leonkazaryan.stepity`, команда та же, что у Nomaded (`A577864FRK`). HealthKit в entitlements.
- Репозиторий: https://github.com/LeonKazaryan/stepity
