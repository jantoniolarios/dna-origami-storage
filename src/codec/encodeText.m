function [nt, dropped] = encodeText(text)
%ENCODETEXT  Codifica texto a nucleótidos, 4 nt por carácter (capa 1).
%
%   nt = ENCODETEXT(text) devuelve un vector fila de caracteres ACGT con
%   cuatro nucleótidos por cada carácter soportado de text.
%
%   [nt, dropped] = ENCODETEXT(text) devuelve además los caracteres que no
%   existen en el codebook y por tanto no pudieron codificarse.

cb = dnaCodebook();

if isstring(text)
    text = char(text);
end
if ~ischar(text)
    error('encodeText:badInput', 'Se esperaba texto (char o string).');
end

text = reshape(text, 1, []);
if isempty(text)
    nt = '';
    dropped = '';
    return
end

code = double(text);

idx = zeros(1, numel(code));
inRange = code >= 1 & code <= numel(cb.sym2idx);
idx(inRange) = cb.sym2idx(code(inRange));

supported = idx > 0;
dropped = text(~supported);

block = cb.codons(idx(supported), :);
nt = reshape(block.', 1, []);
end
