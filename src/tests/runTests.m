function results = runTests()
%RUNTESTS  Batería de pruebas del pipeline de almacenamiento en DNA origami.
%
%   runTests() ejecuta todas las comprobaciones y muestra un resumen.
%   results = runTests() devuelve además una tabla con el detalle.
%
%   Cubre:
%     - integridad del codebook
%     - compatibilidad con las tablas originales del proyecto
%     - ida y vuelta de la capa 1 y de la capa 2
%     - lectura y escritura de topologías sin pérdida
%     - inserción y extracción sobre una estructura real
%     - que el scaffold y los staples no utilizados queden intactos
%     - detección automática de capa, incluido el caso ambiguo
%     - límites de capacidad
%
%   Uso:
%       >> startup
%       >> runTests

state = struct('name', {}, 'passed', {}, 'detail', {});

fprintf('\n===============================================\n');
fprintf('  Pruebas del pipeline DNA origami storage\n');
fprintf('===============================================\n');

state = section(state, 'Codebook');
state = checkCodebook(state);

state = section(state, 'Compatibilidad con las tablas originales');
state = checkLegacy(state);

state = section(state, 'Capa 1');
state = checkLayer1(state);

state = section(state, 'Capa 2');
state = checkLayer2(state);

state = section(state, 'Distancia de edición');
state = checkLevenshtein(state);

state = section(state, 'Simulación de errores');
state = checkNoise(state);

files = allStructures();
if isempty(files)
    state = section(state, 'Estructuras');
    state = check(state, 'hay al menos una estructura en structures/', false, ...
        'no se encontró ningún archivo .top');
else
    for k = 1:numel(files)
        [~, stem] = fileparts(files{k});

        state = section(state, ['Topología: ' stem]);
        state = checkTopology(state, files{k}, stem);

        state = section(state, ['Inserción y extracción: ' stem]);
        state = checkRoundTrip(state, files{k}, stem);
    end
end

summary = struct2table(state);

nPassed = sum([state.passed]);
nTotal  = numel(state);

fprintf('\n===============================================\n');
if nPassed == nTotal
    fprintf('  TODO CORRECTO: %d de %d pruebas\n', nPassed, nTotal);
else
    fprintf('  FALLOS: %d de %d pruebas no pasaron\n', nTotal - nPassed, nTotal);
    failed = summary(~summary.passed, :);
    for k = 1:height(failed)
        fprintf('    - %s: %s\n', failed.name{k}, failed.detail{k});
    end
end
fprintf('===============================================\n\n');

if nargout > 0
    results = summary;
end
end

function state = section(state, sectionName)
fprintf('\n--- %s\n', sectionName);
end

function state = check(state, name, condition, detail)
if nargin < 4
    detail = '';
end
passed = logical(condition);

if passed
    fprintf('  [ok]   %s\n', name);
else
    fprintf('  [FALLO] %s   %s\n', name, detail);
end

state(end + 1) = struct('name', name, 'passed', passed, 'detail', detail); %#ok<AGROW>
end

function state = checkCodebook(state)
cb = dnaCodebook();

state = check(state, 'hay 224 símbolos', cb.nSymbols == 224, ...
    sprintf('son %d', cb.nSymbols));
state = check(state, 'los code points no se repiten', ...
    numel(unique(cb.codePoints)) == cb.nSymbols);
state = check(state, 'los codones no se repiten', ...
    size(unique(cb.codons, 'rows'), 1) == cb.nSymbols);
state = check(state, 'todos los codones son ACGT de 4 nt', ...
    size(cb.codons, 2) == 4 && all(ismember(cb.codons(:), 'ACGT')));

state = check(state, 'los marcadores miden dos codones', ...
    numel(cb.startMarker) == 8 && numel(cb.endMarker) == 8);
state = check(state, 'los dos marcadores son distintos', ...
    ~strcmp(cb.startMarker, cb.endMarker));

markerCodons = unique([ ...
    reshape(cb.startMarker, 4, []).'; ...
    reshape(cb.endMarker,   4, []).'], 'rows');

reserved = true;
for k = 1:size(markerCodons, 1)
    if any(all(cb.codons == repmat(markerCodons(k, :), cb.nSymbols, 1), 2))
        reserved = false;
    end
end
state = check(state, 'los codones de los marcadores están reservados', reserved);

extras = [double(''''), 10, 13, 9];
state = check(state, 'apóstrofo, salto de línea, retorno y tabulador incluidos', ...
    all(ismember(extras, cb.codePoints)));
end

function state = checkLegacy(state)
dataDir = fullfile(fileparts(mfilename('fullpath')), 'data');

legacy = readtable(fullfile(dataDir, 'legacy_codebook220.csv'), ...
    'TextType', 'char');
cb = dnaCodebook();

sameOrder = isequal(cb.codePoints(1:height(legacy)), legacy.codePoint.');
state = check(state, 'los 220 símbolos originales conservan su orden', sameOrder);

sameCodons = isequal(cb.codons(1:height(legacy), :), char(legacy.codon));
state = check(state, 'los 220 símbolos originales conservan su codón', sameCodons);

legacyMap = readtable(fullfile(dataDir, 'legacy_map4to8.csv'), 'TextType', 'char');

mismatch = {};
for k = 1:height(legacyMap)
    produced = expandCodons(legacyMap.codon4{k});
    if ~strcmp(produced, legacyMap.codon8{k})
        mismatch{end + 1} = legacyMap.codon4{k}; %#ok<AGROW>
    end
end

state = check(state, 'expandCodons reproduce el mapa original salvo 2 erratas', ...
    numel(mismatch) == 2, sprintf('%d discrepancias', numel(mismatch)));
state = check(state, 'las erratas conocidas son GATT y GCTT', ...
    isequal(sort(mismatch), {'GATT', 'GCTT'}), strjoin(mismatch, ', '));
end

function state = checkLayer1(state)
text = ['Hola, mundo! Niños y ' char(241) 'andu - 123 ABC xyz ' ...
        char(39) char(39) ' ' char(10) char(9) 'fin.'];

[nt, dropped] = encodeText(text);

state = check(state, 'ningún carácter del texto de prueba se descarta', ...
    isempty(dropped), ['descartados: ' dropped]);
state = check(state, '4 nucleótidos por carácter', ...
    numel(nt) == 4 * numel(text), sprintf('%d vs %d', numel(nt), 4 * numel(text)));
state = check(state, 'ida y vuelta exacta', strcmp(decodeText(nt), text));

[~, dropped2] = encodeText(['ok' char(8212) 'ok' char(8364)]);
state = check(state, 'los caracteres no soportados se reportan', ...
    numel(dropped2) == 2, sprintf('%d reportados', numel(dropped2)));

state = check(state, 'texto vacío no falla', isempty(encodeText('')));
state = check(state, 'decodificar vacío no falla', isempty(decodeText('')));

threw = false;
try
    [partial, unknownCount] = decodeText(['GTAC' '    ' 'AAAC']);
catch
    threw = true;
    partial = '';
    unknownCount = -1;
end
state = check(state, 'decodificar bases inválidas no aborta', ~threw);
state = check(state, 'los codones inválidos se cuentan como desconocidos', ...
    ~threw && unknownCount == 1, sprintf('%d desconocidos', unknownCount));
state = check(state, 'los codones válidos alrededor sí se decodifican', ...
    ~threw && numel(partial) == 2, sprintf('%d caracteres', numel(partial)));
end

function state = checkLayer2(state)
nt = encodeText('Prueba de la capa 2');
expanded = expandCodons(nt);

state = check(state, 'la expansión duplica la longitud', ...
    numel(expanded) == 2 * numel(nt));
state = check(state, 'collapseCodons invierte expandCodons', ...
    strcmp(collapseCodons(expanded), nt));
state = check(state, 'isExpanded reconoce la capa 2', isExpanded(expanded));
state = check(state, 'isExpanded rechaza la capa 1', ~isExpanded(nt));
state = check(state, 'la regla del complemento es correcta', ...
    strcmp(expandCodons('GTAC'), 'GTACCATG'));
state = check(state, 'complementNt no invierte el orden', ...
    strcmp(complementNt('GTAC'), 'CATG'));

bases = 'ACGT';
allOk = true;
for a = 1:4
    for b = 1:4
        for c = 1:4
            for d = 1:4
                codon = [bases(a) bases(b) bases(c) bases(d)];
                if ~strcmp(collapseCodons(expandCodons(codon)), codon)
                    allOk = false;
                end
            end
        end
    end
end
state = check(state, 'la capa 2 es biyectiva en los 256 codones', allOk);
end

function state = checkLevenshtein(state)
state = check(state, 'cadenas iguales dan distancia 0', ...
    levenshtein('ACGT', 'ACGT') == 0);
state = check(state, 'una sustitución da distancia 1', ...
    levenshtein('ACGT', 'ACGA') == 1);
state = check(state, 'una eliminación da distancia 1', ...
    levenshtein('ACGT', 'ACG') == 1);
state = check(state, 'una inserción da distancia 1', ...
    levenshtein('ACGT', 'ACGTT') == 1);
state = check(state, 'caso clásico kitten/sitting = 3', ...
    levenshtein('kitten', 'sitting') == 3);
state = check(state, 'contra cadena vacía es la longitud', ...
    levenshtein('ACGT', '') == 4);
state = check(state, 'es simétrica', ...
    levenshtein('ACGTACG', 'TTGCA') == levenshtein('TTGCA', 'ACGTACG'));

[~, sim] = levenshtein('ACGT', 'ACGT');
state = check(state, 'similitud de cadenas iguales es 100%', abs(sim - 100) < 1e-9);
end

function state = checkNoise(state)
base = repmat('ACGT', 1, 100); 

[same, rep0] = injectNoise(base);
state = check(state, 'sin tasas no se altera nada', ...
    strcmp(same, base) && rep0.totalErrors == 0);

[noisy, rep] = injectNoise(base, 'Substitution', 0.05, 'Seed', 1);
state = check(state, 'se aplican exactamente las sustituciones pedidas', ...
    rep.substitutions == 20, sprintf('%d de 20', rep.substitutions));
state = check(state, 'la sustitución no cambia la longitud', ...
    numel(noisy) == numel(base));
state = check(state, 'la sustitución cambia realmente las bases', ...
    sum(noisy ~= base) == 20, sprintf('%d posiciones', sum(noisy ~= base)));
state = check(state, 'la salida sigue siendo ACGT', all(ismember(noisy, 'ACGT')));

[shorter, repDel] = injectNoise(base, 'Deletion', 0.01, 'Seed', 1);
state = check(state, 'la eliminación acorta la cadena', ...
    numel(shorter) == numel(base) - repDel.deletions && repDel.deletions == 4);

[longer, repIns] = injectNoise(base, 'Insertion', 0.01, 'Seed', 1);
state = check(state, 'la inserción alarga la cadena', ...
    numel(longer) == numel(base) + repIns.insertions && repIns.insertions == 4);

[~, repMix] = injectNoise(base, 'Substitution', 0.05, 'Deletion', 0.02, ...
    'Insertion', 0.02, 'Seed', 3);
state = check(state, 'los tres tipos de error son independientes', ...
    repMix.substitutions == 20 && repMix.deletions == 8 && repMix.insertions == 8, ...
    sprintf('%d/%d/%d', repMix.substitutions, repMix.deletions, repMix.insertions));

a = injectNoise(base, 'Substitution', 0.1, 'Seed', 7);
b = injectNoise(base, 'Substitution', 0.1, 'Seed', 7);
c = injectNoise(base, 'Substitution', 0.1, 'Seed', 8);
state = check(state, 'misma semilla da el mismo resultado', isequal(a, b));
state = check(state, 'semillas distintas dan resultados distintos', ~isequal(a, c));

limpio = expandCodons(encodeText('Prueba de detección por redundancia'));
[okBlocks, checkClean] = verifyExpansion(limpio);
state = check(state, 'una cadena de capa 2 intacta es consistente', ...
    all(okBlocks) && checkClean.nInconsistent == 0);

danada = injectNoise(limpio, 'Substitution', 0.02, 'Seed', 5);
[~, checkNoisy] = verifyExpansion(danada);
state = check(state, 'la redundancia detecta bloques dañados', ...
    checkNoisy.nInconsistent > 0, ...
    sprintf('%d detectados', checkNoisy.nInconsistent));

conMarcador = decodeText(['GTAC' 'GGGG' 'AAAC'], '?');
state = check(state, 'el marcador conserva la alineación', ...
    numel(conMarcador) == 3 && conMarcador(2) == '?', ...
    sprintf('"%s"', conMarcador));
end

function state = checkTopology(state, file, stem)
top = readTopology(file);
cb = dnaCodebook();

info0 = topologyInfo(top);
fprintf('      %s: %d nt, %d hebras, %d de scaffold, %d de staples\n', ...
    stem, info0.nNucleotides, info0.nStrands, info0.nScaffold, info0.nStaples);
fprintf('      capacidad: %d caracteres en capa 1, %d en capa 2\n', ...
    info0.capacityLayer1, info0.capacityLayer2);

state = check(state, 'la cabecera cuadra con el número de filas', ...
    numel(top.strand) == top.nNucleotides);
state = check(state, 'la cabecera cuadra con el número de hebras', ...
    max(top.strand) == top.nStrands);
state = check(state, 'todas las bases son ACGT', all(ismember(top.base, 'ACGT')));

idx = stapleIndices(top);
state = check(state, 'la hebra 1 es el scaffold y no entra en los staples', ...
    all(top.strand(idx) >= 2));
state = check(state, 'los staples empiezan donde acaba el scaffold', ...
    idx(1) == sum(top.strand == 1) + 1);

tmp = [tempname '.top'];
cleaner = onCleanup(@() deleteIfExists(tmp)); %#ok<NASGU>
writeTopology(top, tmp);
reread = readTopology(tmp);

state = check(state, 'escribir y releer conserva las hebras', ...
    isequal(top.strand, reread.strand));
state = check(state, 'escribir y releer conserva las bases', ...
    isequal(top.base, reread.base));
state = check(state, 'escribir y releer conserva los vecinos 3 y 5', ...
    isequal(top.neighbor3, reread.neighbor3) && isequal(top.neighbor5, reread.neighbor5));

nStart = numel(strfind(top.base(:).', cb.startMarker));
nEnd   = numel(strfind(top.base(:).', cb.endMarker));
state = check(state, 'el marcador inicial no aparece en el diseño original', ...
    nStart == 0, sprintf('%d apariciones', nStart));
state = check(state, 'el marcador final no aparece en el diseño original', ...
    nEnd == 0, sprintf('%d apariciones', nEnd));

nMarkerCodons = (numel(cb.startMarker) + numel(cb.endMarker)) / 4;

info = topologyInfo(top);
state = check(state, 'la capacidad de capa 1 cuadra con los staples', ...
    info.capacityLayer1 == floor(info.nStaples / 4) - nMarkerCodons, ...
    sprintf('%d vs %d', info.capacityLayer1, floor(info.nStaples / 4) - nMarkerCodons));
state = check(state, 'la capacidad de capa 2 es la mitad', ...
    info.capacityLayer2 == floor(info.nStaples / 8) - nMarkerCodons, ...
    sprintf('%d vs %d', info.capacityLayer2, floor(info.nStaples / 8) - nMarkerCodons));
end

function state = checkRoundTrip(state, file, stem) %#ok<INUSD>
top = readTopology(file);
cb = dnaCodebook();

message = ['Prueba de almacenamiento.' char(10) ...
           'Segunda línea con apóstrofo: it' char(39) 's listo.' char(9) 'Tab.' char(10) ...
           'Acentos: ' char([225 233 237 243 250 241]) ' y n' char(250) 'meros 0123456789'];

[payload, report] = buildPayload(message, false);
state = check(state, 'el mensaje de prueba se codifica entero', ...
    isempty(report.dropped), ['descartados: ' report.dropped]);
state = check(state, 'el payload empieza por el marcador inicial', ...
    strncmp(payload, cb.startMarker, numel(cb.startMarker)));
state = check(state, 'el payload acaba con el marcador final', ...
    strcmp(payload(end - numel(cb.endMarker) + 1:end), cb.endMarker));

[newTop, stats] = embedPayload(top, payload);
state = check(state, 'se escriben exactamente los nt del payload', ...
    stats.nWritten == numel(payload));

idx = stapleIndices(top);
untouched = idx(numel(payload) + 1:end);
state = check(state, 'los staples sobrantes conservan su base original', ...
    isequal(top.base(untouched), newTop.base(untouched)));

scaffold = find(top.strand == 1);
state = check(state, 'el scaffold queda intacto', ...
    isequal(top.base(scaffold), newTop.base(scaffold)));
state = check(state, 'las columnas de hebra y vecinos quedan intactas', ...
    isequal(top.strand, newTop.strand) && ...
    isequal(top.neighbor3, newTop.neighbor3) && ...
    isequal(top.neighbor5, newTop.neighbor5));

[recovered, rep] = extractPayload(newTop);
state = check(state, 'el texto se recupera identico (capa 1)', ...
    strcmp(recovered, message));
state = check(state, 'se detecta la capa 1', ~rep.useLayer2);

payload2 = buildPayload(message, true);
state = check(state, 'la capa 2 ocupa el doble', ...
    numel(payload2) == 2 * numel(payload));

newTop2 = embedPayload(top, payload2);
[recovered2, rep2] = extractPayload(newTop2);
state = check(state, 'el texto se recupera identico (capa 2)', ...
    strcmp(recovered2, message));
state = check(state, 'se detecta la capa 2', rep2.useLayer2);

expandedStart = expandCodons(cb.startMarker);
state = check(state, 'los marcadores de capa 1 y capa 2 difieren desde el inicio', ...
    ~strncmp(cb.startMarker, expandedStart, numel(cb.startMarker)));

idxCCCC = find(all(cb.codons == repmat('CCCC', cb.nSymbols, 1), 2), 1);
tricky = [char(cb.codePoints(idxCCCC)) 'resto del mensaje de prueba'];
trickyPayload = buildPayload(tricky, false);

trickyTop = embedPayload(top, trickyPayload);
[recovered3, rep3] = extractPayload(trickyTop);
state = check(state, 'el caso que antes era ambiguo se lee como capa 1', ~rep3.useLayer2);
state = check(state, 'el caso que antes era ambiguo se recupera identico', ...
    strcmp(recovered3, tricky));

info = topologyInfo(top);
big = repmat('a', 1, info.capacityLayer1);
bigPayload = buildPayload(big, false);
state = check(state, 'el mensaje máximo llena justo la región de staples', ...
    numel(bigPayload) <= info.nStaples && ...
    numel(bigPayload) > info.nStaples - 4, sprintf('%d de %d nt', ...
    numel(bigPayload), info.nStaples));

bigTop = embedPayload(top, bigPayload);
state = check(state, 'ida y vuelta a capacidad máxima', ...
    strcmp(extractPayload(bigTop), big));

threw = false;
try
    embedPayload(top, repmat('A', 1, info.nStaples + 1));
catch
    threw = true;
end
state = check(state, 'se rechaza un mensaje que no cabe', threw);

[threw, warned] = runGuarded(@() extractPayload(top));
state = check(state, 'una estructura sin mensaje da un error claro', threw);
state = check(state, 'una estructura sin mensaje no genera avisos', ~warned);

[threwScan, ~] = runGuarded(@() extractPayload(top, [], true));
state = check(state, 'ni recorriendo toda la región aparece un mensaje falso', threwScan);
end

function files = allStructures()
list = dir(fullfile(projectRoot(), 'structures', '*.top'));
list = list(~[list.isdir]);

files = cell(numel(list), 1);
for k = 1:numel(list)
    files{k} = fullfile(list(k).folder, list(k).name);
end
end

function [threw, warned] = runGuarded(fn)
lastwarn('');

threw = false;
try
    fn();
catch
    threw = true;
end

warned = ~isempty(lastwarn());
end

function deleteIfExists(file)
if exist(file, 'file') == 2
    delete(file);
end
end
