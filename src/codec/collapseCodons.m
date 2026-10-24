function out = collapseCodons(nt)
%COLLAPSECODONS  Inversa de EXPANDCODONS: de bloques de 8 nt a codones de 4.
%
%   out = COLLAPSECODONS(nt) se queda con los primeros 4 nucleótidos de cada
%   bloque de 8 y descarta el complemento. Es la inversa exacta de
%   EXPANDCODONS para cualquier entrada bien formada.

if isstring(nt)
    nt = char(nt);
end
nt = reshape(nt, 1, []);

nBlocks = floor(numel(nt) / 8);
if nBlocks == 0
    out = '';
    return
end

block = reshape(nt(1:8 * nBlocks), 8, nBlocks);
out = reshape(block(1:4, :), 1, []);
end
