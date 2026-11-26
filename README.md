# Keyboard Cleaner

App de barra de menús para macOS que bloquea el teclado (y, si quieres, el
trackpad) para que puedas limpiarlo sin escribir nada por accidente.

Fork de [kfv/keylock](https://github.com/kfv/keylock) (MIT): conserva su
herramienta de línea de comandos y le suma una app nativa.

## Funciones

- Ícono en la barra de menús, sin ventana ni ícono en el Dock mientras corre.
- **Limpiar teclado**: bloquea solo el teclado; el trackpad sigue funcionando y
  hay un botón «Desbloquear» en pantalla.
- **Limpiar teclado y trackpad**: bloquea todo, incluidos clics, movimiento y scroll.
- Pantalla oscura a pantalla completa en todos los monitores, con cuenta regresiva
  (y fondo negro para ver mejor el polvo).
- Desbloqueo con **Control + U**, o automático a los 30 s, 1, 2, 5 o 10 min.
  No existe la opción «nunca»: el temporizador es la red de seguridad.
- Bloquea también brillo, volumen y teclas multimedia (opcional).
- Sonidos al bloquear y al desbloquear (opcional).
- Opción para abrir al iniciar sesión.
- Si vuelves a abrir la app desde el Dock o Spotlight, despliega su menú.

> El botón de encendido / Touch ID no se puede bloquear por software.

## Instalar

```sh
make install-app      # compila, firma e instala en /Applications
```

La primera vez, macOS pide permiso: **Ajustes del Sistema → Privacidad y
seguridad → Accesibilidad → Keyboard Cleaner**.

`scripts/bundle.sh` firma con la primera identidad «Apple Development» que
encuentra (así el permiso se mantiene entre compilaciones). Si no hay ninguna,
firma ad-hoc; en ese caso puede que tengas que volver a dar el permiso después
de cada compilación. Puedes forzar una identidad con `SIGN_IDENTITY=...`.

## Línea de comandos

```sh
make install          # instala `keylock` en /usr/local/bin
keylock               # bloquea teclado + trackpad hasta Control + U
keylock -t 120        # se desbloquea solo a los 120 s
keylock -k            # solo teclado
keylock --allow-system-keys
keylock -d            # modo debug
```

## Estructura

| Ruta | Qué es |
| --- | --- |
| `Sources/KeylockCore` | `InputLocker`: event tap a nivel HID (compartido) |
| `Sources/keylock` | CLI original (ArgumentParser) |
| `Sources/KeyboardCleaner` | App de barra de menús (AppKit) |
| `scripts/bundle.sh` | Arma y firma el `.app` |
| `scripts/make-icon.swift` | Genera el ícono |

## Licencia

MIT. Código original © 2023 Faraz Vahedi; ver `LICENSE`.
