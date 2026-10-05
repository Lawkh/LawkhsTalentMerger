# Lawkh's Talent Merger

Addon para **WoW Retail 12.1.0** (`Interface: 120100`). Agrupa las builds guardadas que tienen exactamente los mismos talentos, incluyendo las elecciones de talentos de héroe.

## Instalación

Copia la carpeta `LawkhsTalentMerger` a `World of Warcraft/_retail_/Interface/AddOns/` y reinicia el juego o ejecuta `/reload`. El archivo `.toc` debe quedar directamente dentro de esa carpeta.

Abre el desplegable de builds de talentos: **Merge** aparece en la posición 1, seguido de **Nuke** y **Clean**. También puedes abrir la ventana de grupos con el botón **Lawkh's Talent Merger** situado en la parte superior derecha de la ventana de talentos, o usar `/tm`.

Carpeta de instalación de este equipo: `D:\Juegos\World of Warcraft\_retail_\Interface\AddOns\LawkhsTalentMerger`.

## Quitar el addon

Desactívalo en la lista de addons o cierra WoW y borra únicamente la carpeta `LawkhsTalentMerger` de `Interface\AddOns`. No requiere bibliotecas externas ni modifica archivos de Blizzard u otros addons. Los hooks y colores desaparecen al reiniciar o recargar sin el addon.

Las copias de seguridad pueden quedarse en `WTF\Account\<cuenta>\<reino>\<personaje>\SavedVariables\LawkhsTalentMerger.lua` y su `.bak`; esos dos archivos son opcionales para eliminar sus datos. Quitarlo no revierte builds que hayas renombrado o borrado con Merge, Clean o Nuke.

## Acciones

- **Merge**, primer botón: muestra los grupos repetidos. Si hay varios, elige Merge en el grupo. Pide un nombre y propone `X/Y/Z` con los nombres originales. La build resultante conserva los talentos idénticos: se renombra la primera instancia y se eliminan sus copias. Esto funciona aunque se haya alcanzado el límite de builds y conserva los ajustes de barras/equipo de la primera.
- **Clean**: muestra qué conserva y qué borra antes de confirmar. Conserva la primera instancia de cada grupo en el orden devuelto por WoW, además de todas las builds únicas. Actúa sobre la especialización actual.
- **Nuke**, encima de Clean: enumera todas las builds guardadas del personaje, de todas sus especializaciones. Solo permite confirmar al escribir exactamente `NUKE`. No restablece los talentos activos ni borra la configuración interna activa de WoW.

Las builds repetidas tienen el mismo color tanto en los grupos del addon como en el desplegable nativo de talentos. El menú se modifica mediante `Menu.ModifyMenu("MENU_CLASS_TALENT_PROFILE")`; los nombres y callbacks de carga nativos se conservan. Los colores se asignan en orden de grupos y pueden cambiar tras una limpieza; la paleta se repite a partir del noveno grupo.

Atajos: `/tm merge`, `/tm clean`, `/tm nuke`; `/lawkhtm` también abre la ventana. `/tm status` muestra la versión, disponibilidad de las API, registro del menú y número de builds y grupos. Si `/tm` no existe, comprueba que el addon está activado y reinicia WoW para que descubra la carpeta recién instalada.

## Copias y comprobaciones

Antes de modificar builds se guardan sus nombres, especializaciones y cadenas de exportación en `LawkhsTalentMergerDB.backups` (SavedVariables por personaje). Se conservan las últimas 10 operaciones. Estas copias se pueden importar manualmente desde la interfaz de talentos; aún no hay una pantalla de restauración. WoW persiste SavedVariables al cerrar sesión o recargar la interfaz.

Las operaciones comprueban de nuevo la lista confirmada, se bloquean en combate, mientras el personaje está muerto o es un fantasma y cuando hay cambios de talentos pendientes. La comparación usa nodos seleccionados y sus rangos; omite elecciones de ramas de héroe inactivas. Si faltan datos de nodos utiliza igualdad exacta de exportación como alternativa. Las copias de seguridad contienen las exportaciones originales, nunca la firma de comparación. Las operaciones se cancelan si no pueden copiar todas las builds afectadas. Los errores de renombrado o borrado se muestran en el chat y en la confirmación, incluyendo fallos parciales. La lista y las confirmaciones comparten una única ventana. Volver cancela la acción pendiente y regresa a la lista. Confirmar regresa a la lista con el resultado solo tras una operación correcta; si falla, conserva el nombre escrito y muestra el motivo en la misma vista. Durante el borrado se muestra el progreso y Confirmar queda bloqueado. Los borrados se solicitan de uno en uno, esperando el evento de confirmación de WoW antes del siguiente. Una petición aceptada no se cuenta como borrada hasta confirmarla. Si WoW está ocupado se reintenta de forma limitada; ante un rechazo persistente, falta de confirmación, cambio de build, combate o muerte se detiene la cola y se informa del progreso y de las pendientes. Detener o cerrar la ventana impide enviar más peticiones, aunque la petición ya enviada puede completarse. Al entrar en combate se bloquean inmediatamente las acciones y Confirmar, aparece el aviso de combate y se conserva el nombre escrito. Al salir se habilitan de nuevo y se valida otra vez la lista antes de modificar builds.

## Desarrollo y validación

`npm ci` y `npm test` ejecutan 26 pruebas Lua de operaciones y 21 pruebas de interfaz simulada: agrupado, conservación de primeras instancias, Merge, confirmación NUKE, cambios tras la previsualización, combate, errores de API, guardas de retail, carga tardía de talentos, inserción de acciones y colores en el menú, conservación de callbacks nativos y reutilización de diálogos. La lectura de la especialización actual utiliza `PlayerUtil.GetCurrentSpecID()` y la consulta sin argumento de `GetConfigIDsBySpecID()` que se verificó en el cliente. `/tm status` detalla la especialización, IDs disponibles, configuraciones sin información y exportaciones fallidas. Las pruebas de interfaz no validan la apariencia ni el taint. Las dependencias Node solo se usan para pruebas y no se distribuyen con el addon.

La revisión del 5 de octubre de 2026 comprobó `.build.info` de este equipo: **12.1.0.69933**. La referencia de Blizzard consultada fue la etiqueta **12.1.0 (69933)**, que coincide con la build instalada: [interfaz de talentos](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentsFrame.lua), [C_ClassTalents](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/ClassTalentsDocumentation.lua), [C_Traits](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua), [C_SpecializationInfo](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua) y [menú nativo](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_SharedXML/Shared/LoadSystem/LoadSystemTemplates.lua). Se usan las API de especialización actuales, sin depender de sus antiguos alias globales. La disposición visual y ausencia de taint todavía deben comprobarse dentro del cliente.

### Prueba en el juego pendiente

1. Guarda dos builds idénticas con nombres distintos, una distinta con el mismo nombre y otro par idéntico.
2. Comprueba agrupación y colores en el addon y en el desplegable nativo, también después de cambiar de especialización.
3. Cancela Merge/Clean y comprueba que no hay cambios. Ejecuta Merge con nombre personalizado y Clean con la lista de conservación esperada.
4. Cambia o añade builds después de abrir una confirmación: debe rechazar las confirmaciones obsoletas cuando afectan a la operación.
5. Comprueba bloqueo en combate y con talentos pendientes. Activa errores Lua (`/console scriptErrors 1`) para detectar fallos de integración.
6. En un personaje de prueba, verifica Nuke: cancelar, texto incorrecto, `NUKE`, todas las especializaciones y copia de exportaciones tras `/reload`.
