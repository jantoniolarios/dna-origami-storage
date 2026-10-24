function out = seq2seqTranslate(nt, model)
%SEQ2SEQTRANSLATE  Aplica la capa 2 usando la red entrenada en vez de la regla.
%
%   out = SEQ2SEQTRANSLATE(nt) divide nt en codones de 4 nucleótidos, los
%   pasa uno a uno por la red seq2seq entrenada y concatena las predicciones.
%
%   out = SEQ2SEQTRANSLATE(nt, weightsFile) usa un archivo de pesos concreto.
%   Por defecto se busca model/seq2seqWeights.mat, que genera trainSeq2Seq.
%
%   out = SEQ2SEQTRANSLATE(nt, model) acepta el modelo ya cargado con load().

thisDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(thisDir, 'model')));
addpath(genpath(fullfile(fileparts(thisDir), 'src')));

if nargin < 2 || isempty(model)
    model = fullfile(thisDir, 'model', 'seq2seqWeights.mat');
end

if isstruct(model)
    w = model;
    required = {'parameters', 'encSource', 'encTarget', 'startToken', 'stopToken'};
    missing = required(~isfield(w, required));
    if ~isempty(missing)
        error('seq2seqTranslate:badModel', ...
            'Al modelo le faltan los campos: %s.', strjoin(missing, ', '));
    end
else
    weightsFile = char(model);
    if exist(weightsFile, 'file') ~= 2
        error('seq2seqTranslate:noWeights', ...
            ['No se encontró "%s".\n' ...
             'Ejecuta trainSeq2Seq para generarlo, o usa expandCodons, que ' ...
             'calcula la misma transformación de forma exacta.'], weightsFile);
    end
    w = load(weightsFile);
end

if isstring(nt)
    nt = char(nt);
end
nt = reshape(nt, 1, []);

blocks = divideIntoBlocks4(nt);

maxSequenceLength = 8;
miniBatchSize = 1;
delimiter = "";

predictions = translateText(w.parameters, blocks, maxSequenceLength, miniBatchSize, ...
    w.encSource, w.encTarget, w.startToken, w.stopToken, delimiter);

out = char(strjoin(predictions, ''));
end
