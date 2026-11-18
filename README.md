# Stepity

Твои шаги — путешествие по настоящей карте. Линия всей прогулки тянется по 3D-глобусу от твоего дома к мечте, этажи поднимают на башни и горы, а после каждой прогулки сцена «С прошлого раза» показывает, что изменилось.

- iOS 18+, Swift 6, SwiftUI + Metal, HealthKit (только чтение), без сервера.
- Глобус — движок из [Nomaded](https://github.com/LeonKazaryan/nomaded).
- Документы: [`docs/`](docs/), правила для Claude: [`CLAUDE.md`](CLAUDE.md).

## Запуск

1. Открыть `Stepity.xcodeproj` в Xcode 27.
2. Выбрать симулятор iPhone 16 Pro (iOS 18.6): в нём будет придуманная история шагов. Или свой iPhone, тогда настоящее «Здоровье».
3. Run.

Быстро посмотреть сцену «С прошлого раза» в симуляторе:

```bash
xcrun simctl launch --terminate-running-process "iPhone 16 Pro" com.leonkazaryan.stepity \
  -StepityDebugReset YES -StepityDebugInstalledDaysAgo 40 -StepityDebugSeenKmAgo 6
```
