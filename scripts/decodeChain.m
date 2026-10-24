% DECODECHAIN  Decodifica una cadena de nucleótidos guardada en un archivo.
%
%   Complementa a decodeFromStructure, que parte de un archivo .top. Este
%   script parte de una cadena suelta, que es lo que generan:
%
%     - encodeToStructure, que guarda la cadena de capa 1 y la de capa 2
%       en output/*.seq cada vez que codifica
%     - decodeFromStructure, que guarda la cadena extraída de la estructura
%     - la red seq2seq, cuando se elige para la capa 2
%
%   Sirve, para decodificar una cadena producida por la red y
%   verla al lado de la que produce la transformación exacta.
%
%   Detecta sola si la cadena es de capa 1 o de capa 2 comprobando la
%   relación bloque/complemento, y permite simular errores de síntesis
%   igual que decodeFromStructure.
%
%   Uso:
%       >> startup
%       >> decodeChain

clear variables

fprintf('\n===============================================\n');
fprintf('  Decodificación de una cadena de nucleótidos\n');
fprintf('===============================================\n');

%% 1. Archivo
[chainName, chainPath] = uigetfile( ...
    {'*.seq;*.txt', 'Cadenas de nucleótidos (*.seq, *.txt)'; '*.*', 'Todos'}, ...
    'Selecciona la cadena a decodificar', [outputFolder() filesep]);

if isequal(chainName, 0)
    fprintf('\nSelección cancelada.\n');
    return
end

chainFile = fullfile(chainPath, chainName);
[chain, metadata] = readChain(chainFile);

fprintf('\nArchivo  : %s\n', chainName);
fprintf('Longitud : %d nt\n', numel(chain));

campos = fieldnames(metadata);
if ~isempty(campos)
    fprintf('Cabecera :\n');
    for k = 1:numel(campos)
        fprintf('  %-12s %s\n', [campos{k} ':'], metadata.(campos{k}));
    end
end

%% 2. Capa
cb = dnaCodebook();

if numel(chain) >= numel(cb.startMarker) && ...
        strncmp(chain, cb.startMarker, numel(cb.startMarker))
    chain = chain(numel(cb.startMarker) + 1:end);
    fin = strfind(chain, cb.endMarker);
    if ~isempty(fin)
        chain = chain(1:fin(1) - 1);
    end
    fprintf('\nSe encontraron los marcadores de capa 1 y se retiraron.\n');
elseif numel(chain) >= numel(expandCodons(cb.startMarker)) && ...
        strncmp(chain, expandCodons(cb.startMarker), numel(expandCodons(cb.startMarker)))
    marcadorInicio = expandCodons(cb.startMarker);
    marcadorFin    = expandCodons(cb.endMarker);
    chain = chain(numel(marcadorInicio) + 1:end);
    fin = strfind(chain, marcadorFin);
    if ~isempty(fin)
        chain = chain(1:fin(1) - 1);
    end
    fprintf('\nSe encontraron los marcadores de capa 2 y se retiraron.\n');
end

esCapa2 = isExpanded(chain, 2);

fprintf('Capa detectada: %d', 1 + esCapa2);
if esCapa2
    fprintf(' (cumple la relación bloque/complemento)\n');
else
    fprintf('\n');
end

if askYesNo('Forzar la otra capa?', false)
    esCapa2 = ~esCapa2;
    fprintf('  Se leerá como capa %d.\n', 1 + esCapa2);
end

if esCapa2
    body = collapseCodons(chain);
else
    body = chain;
end

%% 3. Decodificación
[text, unknown] = decodeText(body, '?');

fprintf('\nCaracteres recuperados : %d\n', numel(text));
if unknown > 0
    fprintf('Codones sin símbolo    : %d (aparecen como "?" en el texto)\n', unknown);
end

fprintf('\n--- Texto recuperado ---------------------------\n');
fprintf('%s\n', text);
fprintf('------------------------------------------------\n');

%% 4. Simulación de errores de síntesis
noise = askNoiseSettings();

if ~isempty(noise)
    [noisyChain, noiseReport] = injectNoise(chain, ...
        'Substitution', noise.Substitution, ...
        'Deletion',     noise.Deletion, ...
        'Insertion',    noise.Insertion, ...
        'Seed',         noise.Seed);

    if esCapa2
        noisyBody = collapseCodons(noisyChain);
    else
        noisyBody = noisyChain;
    end

    noisyText = decodeText(noisyBody, '?');
    noiseImpactReport(text, noisyText, noiseReport);

    if esCapa2
        [~, check] = verifyExpansion(noisyChain);
        fprintf('\nBloques inconsistentes (detectables): %d de %d (%.2f%%)\n', ...
            check.nInconsistent, check.nBlocks, ...
            100 * check.nInconsistent / max(1, check.nBlocks));
    end

    fprintf('\n--- Texto tras el ruido ------------------------\n');
    fprintf('%s\n', noisyText);
    fprintf('------------------------------------------------\n');
end

%% 5. Guardado
[~, stem] = fileparts(chainName);
outFile = fullfile(outputFolder(), [stem '_decodificado.txt']);

fid = fopen(outFile, 'w');
if fid < 0
    warning('decodeChain:cannotWrite', 'No se pudo guardar en "%s".', outFile);
else
    fprintf(fid, '%s', text);
    fclose(fid);
    fprintf('\nTexto guardado en:\n  %s\n\n', outFile);
end
