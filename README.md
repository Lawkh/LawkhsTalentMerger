# Lawkh's Talent Merger

Addon para **WoW Retail 12.1.0** (`Interface: 120100`). Agrupa las builds guardadas que tienen exactamente los mismos talentos, incluyendo las elecciones de talentos de héroe.

## Instalación

Copia la carpeta `LawkhsTalentMerger` a `World of Warcraft/_retail_/Interface/AddOns/` y reinicia el juego o ejecuta `/reload`. El archivo `.toc` debe quedar directamente dentro de esa carpeta.

Abre los talentos y pulsa **Lawkh's Talent Merger**, o usa `/tm`.

## Acciones

- **Merge**, primer botón: muestra los grupos repetidos. Si hay varios, elige Merge en el grupo. Pide un nombre y propone `X/Y/Z` con los nombres originales. La build resultante conserva los talentos idénticos: se renombra la primera instancia y se eliminan sus copias. Esto funciona aunque se haya alcanzado el límite de builds y conserva los ajustes de barras/equipo de la primera.
- **Clean**: muestra qué conserva y qué borra antes de confirmar. Conserva la primera instancia de cada grupo en el orden devuelto por WoW, además de todas las builds únicas. Actúa sobre la especialización actual.
- **Nuke**, encima de Clean: enumera todas las builds guardadas del personaje, de todas sus especializaciones. Solo permite confirmar al escribir exactamente `NUKE`. No restablece los talentos activos ni borra la configuración interna activa de WoW.

Las builds repetidas tienen el mismo color tanto en los grupos del addon como en el desplegable nativo de talentos. Los colores se asignan en orden de grupos y pueden cambiar tras una limpieza; la paleta se repite a partir del noveno grupo.

Atajos: `/tm merge`, `/tm clean`, `/tm nuke`; `/lawkhtm` también abre la ventana.

## Copias y comprobaciones

Antes de modificar builds se guardan sus nombres, especializaciones y cadenas de exportación en `LawkhsTalentMergerDB.backups` (SavedVariables por personaje). Se conservan las últimas 10 operaciones. Estas copias se pueden importar manualmente desde la interfaz de talentos; aún no hay una pantalla de restauración. WoW persiste SavedVariables al cerrar sesión o recargar la interfaz.

Las operaciones comprueban de nuevo la lista confirmada, se bloquean en combate y cuando hay cambios de talentos pendientes. Si una exportación falla no se considera repetida; Nuke se cancela si no puede copiar todas las builds. Los errores de renombrado o borrado se muestran en el chat, incluyendo fallos parciales.

## Desarrollo y validación

`npm ci` y `npm test` ejecutan pruebas Lua del agrupado, conservación de primeras instancias, Merge, confirmación NUKE, cambios tras la previsualización, combate y errores de API. Las dependencias Node solo se usan para pruebas y no se distribuyen con el addon.

La integración se basa en el [código de talentos de Blizzard](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentsFrame.lua) y sus contratos [C_ClassTalents](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ClassTalentsDocumentation.lua) y [C_Traits](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua). La referencia consultada es la rama `live`, no una instantánea fijada de 12.1.0. La compatibilidad exacta, disposición visual y ausencia de taint deben comprobarse en un cliente 12.1.0.

### Prueba en el juego pendiente

1. Guarda dos builds idénticas con nombres distintos, una distinta con el mismo nombre y otro par idéntico.
2. Comprueba agrupación y colores en el addon y en el desplegable nativo, también después de cambiar de especialización.
3. Cancela Merge/Clean y comprueba que no hay cambios. Ejecuta Merge con nombre personalizado y Clean con la lista de conservación esperada.
4. Cambia o añade builds después de abrir una confirmación: debe rechazar las confirmaciones obsoletas cuando afectan a la operación.
5. Comprueba bloqueo en combate y con talentos pendientes. Activa errores Lua (`/console scriptErrors 1`) para detectar fallos de integración.
6. En un personaje de prueba, verifica Nuke: cancelar, texto incorrecto, `NUKE`, todas las especializaciones y copia de exportaciones tras `/reload`.
