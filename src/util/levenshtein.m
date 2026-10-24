function [distance, similarity] = levenshtein(a, b)
%LEVENSHTEIN  Distancia de edición entre dos cadenas.
%
%   distance = LEVENSHTEIN(a, b) devuelve el número mínimo de inserciones,
%   eliminaciones y sustituciones que convierten a en b.
%
%   [distance, similarity] = LEVENSHTEIN(a, b) devuelve además la similitud
%   en porcentaje: 100 * (1 - distance / max(length(a), length(b))).

a = reshape(char(a), 1, []);
b = reshape(char(b), 1, []);

n = numel(a);
m = numel(b);

if n == 0 || m == 0
    distance = max(n, m);
    similarity = 100 * (max(n, m) == 0);
    return
end

idx  = 0:m;
prev = idx;

for i = 1:n
    cost = double(a(i) ~= b);

    tmp = zeros(1, m + 1);
    tmp(1) = i;
    tmp(2:end) = min(prev(1:m) + cost, prev(2:end) + 1);

    prev = idx + cummin(tmp - idx);
end

distance = prev(end);
similarity = 100 * (1 - distance / max(n, m));
end
