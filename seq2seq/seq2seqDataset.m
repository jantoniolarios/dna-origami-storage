function data = seq2seqDataset(varargin)
%SEQ2SEQDATASET  Construye los pares de entrenamiento y la partición.
%
%   data = SEQ2SEQDATASET() devuelve la configuración publicada.
%
%   data = SEQ2SEQDATASET('Nombre', valor, ...) admite:
%
%     'CodonSet'   'legacy220'   los 220 codones de la tabla original.
%                  'codebook224' los 224 símbolos del codebook actual
%                  'all256'      los 256 cuatro-meros posibles
%     'HoldOut'    fracción de codones que se retiran del entrenamiento y
%                  se reservan como conjunto de prueba (0 por defecto)
%     'Seed'       semilla del generador aleatorio para la partición (0)
%
%   Devuelve una estructura con:
%     data.trainSource / data.trainTarget - pares de entrenamiento
%     data.testSource  / data.testTarget  - codones retenidos (vacío si HoldOut=0)
%     data.allSource   / data.allTarget   - la tabla completa
%     data.codonSet, data.holdOut, data.seed
%     data.nTrain, data.nHeldOut, data.nTotal
%     data.legacyDeviations - codones cuyo objetivo publicado no sigue la
%                             regla del complemento

p = inputParser;
p.addParameter('CodonSet', 'legacy220', ...
    @(s) any(strcmpi(s, {'legacy220', 'codebook224', 'all256'})));
p.addParameter('HoldOut', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1);
p.addParameter('Seed', 0, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});
opt = p.Results;

codonSet = lower(opt.CodonSet);

switch codonSet
    case 'legacy220'
        [source, target] = legacyPairs();

    case 'codebook224'
        cb = dnaCodebook();
        source = cell(cb.nSymbols, 1);
        target = cell(cb.nSymbols, 1);
        for k = 1:cb.nSymbols
            source{k} = cb.codons(k, :);
            target{k} = expandCodons(cb.codons(k, :));
        end

    case 'all256'
        bases = 'ACGT';
        source = cell(256, 1);
        target = cell(256, 1);
        k = 0;
        for a = 1:4
            for b = 1:4
                for c = 1:4
                    for d = 1:4
                        k = k + 1;
                        source{k} = [bases(a) bases(b) bases(c) bases(d)];
                        target{k} = expandCodons(source{k});
                    end
                end
            end
        end
end

n = numel(source);

deviations = {};
for k = 1:n
    if ~strcmp(target{k}, expandCodons(source{k}))
        deviations{end + 1} = source{k}; %#ok<AGROW>
    end
end

nHeldOut = floor(opt.HoldOut * n);
if nHeldOut > 0
    rng(opt.Seed, 'twister');
    order = randperm(n);
    testIdx  = sort(order(1:nHeldOut));
    trainIdx = sort(order(nHeldOut + 1:end));
else
    testIdx  = zeros(1, 0);
    trainIdx = 1:n;
end

data.codonSet          = codonSet;
data.holdOut           = opt.HoldOut;
data.seed              = opt.Seed;
data.allSource         = source;
data.allTarget         = target;
data.trainSource       = source(trainIdx);
data.trainTarget       = target(trainIdx);
data.testSource        = source(testIdx);
data.testTarget        = target(testIdx);
data.trainIndex        = trainIdx(:);
data.testIndex         = testIdx(:);
data.nTotal            = n;
data.nTrain            = numel(trainIdx);
data.nHeldOut          = numel(testIdx);
data.legacyDeviations  = deviations;
end

function [source, target] = legacyPairs()
csvFile = fullfile(projectRoot(), 'src', 'tests', 'data', 'legacy_map4to8.csv');
if exist(csvFile, 'file') ~= 2
    error('seq2seqDataset:noLegacyTable', ...
        'No se encontró la tabla original en "%s".', csvFile);
end

tbl = readtable(csvFile, 'TextType', 'char');
source = tbl.codon4;
target = tbl.codon8;
end
