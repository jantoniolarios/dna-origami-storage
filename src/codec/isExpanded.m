function tf = isExpanded(nt, minBlocks)
%ISEXPANDED  Comprueba si una secuencia tiene la estructura de la capa 2.
%
%   tf = ISEXPANDED(nt) devuelve true si nt se compone de bloques de 8
%   nucleótidos en los que la segunda mitad es el complemento exacto de la
%   primera, es decir, si es una cadena producida por EXPANDCODONS.
%
%   tf = ISEXPANDED(nt, minBlocks) exige además al menos minBlocks bloques
%   para dar un veredicto positivo (por defecto 2). Sirve para distinguir una
%   cadena de capa 2 de una de capa 1 que por casualidad empiece igual.


if nargin < 2 || isempty(minBlocks)
    minBlocks = 2;
end

if isstring(nt)
    nt = char(nt);
end
nt = reshape(nt, 1, []);

nBlocks = floor(numel(nt) / 8);
if nBlocks < minBlocks
    tf = false;
    return
end

block = reshape(nt(1:8 * nBlocks), 8, nBlocks);
tf = isequal(block(5:8, :), complementNt(block(1:4, :)));
end
