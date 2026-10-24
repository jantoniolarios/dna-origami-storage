function seq = stapleSequence(top)
%STAPLESEQUENCE  Secuencia de bases de la región de staples, en orden de archivo.
%
%   seq = STAPLESEQUENCE(top) devuelve un vector fila de caracteres con las
%   bases de todos los nucleótidos de staples concatenadas.

seq = reshape(top.base(stapleIndices(top)), 1, []);
end
