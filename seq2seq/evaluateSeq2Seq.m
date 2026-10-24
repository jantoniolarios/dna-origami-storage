function varargout = evaluateSeq2Seq(varargin)
%EVALUATESEQ2SEQ  Evalúa el modelo con las métricas pedidas en la revisión.
%
%   EVALUATESEQ2SEQ() carga model/seq2seqWeights.mat y evalúa los 50
%   documentos de data/pruebas/. Con argumento de salida devuelve además la
%   estructura de resultados; sin él no imprime nada de más.
%
%   results = EVALUATESEQ2SEQ('Nombre', valor, ...) admite:
%     'WeightsFile'  .mat con los pesos entrenados
%     'DataFolder'   carpeta con los documentos de prueba
%     'CodonSet'     tabla de referencia para los objetivos esperados;
%                    por defecto la que se usó al entrenar
%     'SaveFigures'  generar las figuras (true)
%
%   Métricas que se calculan:
%
%     Exactitud por nucleótido  - posiciones correctas sobre el total.
%     Exact-match por secuencia - bloques de 8 nt enteramente correctos.
%     Recuperación por carácter - caracteres que sobreviven al viaje
%                                 completo texto -> capa 1 -> red -> texto.
%     Cobertura                 - cuántos codones distintos aparecen en la
%                                 prueba y cuántos de ellos estaban en el
%                                 entrenamiento. R
%     Codones retenidos         - si el modelo se entrenó con HoldOut > 0,
%                                 exactitud sobre entradas nunca vistas.
%     Matriz de confusión       - esperado frente a predicho, base a base.
%
%   Los resultados se guardan en results/ como .csv y .mat.

thisDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(thisDir, 'model')));
addpath(genpath(fullfile(fileparts(thisDir), 'src')));

p = inputParser;
p.addParameter('WeightsFile', fullfile(thisDir, 'model', 'seq2seqWeights.mat'));
p.addParameter('DataFolder', fullfile(thisDir, 'data', 'pruebas'));
p.addParameter('CodonSet', '');
p.addParameter('SaveFigures', true);
p.parse(varargin{:});
opt = p.Results;

if exist(opt.WeightsFile, 'file') ~= 2
    error('evaluateSeq2Seq:noWeights', ...
        ['No se encontró "%s". Ejecuta trainSeq2Seq primero.'], opt.WeightsFile);
end

w = load(opt.WeightsFile);

if isempty(opt.CodonSet)
    opt.CodonSet = w.info.dataset.codonSet;
end

ref = seq2seqDataset('CodonSet', opt.CodonSet);
refMap = containers.Map(ref.allSource, ref.allTarget);
trainedSet = containers.Map(w.info.dataset.trainSource, ...
    repmat({true}, numel(w.info.dataset.trainSource), 1));

files = dir(fullfile(opt.DataFolder, '*.txt'));
files = files(~[files.isdir]);
if isempty(files)
    error('evaluateSeq2Seq:noData', 'No hay archivos .txt en "%s".', opt.DataFolder);
end

fprintf('\n===============================================\n');
fprintf('  Evaluación del modelo seq2seq\n');
fprintf('===============================================\n');
fprintf('Pesos      : %s\n', opt.WeightsFile);
fprintf('Entrenado  : %s, %d pares, %d retenidos, semilla %d\n', ...
    w.info.dataset.codonSet, w.info.dataset.nTrain, ...
    w.info.dataset.nHeldOut, w.info.dataset.seed);
fprintf('Documentos : %d\n\n', numel(files));

nFiles = numel(files);
name       = cell(nFiles, 1);
ntTotal    = zeros(nFiles, 1);
ntCorrect  = zeros(nFiles, 1);
blkTotal   = zeros(nFiles, 1);
blkCorrect = zeros(nFiles, 1);
chrTotal   = zeros(nFiles, 1);
chrCorrect = zeros(nFiles, 1);
docExact   = false(nFiles, 1);
ntMissing  = zeros(nFiles, 1);
firstHalfOK     = zeros(nFiles, 1);
secondHalfOK    = zeros(nFiles, 1);
firstHalfBlocks = zeros(nFiles, 1);

errorsByPosition = zeros(1, 8);
confusion = zeros(4, 4);
bases = 'ACGT';
seenCodons = containers.Map('KeyType', 'char', 'ValueType', 'double');

for k = 1:nFiles
    name{k} = files(k).name;
    text = fileread(fullfile(files(k).folder, files(k).name));

    [layer1, codonList] = encodeWithTable(text, ref);

    for c = 1:numel(codonList)
        key = codonList{c};
        if isKey(seenCodons, key)
            seenCodons(key) = seenCodons(key) + 1;
        else
            seenCodons(key) = 1;
        end
    end

    nCodons = numel(codonList);
    expandedBlocks = repmat(' ', 8, nCodons);
    for c = 1:nCodons
        expandedBlocks(:, c) = refMap(codonList{c}).';
    end
    expected = reshape(expandedBlocks, 1, []);

    predicted = char(seq2seqTranslate(layer1, w));

    n = numel(expected);
    padded = repmat(' ', 1, n);
    m = min(n, numel(predicted));
    padded(1:m) = predicted(1:m);

    match = expected == padded;

    ntTotal(k)   = n;
    ntCorrect(k) = sum(match);
    ntMissing(k) = max(0, n - numel(predicted));

    nBlocks = floor(n / 8);
    blkTotal(k) = nBlocks;

    if nBlocks > 0
        blockMatch = reshape(match(1:8 * nBlocks), 8, nBlocks);
        blkCorrect(k) = sum(all(blockMatch, 1));
        errorsByPosition = errorsByPosition + sum(~blockMatch, 2).';
        firstHalfOK(k)  = sum(sum(blockMatch(1:4, :)));
        secondHalfOK(k) = sum(sum(blockMatch(5:8, :)));
        firstHalfBlocks(k)  = sum(all(blockMatch(1:4, :), 1));
    end

    original  = decodeText(layer1);
    recovered = decodeText(collapseCodons(padded));

    nChars = numel(original);
    alignedRecovered = repmat(char(0), 1, nChars);
    mc = min(nChars, numel(recovered));
    alignedRecovered(1:mc) = recovered(1:mc);

    chrTotal(k)   = nChars;
    chrCorrect(k) = sum(alignedRecovered == original);
    docExact(k)   = strcmp(recovered, original);

    for i = 1:n
        r = find(bases == expected(i), 1);
        c = find(bases == padded(i), 1);
        if ~isempty(r) && ~isempty(c)
            confusion(r, c) = confusion(r, c) + 1;
        end
    end

    fprintf('  %-12s nt %7.3f%%   bloques %7.3f%%   caracteres %7.3f%%\n', ...
        name{k}, 100 * ntCorrect(k) / max(1, ntTotal(k)), ...
        100 * blkCorrect(k) / max(1, blkTotal(k)), ...
        100 * chrCorrect(k) / max(1, chrTotal(k)));
end

perDocument = table(name, ntTotal, ntCorrect, ntMissing, blkTotal, blkCorrect, ...
    firstHalfBlocks, chrTotal, chrCorrect, docExact, 'VariableNames', ...
    {'File', 'NtTotal', 'NtCorrect', 'NtMissing', 'BlockTotal', 'BlockCorrect', ...
     'FirstHalfBlocksOK', 'CharTotal', 'CharCorrect', 'DocExact'});

%% Cobertura
testCodons = keys(seenCodons);
inTrain = cellfun(@(c) isKey(trainedSet, c), testCodons);

coverage = struct( ...
    'nPossible',        256, ...
    'nInTable',         ref.nTotal, ...
    'nTrained',         w.info.dataset.nTrain, ...
    'nDistinctInTest',  numel(testCodons), ...
    'nTestSeenInTrain', sum(inTrain), ...
    'nTestUnseen',      sum(~inTrain), ...
    'nTrainedNeverTested', w.info.dataset.nTrain - sum(inTrain));

%% Codones retenidos
heldOut = struct('n', 0, 'ntAccuracy', NaN, 'exactMatch', NaN, ...
    'firstHalfExact', NaN, 'codons', {{}});
if w.info.dataset.nHeldOut > 0
    src = w.info.dataset.testSource;
    tgt = w.info.dataset.testTarget;
    okBlocks = 0; okFirstHalf = 0; ntOk = 0; ntAll = 0;
    for k = 1:numel(src)
        pred = char(seq2seqTranslate(src{k}, w));
        exp8 = tgt{k};
        m = min(numel(exp8), numel(pred));
        hit = false(1, numel(exp8));
        hit(1:m) = exp8(1:m) == pred(1:m);
        ntOk = ntOk + sum(hit);
        ntAll = ntAll + numel(exp8);
        okBlocks = okBlocks + all(hit);
        okFirstHalf = okFirstHalf + all(hit(1:4));
    end
    heldOut.firstHalfExact = 100 * okFirstHalf / numel(src);
    heldOut.n = numel(src);
    heldOut.ntAccuracy = 100 * ntOk / ntAll;
    heldOut.exactMatch = 100 * okBlocks / numel(src);
    heldOut.codons = src;
end

%% Resumen
ntAccuracy  = 100 * sum(ntCorrect)  / sum(ntTotal);
blkAccuracy = 100 * sum(blkCorrect) / sum(blkTotal);
chrAccuracy = 100 * sum(chrCorrect) / sum(chrTotal);
docAccuracy = 100 * sum(docExact)   / nFiles;

fprintf('\n-----------------------------------------------\n');
fprintf('Exactitud por nucleótido        : %.4f%%  (%d de %d)\n', ...
    ntAccuracy, sum(ntCorrect), sum(ntTotal));
fprintf('Exact-match por secuencia (8 nt): %.4f%%  (%d de %d)\n', ...
    blkAccuracy, sum(blkCorrect), sum(blkTotal));
fprintf('Recuperación por carácter       : %.4f%%  (%d de %d)\n', ...
    chrAccuracy, sum(chrCorrect), sum(chrTotal));
fprintf('Documentos recuperados enteros  : %.2f%%  (%d de %d)\n', ...
    docAccuracy, sum(docExact), nFiles);
fprintf('-----------------------------------------------\n');
fprintf('Dónde caen los errores dentro del bloque de 8:\n');
fprintf('  posición      1     2     3     4  |     5     6     7     8\n');
fprintf('  errores  %5d %5d %5d %5d  | %5d %5d %5d %5d\n', errorsByPosition);
fprintf('  primera mitad (codón, informativa) : %d errores\n', sum(errorsByPosition(1:4)));
fprintf('  segunda mitad (complemento, redundante) : %d errores\n', ...
    sum(errorsByPosition(5:8)));
fprintf(['  collapseCodons se queda con la primera mitad, así que un error\n' ...
         '  en la segunda no llega a afectar al texto recuperado.\n']);
if sum(ntMissing) > 0
    fprintf('  nucleótidos que el modelo no llegó a producir : %d\n', sum(ntMissing));
end
fprintf('-----------------------------------------------\n');
fprintf('Cobertura del conjunto de prueba:\n');
fprintf('  4-meros posibles                      : %d\n', coverage.nPossible);
fprintf('  en la tabla                           : %d\n', coverage.nInTable);
fprintf('  usados en entrenamiento               : %d\n', coverage.nTrained);
fprintf('  distintos en los documentos de prueba : %d\n', coverage.nDistinctInTest);
fprintf('    de ellos vistos en entrenamiento    : %d\n', coverage.nTestSeenInTrain);
fprintf('    de ellos NO vistos en entrenamiento : %d\n', coverage.nTestUnseen);
fprintf('  entrenados y nunca evaluados          : %d\n', coverage.nTrainedNeverTested);

if heldOut.n > 0
    fprintf('-----------------------------------------------\n');
    fprintf('Codones retenidos (generalización):\n');
    fprintf('  codones nunca vistos          : %d\n', heldOut.n);
    fprintf('  exactitud por nucleótido      : %.4f%%\n', heldOut.ntAccuracy);
    fprintf('  exact-match del bloque de 8   : %.4f%%\n', heldOut.exactMatch);
    fprintf('  primera mitad exacta (codón)  : %.4f%%\n', heldOut.firstHalfExact);
    fprintf(['  La primera mitad es la que lleva la información: si sale\n' ...
             '  exacta, el carácter se recupera aunque falle el complemento.\n']);
else
    fprintf('-----------------------------------------------\n');
    fprintf(['Sin codones retenidos: este modelo se entrenó con la tabla\n' ...
             'completa, así que las cifras de arriba miden reproducción de\n' ...
             'entradas memorizadas, no generalización. Para medir\n' ...
             'generalización: trainSeq2Seq(''HoldOut'', 0.2).\n']);
end
fprintf('-----------------------------------------------\n');

results = struct( ...
    'perDocument', perDocument, ...
    'ntAccuracy', ntAccuracy, ...
    'blockExactMatch', blkAccuracy, ...
    'charRecovery', chrAccuracy, ...
    'documentExactMatch', docAccuracy, ...
    'confusion', confusion, ...
    'confusionLabels', {cellstr(bases(:))}, ...
    'errorsByPosition', errorsByPosition, ...
    'firstHalfErrors', sum(errorsByPosition(1:4)), ...
    'secondHalfErrors', sum(errorsByPosition(5:8)), ...
    'nucleotidesMissing', sum(ntMissing), ...
    'coverage', coverage, ...
    'heldOut', heldOut, ...
    'weightsFile', opt.WeightsFile, ...
    'trainingInfo', w.info);

%% Guardado
resultsDir = fullfile(thisDir, 'results');
if exist(resultsDir, 'dir') ~= 7
    mkdir(resultsDir);
end

writetable(perDocument, fullfile(resultsDir, 'per_document_metrics.csv'));
writematrix(confusion, fullfile(resultsDir, 'confusion_matrix.csv'));
save(fullfile(resultsDir, 'evaluation.mat'), 'results');

fprintf('\nResultados guardados en:\n  %s\n', resultsDir);

if opt.SaveFigures
    makeFigures(results, resultsDir, bases);
end

if nargout > 0
    varargout{1} = results;
end
end

function makeFigures(results, resultsDir, bases)
correct = sum(results.perDocument.NtCorrect);
wrong   = sum(results.perDocument.NtTotal) - correct;

f1 = figure('Visible', 'off');
cleanup1 = onCleanup(@() closeIfValid(f1)); %#ok<NASGU>
bar([correct, wrong]);
set(gca, 'XTickLabel', {'Correct', 'Incorrect'}, 'FontSize', 14);
ylabel('Nucleotides', 'FontSize', 14);
title(sprintf('Nucleotide-level comparison (%.4f%% correct)', ...
    results.ntAccuracy), 'FontSize', 14);
saveFigure(f1, fullfile(resultsDir, 'comparison_bar.png'));

f2 = figure('Visible', 'off');
cleanup2 = onCleanup(@() closeIfValid(f2)); %#ok<NASGU>
labels = cellstr(bases(:));
heatmap(labels, labels, results.confusion, ...
    'Title', 'Confusion matrix (expected vs predicted)', ...
    'XLabel', 'Predicted', 'YLabel', 'Expected');
colormap('hot');
saveFigure(f2, fullfile(resultsDir, 'confusion_matrix.png'));
end

function saveFigure(fig, path)
try
    exportgraphics(fig, path, 'Resolution', 200);
    fprintf('  figura: %s\n', path);
    return
catch errExport
    primera = errExport.message;
end

try
    print(fig, path, '-dpng', '-r200');
    fprintf('  figura: %s (con print)\n', path);
catch errPrint
    warning('evaluateSeq2Seq:figureFailed', ...
        ['No se pudo guardar "%s".\n' ...
         '  exportgraphics: %s\n' ...
         '  print: %s\n' ...
         'Las métricas sí quedaron guardadas. Si el archivo está abierto en ' ...
         'un visor, ciérralo y vuelve a ejecutar.'], ...
        path, primera, errPrint.message);
end
end

function closeIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    close(fig);
end
end
