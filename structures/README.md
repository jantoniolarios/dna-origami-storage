# Estructuras de DNA origami

Archivos de topología oxDNA (`.top`) y sus configuraciones (`.conf`).
Cualquier `.top` que se copie aquí aparece automáticamente en el menú de
`encodeToStructure`, con su capacidad calculada a partir del propio archivo.

## Formato

Primera línea del `.top`: número total de nucleótidos y número de hebras.
Después, una línea por nucleótido:

```
hebra  base  vecino_3'  vecino_5'
```

Un `-1` indica que el nucleótido termina la hebra en esa dirección.

Por convención del proyecto, **la hebra 1 es el scaffold** y las hebras 2 en
adelante son los staples. La información se almacena solo en los staples.

El `.conf` que acompaña a cada `.top` guarda las posiciones y orientaciones
de los nucleótidos. El pipeline no lo modifica nunca, solo cambia bases, no
geometría así que el mismo `.conf` vale para la estructura generada.
`encodeToStructure` lo copia a `output/` junto al `.top` nuevo.

## Disponibles

| Archivo | Nucleótidos | Hebras | Scaffold | Staples | Capa 1 | Capa 2 |
|---|---:|---:|---:|---:|---:|---:|
| `Cube.top` | 14 352 | 18 | 7 176 | 7 176 | 1 790 | 893 |
| `Interlock.top` | 22 378 | 83 | 11 430 | 10 948 | 2 733 | 1 364 |
| `Octagon.top` | 21 600 | 58 | 10 800 | 10 800 | 2 696 | 1 346 |
| `Steward.top` | 14 037 | 77 | 7 167 | 6 870 | 1 713 | 854 |

Las columnas de capa 1 y capa 2 son caracteres almacenables, ya descontados
los cuatro codones de los marcadores.
