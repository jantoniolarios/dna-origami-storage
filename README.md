# Almacenamiento de información en estructuras de DNA origami

Codifica el contenido de un archivo de texto como una secuencia de nucleótidos
y lo inserta en la región de staples de un diseño de DNA origami en formato
oxDNA (`.top`), de modo que el texto pueda recuperarse después a partir del
archivo de topología.

El proyecto incluye además una segunda capa de codificación opcional y un
módulo experimental con la red seq2seq que se entrenó para aprenderla.

---

## Puesta en marcha

Requiere MATLAB R2020a o posterior. El pipeline principal solo usa funciones
base; el módulo `seq2seq/` necesita además Deep Learning Toolbox y Text
Analytics Toolbox.

```matlab
>> cd ruta/al/repositorio
>> startup          % añade src/ al path
>> runTests         % comprueba que todo funciona en este equipo
```

### Codificar

```matlab
>> encodeToStructure
```

El script pide un archivo de texto, lo codifica, muestra el catálogo de
estructuras disponibles con su capacidad, inserta el mensaje en la elegida y
guarda el resultado en `output/`. Al final pregunta si se quiere aplicar
también la capa 2.

### Decodificar

```matlab
>> decodeFromStructure
```

Pide un archivo `.top` y recupera el texto.

### Añadir estructuras

Copia cualquier archivo `.top` en `structures/` y aparecerá como opción, con
su capacidad calculada automáticamente.

---

## Cómo funciona

### Capa 1 — texto a nucleótidos

Cada carácter se sustituye por un codón de 4 nucleótidos según una tabla de
224 símbolos (`src/codec/dnaCodebook.m`). La tabla cubre el juego CP437
(ASCII imprimible, vocales acentuadas, eñes, caracteres de dibujo de caja).

Un carácter fuera de la tabla (una raya larga `—`, el símbolo del euro) no
puede codificarse. El script **avisa de cuáles se omitirán y pide confirmación**
en lugar de descartarlos en silencio.

### Marcadores de inicio y fin

El mensaje se enmarca entre dos marcadores:

```
GCGTGTAT  <mensaje codificado>  GTCAGTCT
```

Los cuatro codones que los forman (`GCGT`, `GTAT`, `GTCA`, `GTCT`) están
reservados: no corresponden a ningún símbolo, así que un mensaje nunca puede
producirlos por casualidad.

Hay dos protecciones distintas contra confundir el diseño original con un
mensaje, y conviene no mezclarlas:

**El anclaje es la protección real.** El codificador siempre escribe desde el
primer nucleótido de la región de staples, así que el decodificador exige el
marcador exactamente ahí. Una coincidencia a mitad de la región no puede
tomarse por mensaje. Con `extractPayload(top, [], true)` se recorre toda la
región, pero eso solo hace falta para archivos escritos por otra herramienta.

**La elección del marcador es defensa en profundidad.** La secuencia se eligió
midiéndola contra los 72 367 nucleótidos de las cuatro estructuras del
proyecto: cero apariciones, ninguna base repetida adyacente y 50 % de GC.

### Inserción en la estructura

Los nucleótidos del mensaje sobrescriben las bases de los primeros staples, y
**solo esos**. El resto de la región conserva sus bases de diseño.
El marcador final es lo que indica al decodificador dónde termina la información.

El scaffold (hebra 1) nunca se toca, y de los staples solo cambia la columna
de bases: los índices de hebra y los vecinos 3'/5' se reescriben idénticos.

### Capa 2 — opcional

Expande cada codón de 4 nucleótidos a un bloque de 8 añadiendo su
complemento base a base:

```
GTAC  ->  GTAC CATG
AAAC  ->  AAAC TTTG
```

Duplica el tamaño del mensaje y reduce a la mitad la capacidad de la
estructura. La detección al decodificar es automática: una cadena de capa 2
cumple la relación bloque/complemento en todos sus bloques, y una de capa 1
no lo haría más que por coincidencia.

### Simulación de errores de síntesis

En simulación la recuperación es perfecta, lo que no dice nada sobre qué
pasaría con una cadena sintetizada de verdad. `decodeFromStructure` y
`decodeChain` ofrecen, justo antes de decodificar, inyectar un porcentaje de
error de tres tipos: **sustitución**, **eliminación** e **inserción**.

Los tres no hacen el mismo daño, y esa es la razón de separarlos:

| Tipo | Efecto |
|---|---|
| Sustitución | Daña su propio carácter. Pero el 6.4 % de las veces produce uno de los 32 codones sin símbolo asignado, que al descartarse recorre el texto posterior. |
| Eliminación | Corre el marco de lectura. Todo lo que viene después se lee desplazado. |
| Inserción | Igual que la eliminación, en el otro sentido. |

El informe da dos medidas:

- **Exactitud posicional** — lo que de verdad se lee. Un solo indel la hunde.
- **Similitud de Levenshtein** — cuánta información sobrevive, sin penalizar
  el corrimiento.

La diferencia entre ambas *es* el daño por desplazamiento de marco. Sobre un
mensaje de 1 596 nt, eliminar **2 nucleótidos (0.125 %)** deja la exactitud
posicional por debajo del 20 % y la similitud en torno al 24 %: el mensaje se
pierde casi entero.

### Capacidades

| Estructura | Nucleótidos | Hebras | Scaffold | Staples | Capa 1 | Capa 2 |
|---|---:|---:|---:|---:|---:|---:|
| `Cube` | 14 352 | 18 | 7 176 | 7 176 | 1 790 | 893 |
| `Interlock` | 22 378 | 83 | 11 430 | 10 948 | 2 733 | 1 364 |
| `Octagon` | 21 600 | 58 | 10 800 | 10 800 | 2 696 | 1 346 |
| `Steward` | 14 037 | 77 | 7 167 | 6 870 | 1 713 | 854 |

Las cifras de capa 1 y capa 2 son caracteres, ya descontados los cuatro
codones de los marcadores. 

En las estructuras de `Interlock` y `Steward` los staples no suman lo mismo
que el scaffold: esos diseños dejan tramos de scaffold sin emparejar, y por
eso su capacidad es menor de lo que haría pensar su tamaño total.

### Archivos de configuración

Cada `.top` puede ir acompañado de un `.conf` con el mismo nombre, que
contiene las posiciones de los nucleótidos. El pipeline solo cambia bases,
nunca posiciones, así que el `.conf` original sigue siendo válido para la
estructura generada: `encodeToStructure` lo copia a `output/` junto al `.top`
nuevo y con el mismo nombre, de modo que el resultado se puede cargar
directamente en oxView.

---

## Estructura del repositorio

```
src/codec/       codificación de texto a nucleótidos y las dos capas
src/topology/    lectura, escritura y análisis de archivos .top
src/pipeline/    construcción, inserción y extracción del mensaje
src/util/        rutas portables y utilidades de consola
src/tests/       batería de pruebas y tablas de referencia
scripts/         los tres puntos de entrada
structures/      diseños de origami (.top) y sus configuraciones (.conf)
output/          estructuras y textos generados
seq2seq/         módulo experimental de la red neuronal
```

---

## El módulo seq2seq

La capa 2 nació como una red seq2seq con atención que aprendía la
transformación de 4 a 8 nucleótidos. La tabla de entrenamiento es simplemente
**concatenar el complemento**, una función determinista, total y biyectiva
sobre los 256 codones posibles.

Por eso el pipeline de producción usa `expandCodons`, que la calcula de forma
exacta e instantánea, y la red queda en `seq2seq/` como experimento
reproducible, con su partición, sus hiperparámetros, sus pesos entrenados y
sus métricas documentados.

[`seq2seq/README.md`](seq2seq/README.md) es la ficha completa del modelo.

---

## Limitaciones conocidas

**No se evalua si las estructuras generadas son sintetizables.** Al sobrescribir
los staples con datos arbitrarios, estos dejan de ser  totalmente complementarios al
scaffold. El archivo resultante es válido como topología y el texto se
recupera sin pérdida, pero el diseño no evaluo su plegamiento en laboratorio. 
Es una demostración de capacidad de almacenamiento, no un protocolo experimental.

**No hay corrección de errores.** Si un nucleótido del mensaje cambia, el
carácter correspondiente se pierde o se convierte en otro. Y no hay nada que
mantenga el marco de lectura: una sola inserción o eliminación desplaza todos
los codones posteriores y destruye el resto del mensaje.

La capa 2 no remedia esto. Su redundancia permite *detectar* bloques dañados
con `verifyExpansion`, pero no corregirlos ni resincronizar el marco. Un
esquema con corrección de errores o con codones autosincronizantes sería
trabajo futuro, no algo que este codec ya haga.

**El alfabeto es CP437, no Unicode.** Son 224 símbolos. Caracteres como `—`,
`€` o cualquier emoji no tienen codón asignado.

**La detección del mensaje asume que empieza al principio de los staples.** Si
el marcador inicial aparece más adelante, el script lo usa igual pero emite un
aviso, porque podría tratarse de una coincidencia con el diseño original.

---

## Licencia

MIT. Ver [LICENSE](LICENSE).
