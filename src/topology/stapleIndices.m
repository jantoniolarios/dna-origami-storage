function idx = stapleIndices(top)
%STAPLEINDICES  Posiciones de los nucleótidos que pertenecen a los staples.
%
%   idx = STAPLEINDICES(top) devuelve un vector columna con los índices (base
%   1, en el orden en que aparecen en el archivo) de todos los nucleótidos
%   que no pertenecen al scaffold.

idx = find(top.strand >= 2);
idx = idx(:);

if isempty(idx)
    error('stapleIndices:noStaples', ...
        ['La topología "%s" solo tiene una hebra: no hay staples donde ' ...
         'almacenar información.'], topName(top));
end
end

function name = topName(top)
if isfield(top, 'filename') && ~isempty(top.filename)
    name = top.filename;
else
    name = '(sin nombre)';
end
end
