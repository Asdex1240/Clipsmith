# Clipsmith — Reglas de código

Reglas para mantener el código simple, consistente y fácil de probar. Complementan a [MVP.md](MVP.md).

## 1. Idioma e internacionalización (i18n)
- **Código** (tipos, funciones, variables, nombres de archivo, claves de traducción, mensajes de commit): siempre en inglés.
- **Documentación** (`MVP.md`, este archivo): español. El código no lleva comentarios (ver sección 9).
- **La app es bilingüe: inglés (idioma base) y español.** Ningún texto visible al usuario va escrito directamente en el código.
- Mecanismo: archivos `Localizable.strings` por idioma, dentro de los recursos del target:
  ```
  Sources/Clipsmith/Resources/
  ├── en.lproj/Localizable.strings
  └── es.lproj/Localizable.strings
  ```
  y en `Package.swift`: `defaultLocalization: "en"` y `resources: [.process("Resources")]`.
- Las claves son identificadores en inglés con puntos (`export.title`, `timeline.split`), nunca el texto en sí.
- En el código se accede con `String(localized: "export.title", bundle: .module)` y, en SwiftUI, `Text("export.title", bundle: .module)`. Sin `bundle: .module` no encuentra las traducciones.
- Cada clave nueva se añade **a la vez** en `en` y `es`. Una prueba unitaria verifica que ambos archivos tienen exactamente las mismas claves.
- Textos con números o fechas: usar formatters (`FormatStyle`) y claves con parámetros, no concatenar strings.
- Nota técnica: los String Catalogs (`.xcstrings`) **no** sirven por ahora, porque `swift build` / `swift run` no los compila y las traducciones no cargan. Si algún día se migra a un proyecto Xcode, se pueden adoptar.

## 2. Arquitectura
- Respetar las capas: `Models/` → `Engine/` → `Views/`.
  - `Models/`: tipos `Codable` puros. **No importan** `AVFoundation`, `SwiftUI` ni `AppKit`. Son la fuente de verdad.
  - `Engine/`: construye `AVMutableComposition` / `AVVideoComposition` a partir del modelo, para preview y export. No conoce las vistas.
  - `Views/`: SwiftUI. No toca `AVFoundation` directamente para construir composiciones; pasa por el engine.
- Las dependencias van en un solo sentido: las vistas dependen del engine y del modelo; el engine depende del modelo; el modelo no depende de nada.
- Preview y export **usan la misma ruta** de construcción de composición. Nunca duplicar esa lógica.
- Sin dependencias externas salvo necesidad clara. Cualquier paquete nuevo se justifica en el PR/commit.

## 2b. Principios de Clean Code
- **Nombres que revelan la intención:** `splitClip(at:)` y no `doSplit()`. Sin abreviaturas ni nombres de una letra (salvo índices triviales).
- **Funciones pequeñas que hacen una sola cosa**, con un único nivel de abstracción. Ideal: ≤ 20 líneas y ≤ 3 parámetros.
- **Responsabilidad única (SRP):** cada tipo tiene una razón para cambiar. Un tipo que mezcla modelo, lógica y UI se divide.
- **Abierto/cerrado, inversión de dependencias:** el engine y los stores dependen de `protocol`s cuando eso facilite las pruebas (p. ej. un `MediaLoading` para no tocar disco en tests).
- **DRY:** no duplicar lógica; pero tampoco abstraer antes de tener dos usos reales (YAGNI).
- **KISS:** la solución más simple que cumpla el hito. Nada de código «por si acaso».
- **Sin valores mágicos:** constantes con nombre.
- **Sin efectos secundarios ocultos:** una función que consulta no modifica; una que modifica lo dice en su nombre (`removeClip`, no `getClip`).
- **Separar comandos de consultas** y preferir funciones puras en la lógica de edición.
- **Pocos niveles de anidación:** salidas tempranas con `guard`; máximo 2 niveles de indentación por función.
- **Booleanos como parámetro: evitar.** Usar dos funciones o un `enum`.
- **Operador ternario (`a ? b : c`): evitar.** Usar `if`/`else`, `guard` o un `switch`; si el valor se reutiliza, extraerlo a una función o propiedad con nombre.
- **Ley de Demeter:** no encadenar `a.b.c.d`; exponer lo necesario desde el tipo que lo posee.
- **Regla del boy scout:** dejar cada archivo que se toca un poco mejor de lo que estaba.

## 3. Estilo Swift
- Seguir las [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Indentación de 4 espacios; líneas de ~100 caracteres como máximo.
- El formato lo aplica `swift format format -i -r Sources Tests` con la configuración de `.swift-format` (100 columnas, 4 espacios). Se ejecuta antes de cada commit.
- `UpperCamelCase` para tipos, `lowerCamelCase` para el resto. Sin prefijos (`CS…`).
- Un tipo principal por archivo; el archivo lleva el nombre del tipo.
- Preferir `struct` y `enum` sobre `class`. Usar `class` solo si se necesita identidad o herencia (por ejemplo, `ObservableObject`).
- `let` por defecto; `var` solo si hay mutación.
- Evitar `!` (force unwrap), `try!` y `as!`. Usar `guard let`, `if let` o propagar el error.
- Preferir `guard` con salida temprana frente a anidar `if`.
- Control de acceso explícito donde ayude: `private` por defecto para lo que no se usa fuera del tipo.
- Sin código comentado (se borra, para eso está git) ni `print` de depuración en lo que se commitea; usar `Logger` (`os`) si hace falta registrar.

## 4. Modelo de datos
- Todo tipo persistido es `Codable` y `Identifiable`.
- **Tiempo siempre en segundos** (`TimeInterval`) en el modelo; convertir a `CMTime` solo en el engine, con un timescale fijo (p. ej. 600).
- Los cambios al formato `.json` deben ser compatibles hacia atrás: campos nuevos con valor por defecto u opcionales. Incluir un campo `version` en el proyecto cuando se implemente el guardado.
- Las rutas de archivos se guardan como referencias (más adelante, security-scoped bookmarks). Nunca se copia el material original dentro del proyecto sin pedirlo.
- Toda mutación del proyecto pasa por una única vía (p. ej. un `ProjectStore`) para que undo/redo funcione de forma uniforme.

## 5. SwiftUI y estado
- Vistas pequeñas y componibles; extraer subvistas cuando un `body` pase de ~50 líneas.
- Sin lógica de negocio en las vistas: va en el store o el engine.
- Estado con `@Observable` (macOS 14+); `@State` solo para estado local de la vista.
- El timeline es la parte más costosa: usar `Canvas` o AppKit si SwiftUI puro no rinde, pero encapsulado detrás de una vista con una interfaz simple.
- Cada vista nueva incluye un `#Preview`.

## 6. Concurrencia y rendimiento
- El hilo principal es solo para UI. Importación, miniaturas, waveform y export corren en segundo plano con `async/await`.
- Las operaciones largas (export, generación de waveform) deben ser **cancelables** y reportar progreso.
- Usar la API moderna de AVFoundation (`async` `load(...)`) en lugar de las propiedades síncronas obsoletas.
- Cachear miniaturas y waveforms; no regenerarlas en cada redibujado.
- Medir antes de optimizar. Objetivos: preview ≥ 30 fps a 1080p; export 1080p en menos de 2× la duración del video.

## 7. Errores
- Definir errores propios con `enum … : Error, LocalizedError` por módulo (`ImportError`, `ExportError`…).
- Nunca tragarse un error en silencio (`try?` sin razón). Si se ignora, se explica en un comentario.
- Los errores que afectan al usuario se muestran en la UI con un mensaje claro; los demás se registran con `Logger`.

## 8. Pruebas unitarias
- Herramienta: **XCTest**, ya configurado en el target `ClipsmithTests`; se ejecuta con `swift test` (verificado: funciona con el toolchain actual, Swift 6.3 / Xcode 26). Swift Testing (`import Testing`) también está disponible, pero se usa un solo framework por consistencia: XCTest.
- Los tests importan el código con `@testable import Clipsmith`, que funciona incluso en un `executableTarget`.
- El modelo y la lógica de edición (split, trim, ripple delete, snap, conversión de tiempos) **siempre** llevan pruebas en `Tests/ClipsmithTests/`.
- La lógica va fuera de las vistas precisamente para poder probarla sin UI.
- Estructura de cada test: **Given / When / Then** (preparar, actuar, verificar), con una sola idea por test.
- Nombres que describen el comportamiento: `testSplitCreatesTwoClipsAtPlayhead`.
- Tests rápidos y deterministas: sin red, sin depender de archivos del usuario ni del reloj. Los medios de prueba se generan en el test o son fixtures pequeños.
- Las dependencias externas (disco, AVFoundation) se sustituyen con dobles de prueba mediante protocolos.
- Un bug corregido añade primero un test que lo reproduce.
- Prueba obligatoria de i18n: las claves de `en` y `es` coinciden.
- `swift test` debe pasar antes de cada commit.

## 9. Comentarios: evitarlos
- **No se escriben comentarios en el código** (ni `//` ni `///`). Si el código necesita un comentario, está mal hecho: se arregla el código.
- En lugar de comentar:
  - Renombrar variables, funciones y tipos hasta que se expliquen solos.
  - Extraer el bloque confuso a una función con nombre descriptivo.
  - Reemplazar valores mágicos por constantes con nombre (`let fadeDuration = 0.5`).
  - Poner las unidades en el nombre o en el tipo (`durationInSeconds`, `TimeInterval`) en vez de anotarlas.
  - Usar tipos (`enum`, `struct`) para expresar las restricciones en lugar de describirlas.
- Los tests sirven de documentación del comportamiento esperado: nombres como `testSplitCreatesTwoClipsAtPlayhead`.
- Las decisiones de diseño y los riesgos se documentan en `MVP.md`, no en el código.
- Única excepción: directivas que exigen texto (`// MARK:` para navegar archivos largos, `// swiftlint:disable`, `// TODO:` con motivo) y la licencia si algún día se añade. Los `// TODO:` no se commitean a `main`.

## 10. Git y flujo de trabajo
- Commits pequeños y atómicos, en inglés, en imperativo y con un prefijo: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Una rama por hito o funcionalidad (`feat/timeline-split`); `main` siempre compila y pasa los tests.
- No commitear `.build/`, `.DS_Store`, claves ni certificados de firma.
- Alcance: no añadir funciones fuera del MVP sin actualizar antes `MVP.md`.
