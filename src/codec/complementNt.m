function out = complementNt(nt)
%COMPLEMENTNT  Complemento base a base de una secuencia de nucleótidos.
%
%   out = COMPLEMENTNT(nt) sustituye A<->T y C<->G conservando la forma del
%   argumento. 

if isstring(nt)
    nt = char(nt);
end

map = repmat(' ', 1, 256);
map(double('A')) = 'T';
map(double('T')) = 'A';
map(double('C')) = 'G';
map(double('G')) = 'C';

code = double(nt);
if any(code(:) > 255) || any(code(:) < 1)
    error('complementNt:badBase', 'La secuencia contiene caracteres no válidos.');
end

out = map(code);
out = reshape(out, size(nt));

if any(out(:) == ' ')
    error('complementNt:badBase', ...
        'La secuencia contiene caracteres distintos de A, C, G o T.');
end
end
