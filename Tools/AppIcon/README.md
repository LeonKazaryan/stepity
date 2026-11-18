# AppIcon

Рисует иконку Stepity кодом: ночной глобус приложения (контуры стран из `world.nmgeo`, та же палитра, затемнение краёв, блик и свечение атмосферы, что у `GlobeShading`) и светящуюся линию пути от Алматы на запад к Парижу с путником на конце. Основа — генератор иконки Nomaded.

Пишет три PNG 1024×1024 в `AppIcon.appiconset` (обычная без альфа-канала, тёмная на прозрачном, тонированная в оттенках серого):

```bash
swiftc -O Tools/AppIcon/main.swift Stepity/GlobeEngine/WorldGeometry.swift Stepity/GlobeEngine/GeoMath.swift Stepity/GlobeEngine/Worldview.swift -o "$TMPDIR/appicon"
"$TMPDIR/appicon" Stepity/Resources/Geo/world.nmgeo Stepity/Resources/Assets.xcassets/AppIcon.appiconset
```

Цвета продублированы из `Palette.swift`: при их изменении поправь и здесь.
