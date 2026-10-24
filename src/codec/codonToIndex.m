function idx = codonToIndex(codons)
%CODONTOINDEX  Convierte codones de 4 nt a un índice entero 1..256.
%
%   idx = CODONTOINDEX(codons) recibe una matriz Nx4 de caracteres ACGT y
%   devuelve un vector columna Nx1 con el índice base-4 de cada codón más uno
%   (A=0, C=1, G=2, T=3), apto para indexar directamente en MATLAB.
%
%   Un codón que contenga un carácter distinto de A, C, G o T produce error.

if size(codons, 2) ~= 4
    error('codonToIndex:badWidth', ...
        'Se esperaban codones de 4 nucleótidos, se recibieron de %d.', size(codons, 2));
end

value = nan(1, 256);
value(double('A')) = 0;
value(double('C')) = 1;
value(double('G')) = 2;
value(double('T')) = 3;

code = double(codons);
if any(code(:) > 255) || any(code(:) < 1)
    error('codonToIndex:badBase', 'Los codones contienen caracteres no válidos.');
end

v = value(code);
v = reshape(v, size(codons));

bad = any(isnan(v), 2);
if any(bad)
    first = find(bad, 1);
    error('codonToIndex:badBase', ...
        'El codón "%s" (fila %d) contiene caracteres distintos de A, C, G o T.', ...
        codons(first, :), first);
end

idx = v * [64; 16; 4; 1] + 1;
end
