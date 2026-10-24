% ENCODETOSTRUCTURE  Pipeline completo de codificación.
%
%     1. Pide un archivo de texto.
%     2. Lo codifica a nucleótidos (4 nt por carácter).
%     3. Muestra el catálogo de estructuras y su capacidad, y deja elegir.
%     4. Enmarca el mensaje entre el marcador inicial y el final, e
%        inserta solo esos nucleótidos en la región de staples, dejando el
%        resto del diseño sin tocar.
%     5. Guarda la estructura resultante en output/, junto con una copia del
%        .conf de la estructura original si existe, para poder abrir el
%        resultado directamente en oxView.
%     6. Pregunta si se quiere aplicar además la capa 2 (8 nt por carácter)
%        y, en ese caso, guarda también esa versión.
%
%   Uso:
%       >> startup
%       >> encodeToStructure

clear variables

fprintf('\n===============================================\n');
fprintf('  Codificación de texto en DNA origami\n');
fprintf('===============================================\n');

%% 1. Archivo de texto de entrada
[txtName, txtPath] = uigetfile({'*.txt', 'Archivos de texto (*.txt)'; ...
                                '*.*',   'Todos los archivos'}, ...
                                'Selecciona el archivo de texto a codificar');
if isequal(txtName, 0)
    fprintf('\nSelección cancelada.\n');
    return
end

sourceFile = fullfile(txtPath, txtName);
rawText = fileread(sourceFile);

fprintf('\nArchivo: %s\n', txtName);
fprintf('Caracteres leídos: %d\n', numel(rawText));

%% 2. Codificación (capa 1)
[payload1, report1] = buildPayload(rawText, false);

if ~isempty(report1.dropped)
    unsupported = unique(report1.dropped);
    fprintf('\nAviso: %d caracteres no están en el alfabeto y se omitirán.\n', ...
        numel(report1.dropped));
    fprintf('Caracteres afectados: ');
    fprintf('U+%04X ', double(unsupported));
    fprintf('\n');
    if ~askYesNo('Continuar de todos modos?', true)
        fprintf('\nProceso cancelado.\n');
        return
    end
end

fprintf('\nCaracteres codificados: %d\n', report1.nChars);
fprintf('Nucleótidos necesarios (capa 1): %d\n', report1.nNucleotides);

%% 3. Elección de estructura
structures = listStructures();
selection = chooseStructure(structures, report1.nChars, false);

if isempty(selection)
    fprintf('\nProceso cancelado.\n');
    return
end

top = readTopology(selection.filename);
info = topologyInfo(top);

fprintf('\nEstructura: %s\n', selection.name);
fprintf('  Nucleótidos totales : %d en %d hebras\n', info.nNucleotides, info.nStrands);
fprintf('  Scaffold (hebra 1)  : %d nt\n', info.nScaffold);
fprintf('  Staples (hebras 2+) : %d nt, a partir del nucleótido %d\n', ...
    info.nStaples, info.firstStaple);

%% 4. Inserción
[newTop, stats] = embedPayload(top, payload1);

fprintf('\nInserción realizada:\n');
fprintf('  Nucleótidos escritos  : %d (%.1f%% de la región de staples)\n', ...
    stats.nWritten, 100 * stats.occupancy);
fprintf('  Bases que cambiaron   : %d\n', stats.nChanged);
fprintf('  Staples sin modificar : %d\n', stats.nUntouched);

%% 5. Guardado
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outName = sprintf('%s_%s_capa1.top', selection.name, stamp);
outFile = fullfile(outputFolder(), outName);
writeTopology(newTop, outFile);

fprintf('\nEstructura guardada en:\n  %s\n', outFile);

confFile = copyConfiguration(selection.filename, outFile);
if ~isempty(confFile)
    fprintf('Configuración copiada en:\n  %s\n', confFile);
end

chainFile = fullfile(outputFolder(), sprintf('%s_%s_capa1.seq', selection.name, stamp));
writeChain(chainFile, payload1, struct( ...
    'estructura', selection.name, ...
    'capa',       1, ...
    'metodo',     'codebook', ...
    'caracteres', report1.nChars));
fprintf('Cadena guardada en:\n  %s\n', chainFile);

%% 6. Capa 2 opcional
fprintf('\n-----------------------------------------------\n');
fprintf('La capa 2 expande cada codón de 4 nt a 8 nt añadiendo\n');
fprintf('su complemento. Duplica el tamaño del mensaje.\n');

if ~askYesNo('Aplicar también la capa 2?', false)
    fprintf('\nListo. Para recuperar el texto, ejecuta decodeFromStructure.\n\n');
    return
end

% La transformación exacta y la red entrenada calculan la misma función. La
% red solo está disponible si ya se entrenó, y conviene saber en qué se
% diferencian, así que se ofrece elegir y se comparan los dos resultados.
weightsFile = fullfile(projectRoot(), 'seq2seq', 'model', 'seq2seqWeights.mat');
useNetwork = false;

if exist(weightsFile, 'file') == 2
    fprintf('\nHay un modelo seq2seq entrenado disponible.\n');
    useNetwork = askYesNo('Usar la red en vez de la transformación exacta?', false);
end

[payload2, report2] = buildPayload(rawText, true);
metodo = 'expandCodons';

if useNetwork
    addpath(genpath(fullfile(projectRoot(), 'seq2seq')));
    cb = dnaCodebook();
    nt1 = encodeText(rawText);

    fprintf('\nTraduciendo con la red...\n');
    cuerpoRed = char(seq2seqTranslate(nt1, weightsFile));
    payloadRed = [expandCodons(cb.startMarker) cuerpoRed expandCodons(cb.endMarker)];

    n = min(numel(payload2), numel(payloadRed));
    diferencias = sum(payload2(1:n) ~= payloadRed(1:n)) + abs(numel(payload2) - numel(payloadRed));

    fprintf('Diferencias frente a la transformación exacta: %d de %d nt (%.4f%%)\n', ...
        diferencias, numel(payload2), 100 * diferencias / max(1, numel(payload2)));
    if diferencias > 0
        fprintf(['Aviso: la red no reprodujo la transformación exactamente.\n' ...
                 'Los caracteres afectados se perderán al decodificar, salvo\n' ...
                 'que el error caiga en la mitad complementaria del bloque.\n']);
    end

    payload2 = payloadRed;
    report2.nNucleotides = numel(payload2);
    metodo = 'seq2seq';
end

fprintf('\nNucleótidos necesarios (capa 2): %d\n', report2.nNucleotides);

seqFile = fullfile(outputFolder(), ...
    sprintf('%s_%s_capa2_%s.seq', selection.name, stamp, metodo));
writeChain(seqFile, payload2, struct( ...
    'estructura', selection.name, ...
    'capa',       2, ...
    'metodo',     metodo, ...
    'caracteres', report2.nChars));
fprintf('Cadena de capa 2 guardada en:\n  %s\n', seqFile);

if report2.nNucleotides > info.nStaples
    fprintf(['\nLa versión de capa 2 ocupa %d nt y "%s" solo tiene %d nt de ' ...
             'staples, así que no se inserta.\n'], ...
        report2.nNucleotides, selection.name, info.nStaples);
    fprintf(['La cadena queda guardada igualmente y se puede decodificar con\n' ...
             'decodeChain.\n\nListo.\n\n']);
    return
end

[newTop2, stats2] = embedPayload(top, payload2);

outName2 = sprintf('%s_%s_capa2.top', selection.name, stamp);
outFile2 = fullfile(outputFolder(), outName2);
writeTopology(newTop2, outFile2);

fprintf('\nInserción de capa 2 realizada:\n');
fprintf('  Nucleótidos escritos  : %d (%.1f%% de la región de staples)\n', ...
    stats2.nWritten, 100 * stats2.occupancy);
fprintf('  Staples sin modificar : %d\n', stats2.nUntouched);
fprintf('\nEstructura guardada en:\n  %s\n', outFile2);

confFile2 = copyConfiguration(selection.filename, outFile2);
if ~isempty(confFile2)
    fprintf('Configuración copiada en:\n  %s\n', confFile2);
end

fprintf('\nListo. Para recuperar el texto, ejecuta decodeFromStructure.\n\n');
