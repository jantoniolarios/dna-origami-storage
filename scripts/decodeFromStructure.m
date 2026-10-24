% DECODEFROMSTRUCTURE  Recupera el texto almacenado en una estructura .top.
%
%   Uso:
%       >> startup
%       >> decodeFromStructure

clear variables

fprintf('\n===============================================\n');
fprintf('  Decodificación de DNA origami\n');
fprintf('===============================================\n');

%% 1. Archivo de topología
[topName, topPath] = uigetfile({'*.top', 'Topología oxDNA (*.top)'}, ...
    'Selecciona la estructura con la información codificada', ...
    [outputFolder() filesep]);

if isequal(topName, 0)
    fprintf('\nSelección cancelada.\n');
    return
end

topFile = fullfile(topPath, topName);

fprintf('\nArchivo: %s\n', topName);

timer = tic;
top = readTopology(topFile);
info = topologyInfo(top);

fprintf('  Nucleótidos totales : %d en %d hebras\n', info.nNucleotides, info.nStrands);
fprintf('  Staples (hebras 2+) : %d nt, a partir del nucleótido %d\n', ...
    info.nStaples, info.firstStaple);

%% 2. Capa de codificación
fprintf('\nLa capa de codificación se detecta sola. ');
if askYesNo('Quieres forzarla manualmente?', false)
    if askYesNo('  Se uso la capa 2 (8 nt por carácter)?', false)
        forceLayer = true;
    else
        forceLayer = false;
    end
else
    forceLayer = [];
end

%% 3. Extracción
try
    [text, report] = extractPayload(top, forceLayer);
catch err
    fprintf('\nNo se pudo recuperar el mensaje.\n  %s\n\n', err.message);
    return
end

if report.detected
    origin = 'detectada automáticamente';
else
    origin = 'impuesta por el usuario';
end

fprintf('\nMensaje localizado:\n');
fprintf('  Capa                 : %d (%s)\n', 1 + report.useLayer2, origin);
fprintf('  Inicio en la región  : nucleótido %d\n', report.startOffset);
fprintf('  Nucleótidos de datos : %d\n', report.nNucleotides);
fprintf('  Caracteres           : %d\n', report.nChars);

if report.unknownCodons > 0
    fprintf(['  Aviso: %d codones no corresponden a ningún símbolo y se ' ...
             'omitieron.\n'], report.unknownCodons);
end

%% 4. Resultado
fprintf('\n--- Texto recuperado ---------------------------\n');
fprintf('%s\n', text);
fprintf('------------------------------------------------\n');

%% 5. Simulación de errores de síntesis
noise = askNoiseSettings();
noisyText = '';
impact = [];

if ~isempty(noise)
    [noisyChain, noiseReport] = injectNoise(report.rawBody, ...
        'Substitution', noise.Substitution, ...
        'Deletion',     noise.Deletion, ...
        'Insertion',    noise.Insertion, ...
        'Seed',         noise.Seed);

    if report.useLayer2
        noisyBody = collapseCodons(noisyChain);
    else
        noisyBody = noisyChain;
    end

    noisyText = decodeText(noisyBody, '?');

    impact = noiseImpactReport(text, noisyText, noiseReport);

    fprintf('\n--- Texto tras el ruido ------------------------\n');
    fprintf('%s\n', noisyText);
    fprintf('------------------------------------------------\n');

    if report.useLayer2
        [~, check] = verifyExpansion(noisyChain);
        fprintf(['\nLa capa 2 escribe cada codón seguido de su complemento, y\n' ...
                 'collapseCodons descarta esa segunda mitad sin mirarla. Esa\n' ...
                 'redundancia no corrige nada, pero sí permite detectar:\n']);
        fprintf('  bloques inconsistentes: %d de %d (%.2f%%)\n', ...
            check.nInconsistent, check.nBlocks, ...
            100 * check.nInconsistent / max(1, check.nBlocks));
        fprintf(['  Son los bloques donde la segunda mitad no es el\n' ...
                 '  complemento de la primera, es decir, los sospechosos.\n']);
        fprintf(['\nOjo: la capa 2 NO hace el mensaje más robusto. A igual tasa\n' ...
                 'de error por nucleótido tiene el doble de nucleótidos y por\n' ...
                 'tanto el doble de errores; la mitad cae en la parte\n' ...
                 'redundante, así que la exactitud final es parecida a la de\n' ...
                 'la capa 1 con el doble de material.\n']);
    end
end

%% 6. Guardado
[~, stem] = fileparts(topName);
outFile = fullfile(outputFolder(), [stem '_decodificado.txt']);

fid = fopen(outFile, 'w');
if fid < 0
    warning('decodeFromStructure:cannotWrite', ...
        'No se pudo guardar el resultado en "%s".', outFile);
else
    fprintf(fid, '%s', text);
    fclose(fid);
    fprintf('\nTexto guardado en:\n  %s\n', outFile);
end

chainFile = fullfile(outputFolder(), [stem '_cadena.seq']);
writeChain(chainFile, report.rawBody, struct( ...
    'estructura', topName, ...
    'capa',       1 + report.useLayer2, ...
    'caracteres', report.nChars));
fprintf('Cadena guardada en:\n  %s\n', chainFile);

if ~isempty(impact)
    noisyFile = fullfile(outputFolder(), [stem '_decodificado_con_ruido.txt']);
    fid = fopen(noisyFile, 'w');
    if fid >= 0
        fprintf(fid, '%s', noisyText);
        fclose(fid);
        fprintf('Texto con ruido guardado en:\n  %s\n', noisyFile);
    end
end

fprintf('\nTiempo total: %.2f s\n\n', toc(timer));
