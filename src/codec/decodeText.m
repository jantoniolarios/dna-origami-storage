function [text, unknown] = decodeText(nt, placeholder)
%DECODETEXT  Decodifica nucleótidos a texto, 4 nt por carácter (capa 1).
%
%   text = DECODETEXT(nt) interpreta nt como una secuencia de codones de 4
%   nucleótidos y devuelve el texto correspondiente.
%
%   text = DECODETEXT(nt, placeholder) pone ese carácter en lugar de cada
%   codón sin símbolo asignado, en vez de omitirlo. Conviene al analizar una
%   cadena dañada: omitir un codón recorre todo el texto posterior y hace
%   imposible ver dónde está el daño, mientras que un marcador conserva la
%   alineación y lo deja a la vista.
%
%   [text, unknown] = DECODETEXT(...) devuelve además cuántos codones no
%   correspondían a ningún símbolo del codebook. De los 256 codones posibles
%   hay 32 sin asignar, así que un valor alto indica que la cadena no era un
%   mensaje válido o que se leyó con el marco desplazado.
%
%   Si la longitud de nt no es múltiplo de 4 se ignoran los nucleótidos
%   sobrantes del final.

cb = dnaCodebook();

if nargin < 2
    placeholder = '';
end
if ~isempty(placeholder)
    placeholder = char(placeholder);
    if numel(placeholder) ~= 1
        error('decodeText:badPlaceholder', ...
            'El marcador debe ser un solo carácter.');
    end
end

if isstring(nt)
    nt = char(nt);
end
if ~ischar(nt)
    error('decodeText:badInput', 'Se esperaba una secuencia de nucleótidos (char o string).');
end

nt = reshape(nt, 1, []);
nCodons = floor(numel(nt) / 4);
if nCodons == 0
    text = '';
    unknown = 0;
    return
end

block = reshape(nt(1:4 * nCodons), 4, nCodons).';

decodable = all(ismember(block, 'ACGT'), 2);

idx = zeros(nCodons, 1);
if any(decodable)
    idx(decodable) = cb.codon2idx(codonToIndex(block(decodable, :)));
end

known = idx > 0;
unknown = sum(~known);

if isempty(placeholder)
    text = char(cb.codePoints(idx(known)));
else
    text = repmat(placeholder, 1, nCodons);
    text(known) = char(cb.codePoints(idx(known)));
end

text = reshape(text, 1, []);
end
