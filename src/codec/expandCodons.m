function out = expandCodons(nt)
%EXPANDCODONS  Expande cada codón de 4 nt a un bloque de 8 nt (capa 2).
%
%   out = EXPANDCODONS(nt) sustituye cada bloque de 4 nucleótidos por ese
%   mismo bloque seguido de su complemento base a base (A<->T, C<->G).
%   Duplica la longitud de la cadena.

if isstring(nt)
    nt = char(nt);
end
nt = reshape(nt, 1, []);

nCodons = floor(numel(nt) / 4);
if nCodons == 0
    out = '';
    return
end

block = reshape(nt(1:4 * nCodons), 4, nCodons);     
out = reshape([block; complementNt(block)], 1, []);  
end
