function varargout = trainSeq2Seq(varargin)
%TRAINSEQ2SEQ  Entrena la red seq2seq con atención que aprende la capa 2.
%
%   TRAINSEQ2SEQ() reproduce la configuración publicada: los 220
%   codones de la tabla original, sin partición, 300 épocas, minilotes de 32.
%   Guarda los pesos y el registro completo en model/seq2seqWeights.mat.
%
%   info = TRAINSEQ2SEQ(...) devuelve el registro de la corrida. Sin
%   argumento de salida no imprime nada: el registro queda en el .mat.
%
%   TRAINSEQ2SEQ('Nombre', valor, ...) admite:
%
%     'CodonSet'      'legacy220' (por defecto), 'codebook224' o 'all256'
%     'HoldOut'       fracción de codones reservados para prueba (0)
%     'Seed'          semilla del generador aleatorio (0)
%     'NumEpochs'     épocas de entrenamiento (300)
%     'MiniBatchSize' tamaño del minilote (32)
%     'LearnRate'     tasa de aprendizaje de Adam (0.001)
%     'EmbeddingDimension'  dimensión del embedding (128)
%     'NumHiddenUnits'      unidades ocultas de las LSTM (100)
%     'Dropout'       probabilidad de dropout en el decodificador (0.05)
%     'OutputFile'    ruta del .mat de salida
%     'ShowProgress'  abrir la ventana de progreso (true)
%
%   Requiere Deep Learning Toolbox y Text Analytics Toolbox.

thisDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(thisDir, 'model')));
addpath(genpath(fullfile(fileparts(thisDir), 'src')));

p = inputParser;
p.addParameter('CodonSet', 'legacy220');
p.addParameter('HoldOut', 0);
p.addParameter('Seed', 0);
p.addParameter('NumEpochs', 300);
p.addParameter('MiniBatchSize', 32);
p.addParameter('LearnRate', 0.001);
p.addParameter('EmbeddingDimension', 128);
p.addParameter('NumHiddenUnits', 100);
p.addParameter('Dropout', 0.05);
p.addParameter('OutputFile', '');
p.addParameter('ShowProgress', true);
p.parse(varargin{:});
opt = p.Results;

if isempty(opt.OutputFile)
    opt.OutputFile = fullfile(thisDir, 'model', 'seq2seqWeights.mat');
end

%% Datos y partición
data = seq2seqDataset('CodonSet', opt.CodonSet, ...
    'HoldOut', opt.HoldOut, 'Seed', opt.Seed);

fprintf('\nConjunto de codones : %s\n', data.codonSet);
fprintf('Pares totales       : %d\n', data.nTotal);
fprintf('Entrenamiento       : %d\n', data.nTrain);
fprintf('Reservados (prueba) : %d\n', data.nHeldOut);
if ~isempty(data.legacyDeviations)
    fprintf(['Aviso: %d objetivos de la tabla publicada no siguen la regla del\n' ...
             '       complemento (%s). Se entrena con ellos tal cual para\n' ...
             '       reproducir la corrida original.\n'], ...
        numel(data.legacyDeviations), strjoin(data.legacyDeviations, ', '));
end

%% Semilla
rng(opt.Seed, 'twister');

%% Representación de las secuencias
startToken = "<start>";
stopToken  = "<stop>";

documentsSource = transformText(string(data.trainSource), startToken, stopToken);
encSource = wordEncoding(documentsSource);
sequencesSource = doc2sequence(encSource, documentsSource, PaddingDirection="none");

documentsTarget = transformText(string(data.trainTarget), startToken, stopToken);
encTarget = wordEncoding(documentsTarget);
sequencesTarget = doc2sequence(encTarget, documentsTarget, PaddingDirection="none");

sequenceLengths = cellfun(@(s) size(s, 2), sequencesSource);
[~, idx] = sort(sequenceLengths);
sequencesSource = sequencesSource(idx);
sequencesTarget = sequencesTarget(idx);

sequencesDs = combine( ...
    arrayDatastore(sequencesSource, OutputType="same"), ...
    arrayDatastore(sequencesTarget, OutputType="same"));

%% Parámetros del codificador
embeddingDimension = opt.EmbeddingDimension;
numHiddenUnits     = opt.NumHiddenUnits;

inputSize = encSource.NumWords + 1;
parameters.encoder.emb.Weights = initializeGaussian([embeddingDimension inputSize], 0, 0.01);
parameters.encoder.lstm.InputWeights = initializeGlorot( ...
    [4 * numHiddenUnits embeddingDimension], 4 * numHiddenUnits, embeddingDimension);
parameters.encoder.lstm.RecurrentWeights = initializeOrthogonal( ...
    [4 * numHiddenUnits numHiddenUnits]);
parameters.encoder.lstm.Bias = initializeUnitForgetGate(numHiddenUnits);

%% Parámetros del decodificador
outputSize = encTarget.NumWords + 1;
parameters.decoder.emb.Weights = initializeGaussian([embeddingDimension outputSize], 0, 0.01);
parameters.decoder.attention.Weights = initializeGlorot( ...
    [numHiddenUnits numHiddenUnits], numHiddenUnits, numHiddenUnits);
parameters.decoder.lstm.InputWeights = initializeGlorot( ...
    [4 * numHiddenUnits embeddingDimension + numHiddenUnits], ...
    4 * numHiddenUnits, embeddingDimension + numHiddenUnits);
parameters.decoder.lstm.RecurrentWeights = initializeOrthogonal( ...
    [4 * numHiddenUnits numHiddenUnits]);
parameters.decoder.lstm.Bias = initializeUnitForgetGate(numHiddenUnits);
parameters.decoder.fc.Weights = initializeGlorot( ...
    [outputSize 2 * numHiddenUnits], outputSize, 2 * numHiddenUnits);
parameters.decoder.fc.Bias = initializeZeros([outputSize 1]);

%% Entrenamiento
mbq = minibatchqueue(sequencesDs, 4, ...
    MiniBatchSize=opt.MiniBatchSize, ...
    MiniBatchFcn=@(x, t) preprocessMiniBatch(x, t, inputSize, outputSize));

trailingAvg   = [];
trailingAvgSq = [];

gradientDecayFactor        = 0.9;
squaredGradientDecayFactor = 0.999;

numIterationsPerEpoch = ceil(data.nTrain / opt.MiniBatchSize);
numIterations         = opt.NumEpochs * numIterationsPerEpoch;

fprintf('Iteraciones por época: %d  (total %d)\n\n', numIterationsPerEpoch, numIterations);

lossHistory = nan(numIterations, 1);

if opt.ShowProgress
    monitor = trainingProgressMonitor(Metrics="Loss", Info="Epoch", XLabel="Iteration");
else
    monitor = [];
end

timer = tic;
epoch = 0;
iteration = 0;
stopped = false;

while epoch < opt.NumEpochs && ~stopped
    epoch = epoch + 1;
    reset(mbq);

    while hasdata(mbq) && ~stopped
        iteration = iteration + 1;

        [X, T, sequenceLengthsSource, maskSequenceTarget] = next(mbq);

        [loss, gradients] = dlfeval(@modelLoss, parameters, X, T, ...
            sequenceLengthsSource, maskSequenceTarget, opt.Dropout);

        [parameters, trailingAvg, trailingAvgSq] = adamupdate(parameters, gradients, ...
            trailingAvg, trailingAvgSq, iteration, opt.LearnRate, ...
            gradientDecayFactor, squaredGradientDecayFactor);

        loss = loss ./ size(T, 3);
        lossHistory(iteration) = double(gather(extractdata(loss)));

        if ~isempty(monitor)
            recordMetrics(monitor, iteration, Loss=loss);
            updateInfo(monitor, Epoch=epoch + " of " + opt.NumEpochs);
            monitor.Progress = 100 * iteration / numIterations;
            stopped = monitor.Stop;
        end
    end
end

elapsed = toc(timer);
lossHistory = lossHistory(1:iteration);

fprintf('Entrenamiento terminado en %.1f s (%d iteraciones).\n', elapsed, iteration);
fprintf('Pérdida  última iteración: %.6g\n', lossHistory(end));
fprintf('         media última época: %.6g\n', ...
    mean(lossHistory(max(1, end - numIterationsPerEpoch + 1):end)));
fprintf('                    mínima: %.6g\n', min(lossHistory));

%% Registro de la corrida
info = struct();
info.dataset = data;

info.hyperparameters = struct( ...
    'codonSet',                   data.codonSet, ...
    'holdOut',                    data.holdOut, ...
    'seed',                       opt.Seed, ...
    'numEpochs',                  opt.NumEpochs, ...
    'miniBatchSize',              opt.MiniBatchSize, ...
    'learnRate',                  opt.LearnRate, ...
    'embeddingDimension',         embeddingDimension, ...
    'numHiddenUnits',             numHiddenUnits, ...
    'dropout',                    opt.Dropout, ...
    'optimizer',                  'adam', ...
    'gradientDecayFactor',        gradientDecayFactor, ...
    'squaredGradientDecayFactor', squaredGradientDecayFactor, ...
    'teacherForcingProbability',  0.5, ...
    'lossFunction',               'crossentropy enmascarada', ...
    'inputVocabSize',             inputSize, ...
    'outputVocabSize',            outputSize);

lastEpoch = lossHistory(max(1, end - numIterationsPerEpoch + 1):end);

info.training = struct( ...
    'numIterations',         iteration, ...
    'numIterationsPerEpoch', numIterationsPerEpoch, ...
    'elapsedSeconds',        elapsed, ...
    'finalLoss',             lossHistory(end), ...
    'finalEpochMeanLoss',    mean(lastEpoch), ...
    'minLoss',               min(lossHistory), ...
    'stoppedEarly',          stopped);

info.environment = environmentRecord();
info.numLearnables = countLearnables(parameters);

%% Guardado
outDir = fileparts(opt.OutputFile);
if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

save(opt.OutputFile, 'parameters', 'encSource', 'encTarget', ...
    'startToken', 'stopToken', 'info', 'lossHistory');

fprintf('\nPesos y registro guardados en:\n  %s\n', opt.OutputFile);
fprintf('Parámetros aprendibles: %d\n', info.numLearnables);
fprintf('\nSiguiente paso: evaluateSeq2Seq\n');

if nargout > 0
    varargout{1} = info;
end
end

function n = countLearnables(parameters)
n = 0;
blocks = fieldnames(parameters);
for i = 1:numel(blocks)
    layers = fieldnames(parameters.(blocks{i}));
    for j = 1:numel(layers)
        tensors = fieldnames(parameters.(blocks{i}).(layers{j}));
        for k = 1:numel(tensors)
            n = n + numel(parameters.(blocks{i}).(layers{j}).(tensors{k}));
        end
    end
end
end

function env = environmentRecord()
env.timestamp    = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
env.matlab       = version;
env.matlabRelease = version('-release');
env.computer     = computer;

try
    v = ver;
    names = {v.Name};
    versions = {v.Version};
    keep = contains(names, {'Deep Learning', 'Text Analytics', 'MATLAB'});
    env.toolboxes = strjoin( ...
        cellfun(@(n, r) sprintf('%s %s', n, r), ...
        names(keep), versions(keep), 'UniformOutput', false), '; ');
catch
    env.toolboxes = '(no disponible)';
end
end
