# Modelo seq2seq: ficha, metodología y reproducción

Red codificador-decodificador LSTM con atención de Luong, entrenada para
traducir codones de 4 nucleótidos a bloques de 8.

---

## 1. La tarea

La capa 2 del pipeline convierte cada codón de 4 nucleótidos en uno de 8
añadiendo su complemento base a base:

```
GTAC  ->  GTAC CATG
AAAC  ->  AAAC TTTG
```

Es una función **determinista, total y biyectiva** sobre los 256 codones
posibles. `src/codec/expandCodons.m` la calcula en forma cerrada.

La red no aprende una relación estadística: aprende esta tabla.

---

## 2. Datos y partición

### Tamaños

| Conjunto | Pares |
|---|---:|
| 4-meros posibles | 256 |
| En la tabla publicada | 220 |
| Entrenamiento (configuración publicada) | 220 |
| Validación | 0 |
| Prueba de codones retenidos | 0 |

### Cómo medir generalización, si se quiere

```matlab
>> trainSeq2Seq('CodonSet', 'all256', 'HoldOut', 0.2, 'Seed', 0)
>> evaluateSeq2Seq
```

Retira el 20 % de los codones del entrenamiento y evalúa sobre ellos. Como
el objetivo es "concatenar el complemento", un modelo que haya aprendido la
**regla** acierta los codones retenidos; uno que haya memorizado las parejas
falla.

### Corpus de evaluación

50 documentos `.txt` en `data/pruebas/`, 73 764 caracteres en total, de
densidades y vocabularios distintos.

---

## 3. Representación de las secuencias

Cada codón se trata como una secuencia de tokens de un carácter, con
marcadores de inicio y fin:

```
'GTAC'  ->  <start> G T A C <stop>
```

El vocabulario son 4 bases más los dos marcadores, y `wordEncoding` añade un
índice de relleno: 7 entradas de entrada y 7 de salida. La tokenización está
en `model/transformText.m`.

---

## 4. Arquitectura

| Componente | Valor |
|---|---|
| Codificador | embedding + LSTM |
| Decodificador | embedding + LSTM + atención de Luong + capa densa + softmax |
| Dimensión del embedding | 128 |
| Unidades ocultas | 100 |
| Atención | producto punto escalado, una cabeza (`model/luongAttention.m`) |
| Dropout | 0.05, solo en el decodificador |
| Parámetros aprendibles | ≈ 236 000 (lo cuenta `trainSeq2Seq` y lo guarda en `info.numLearnables`) |

Inicialización: Gaussiana (σ = 0.01) para los embeddings, Glorot para las
matrices de entrada y la densa, ortogonal para las recurrentes, y sesgo de
puerta de olvido a 1.

---

## 5. Optimización

| Hiperparámetro | Valor |
|---|---|
| Optimizador | Adam |
| Tasa de aprendizaje | 0.001 |
| Decaimiento del gradiente | 0.9 |
| Decaimiento cuadrático | 0.999 |
| Épocas | 300 |
| Tamaño de minilote | 32 |
| Iteraciones por época | ⌈220/32⌉ = 7 |
| Iteraciones totales | 2 100 |
| Pérdida | entropía cruzada enmascarada sobre las posiciones válidas |
| Teacher forcing | probabilidad 0.5 por minilote |

---

## 6. Métricas

`evaluateSeq2Seq` calcula:

- **Exactitud por nucleótido** — posiciones correctas sobre el total.
- **Exact-match por secuencia** — bloques de 8 nt enteramente correctos.
- **Recuperación por carácter** — caracteres que sobreviven al viaje
  completo texto → capa 1 → red → texto.
- **Documentos recuperados enteros** — fracción de los 50 que vuelven
  idénticos.
- **Cobertura** — el desglose de la sección 2, recalculado en cada corrida.
- **Codones retenidos** — exactitud sobre entradas nunca vistas, si se
  entrenó con `HoldOut > 0`.
- **Matriz de confusión** 4 × 4, esperado frente a predicho.

---

## 7. Reproducir

```matlab
>> cd seq2seq

% Reproduce la configuración publicada
>> trainSeq2Seq
>> evaluateSeq2Seq
>> benchmarkCodecs

% Mide generalización
>> trainSeq2Seq('CodonSet', 'all256', 'HoldOut', 0.2, 'OutputFile', 'model/heldout.mat')
>> evaluateSeq2Seq('WeightsFile', 'model/heldout.mat')
```

`trainSeq2Seq` fija la semilla antes de inicializar los pesos, así que dos
corridas con los mismos ajustes dan el mismo modelo. **La versión original no
fijaba semilla**, y por eso las dos corridas que menciona el artículo
(pérdida 0.07 % y 0.028 %) no son reproducibles tal cual: diferían solo en la
inicialización aleatoria.

Cada `.mat` de pesos guarda, junto a los parámetros, un registro `info` con
los hiperparámetros, la partición, el historial de pérdida, el tiempo de
entrenamiento, la versión de MATLAB y los toolboxes.

Los resultados van a `results/` como `.csv` y `.mat`, más las dos figuras.

---

## 8. Coste frente a una tabla de búsqueda

`benchmarkCodecs` mide, sobre el mismo corpus, el tiempo de `expandCodons`
frente al de la red, el rendimiento en nucleótidos por segundo, y el tamaño
de cada representación: ~236 000 parámetros en punto flotante simple
(≈ 944 kB) frente a una tabla de 220 entradas (≈ 2.6 kB).

---

## 9. Contenido

```
seq2seqDataset.m     tablas de entrenamiento y partición
trainSeq2Seq.m       entrenamiento reproducible, guarda pesos y registro
evaluateSeq2Seq.m    todas las métricas de la sección 6
benchmarkCodecs.m    coste frente a la tabla de búsqueda
seq2seqTranslate.m   inferencia sobre una cadena
encodeWithTable.m    codificación restringida a la tabla entrenada
model/               capas, inicializadores y pesos entrenados
data/pruebas/        los 50 documentos de evaluación
results/             salidas de evaluateSeq2Seq y benchmarkCodecs
```
