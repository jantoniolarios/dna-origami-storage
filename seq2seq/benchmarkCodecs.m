function varargout = benchmarkCodecs(varargin)
%BENCHMARKCODECS  Compara la red con la tabla de búsqueda en coste y exactitud.
%
%   BENCHMARKCODECS() mide sobre los 50 documentos de prueba:
%     - tiempo de la transformación exacta (expandCodons)
%     - tiempo de la red entrenada (seq2seqTranslate)
%     - rendimiento en nucleótidos por segundo de cada una
%     - número de parámetros aprendibles frente al tamaño de la tabla
%     - si ambas producen el mismo resultado
%
%   results = BENCHMARKCODECS('NumFiles', n) usa solo los primeros n
%   documentos; la red es lenta y el corpus completo puede tardar.

thisDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(thisDir, 'model')));
addpath(genpath(fullfile(fileparts(thisDir), 'src')));

p = inputParser;
p.addParameter('WeightsFile', fullfile(thisDir, 'model', 'seq2seqWeights.mat'));
p.addParameter('DataFolder', fullfile(thisDir, 'data', 'pruebas'));
p.addParameter('NumFiles', Inf);
p.parse(varargin{:});
opt = p.Results;

if exist(opt.WeightsFile, 'file') ~= 2
    error('benchmarkCodecs:noWeights', ...
        'No se encontró "%s". Ejecuta trainSeq2Seq primero.', opt.WeightsFile);
end
w = load(opt.WeightsFile);

files = dir(fullfile(opt.DataFolder, '*.txt'));
files = files(~[files.isdir]);
files = files(1:min(numel(files), opt.NumFiles));

if isempty(files)
    error('benchmarkCodecs:noData', 'No hay archivos .txt en "%s".', opt.DataFolder);
end

pieces = cell(1, numel(files));
for k = 1:numel(files)
    pieces{k} = fileread(fullfile(files(k).folder, files(k).name));
end
corpus = [pieces{:}];

ref = seq2seqDataset('CodonSet', w.info.dataset.codonSet);
layer1 = encodeWithTable(corpus, ref);
nIn = numel(layer1);

fprintf('\n===============================================\n');
fprintf('  Tabla de búsqueda frente a red seq2seq\n');
fprintf('===============================================\n');
fprintf('Documentos : %d\n', numel(files));
fprintf('Entrada    : %d nt de capa 1 (%d caracteres)\n\n', nIn, nIn / 4);

%% Transformación exacta
tableTimer = tic;
exact = expandCodons(layer1);
tableTime = toc(tableTimer);

%% Red entrenada
netTimer = tic;
predicted = char(seq2seqTranslate(layer1, w));
netTime = toc(netTimer);

%% Comparación
n = numel(exact);
padded = repmat(' ', 1, n);
m = min(n, numel(predicted));
padded(1:m) = predicted(1:m);
agree = sum(exact == padded);

%% Tamaño de cada representación
numLearnables = w.info.numLearnables;
tableEntries = w.info.dataset.nTotal;
tableBytes = tableEntries * 12;
networkBytes = numLearnables * 4;

fprintf('Transformación exacta (expandCodons)\n');
fprintf('  tiempo        : %.4f s\n', tableTime);
fprintf('  rendimiento   : %.3g nt/s\n', n / tableTime);
fprintf('  representación: %d entradas, %d bytes\n\n', tableEntries, tableBytes);

fprintf('Red seq2seq entrenada\n');
fprintf('  tiempo        : %.4f s\n', netTime);
fprintf('  rendimiento   : %.3g nt/s\n', n / netTime);
fprintf('  representación: %d parámetros aprendibles, %d bytes\n\n', ...
    numLearnables, networkBytes);

fprintf('La red tarda %.0f veces más y ocupa %.0f veces más memoria\n', ...
    netTime / tableTime, networkBytes / tableBytes);
fprintf('que la tabla, para calcular la misma función.\n\n');

fprintf('Coincidencia entre ambas: %.4f%% de los nucleótidos (%d de %d)\n', ...
    100 * agree / n, agree, n);
fprintf('===============================================\n');

results = struct( ...
    'numFiles',        numel(files), ...
    'nNucleotidesIn',  nIn, ...
    'nNucleotidesOut', n, ...
    'tableSeconds',    tableTime, ...
    'networkSeconds',  netTime, ...
    'speedupFactor',   netTime / tableTime, ...
    'tableEntries',    tableEntries, ...
    'tableBytes',      tableBytes, ...
    'numLearnables',   numLearnables, ...
    'networkBytes',    networkBytes, ...
    'memoryFactor',    networkBytes / tableBytes, ...
    'agreementPct',    100 * agree / n);

resultsDir = fullfile(thisDir, 'results');
if exist(resultsDir, 'dir') ~= 7
    mkdir(resultsDir);
end
save(fullfile(resultsDir, 'benchmark.mat'), 'results');
writetable(struct2table(results), fullfile(resultsDir, 'benchmark.csv'));

fprintf('\nGuardado en %s\n', resultsDir);

if nargout > 0
    varargout{1} = results;
end
end
