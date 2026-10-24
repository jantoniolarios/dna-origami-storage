function [noisy, report] = injectNoise(nt, varargin)
%INJECTNOISE  Introduce errores simulados de síntesis en una cadena.
%
%   noisy = INJECTNOISE(nt, 'Nombre', valor, ...) admite:
%
%     'Substitution'  fracción de nucleótidos sustituidos por otra base (0)
%     'Deletion'      fracción de nucleótidos eliminados (0)
%     'Insertion'     nucleótidos añadidos, como fracción de la longitud (0)
%     'Seed'          semilla del generador aleatorio (0)
%
%   Las tres tasas son fracciones de la longitud ORIGINAL y se aplican en
%   una sola pasada, así que son independientes entre sí: pedir 1 % de
%   sustitución y 1 % de eliminación da exactamente round(0.01*N) de cada
%   una, no una sobre el resultado de la otra.
%
%   [noisy, report] = INJECTNOISE(...) devuelve el recuento real aplicado,
%   las longitudes de entrada y salida, y la primera posición alterada.

p = inputParser;
p.addParameter('Substitution', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
p.addParameter('Deletion',     0, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
p.addParameter('Insertion',    0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('Seed',         0, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});
opt = p.Results;

nt = reshape(char(nt), 1, []);
n = numel(nt);

report = struct('nIn', n, 'nOut', n, 'substitutions', 0, 'deletions', 0, ...
    'insertions', 0, 'firstChange', NaN, 'seed', opt.Seed, ...
    'rates', struct('substitution', opt.Substitution, ...
                    'deletion', opt.Deletion, 'insertion', opt.Insertion));

if n == 0
    noisy = '';
    return
end

rng(opt.Seed, 'twister');

bases = 'ACGT';

nSub = min(n, round(opt.Substitution * n));
nDel = min(n, round(opt.Deletion * n));
nIns = round(opt.Insertion * n);

delMask = false(1, n);
delMask(randperm(n, nDel)) = true;

survivors = find(~delMask);
nSub = min(nSub, numel(survivors));

subMask = false(1, n);
if nSub > 0
    subMask(survivors(randperm(numel(survivors), nSub))) = true;
end

insCount = zeros(1, n + 1);
if nIns > 0
    gaps = randi(n + 1, 1, nIns);
    for k = 1:nIns
        insCount(gaps(k)) = insCount(gaps(k)) + 1;
    end
end

out = repmat(' ', 1, n + nIns);
written = 0;
firstChange = NaN;

for i = 1:(n + 1)
    for k = 1:insCount(i)
        written = written + 1;
        out(written) = bases(randi(4));
        report.insertions = report.insertions + 1;
        if isnan(firstChange)
            firstChange = written;
        end
    end

    if i > n
        break
    end

    if delMask(i)
        report.deletions = report.deletions + 1;
        if isnan(firstChange)
            firstChange = written + 1;
        end
        continue
    end

    base = nt(i);
    if subMask(i)
        alternatives = bases(bases ~= base);
        base = alternatives(randi(3));
        report.substitutions = report.substitutions + 1;
        if isnan(firstChange)
            firstChange = written + 1;
        end
    end

    written = written + 1;
    out(written) = base;
end

noisy = out(1:written);

report.nOut = numel(noisy);
report.firstChange = firstChange;
report.totalErrors = report.substitutions + report.deletions + report.insertions;
end
