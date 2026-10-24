function [ok, report] = verifyExpansion(nt)
%VERIFYEXPANSION  Detecta bloques de capa 2 dañados usando su redundancia.
%
%   ok = VERIFYEXPANSION(nt) devuelve un vector lógico con un elemento por
%   bloque de 8 nucleótidos: true si la segunda mitad es el complemento
%   exacto de la primera.
%
%   [ok, report] = VERIFYEXPANSION(nt) devuelve además el número de bloques,
%   cuántos son inconsistentes y sus índices.

nt = reshape(char(nt), 1, []);
nBlocks = floor(numel(nt) / 8);

if nBlocks == 0
    ok = false(1, 0);
    report = struct('nBlocks', 0, 'nInconsistent', 0, 'inconsistentIndex', []);
    return
end

block = reshape(nt(1:8 * nBlocks), 8, nBlocks);

firstHalf  = block(1:4, :);
secondHalf = block(5:8, :);

decodable = all(ismember(firstHalf, 'ACGT'), 1) & ...
            all(ismember(secondHalf, 'ACGT'), 1);

ok = false(1, nBlocks);
if any(decodable)
    expected = complementNt(firstHalf(:, decodable));
    ok(decodable) = all(secondHalf(:, decodable) == expected, 1);
end

report = struct( ...
    'nBlocks',           nBlocks, ...
    'nInconsistent',     sum(~ok), ...
    'inconsistentIndex', find(~ok));
end
