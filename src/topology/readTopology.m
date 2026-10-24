function top = readTopology(filename)
%READTOPOLOGY  Lee un archivo de topología oxDNA (.top).
%
%   top = READTOPOLOGY(filename) devuelve una estructura con:
%     top.nNucleotides - número de nucleótidos declarado en la cabecera
%     top.nStrands     - número de hebras declarado en la cabecera
%     top.strand       - Nx1 índice de hebra de cada nucleótido
%     top.base         - Nx1 char con la base (A, C, G, T)
%     top.neighbor3    - Nx1 índice del vecino en dirección 3' (-1 = extremo)
%     top.neighbor5    - Nx1 índice del vecino en dirección 5' (-1 = extremo)
%     top.filename     - ruta del archivo leído

if isstring(filename)
    filename = char(filename);
end
if exist(filename, 'file') ~= 2
    error('readTopology:notFound', 'No se encontró el archivo "%s".', filename);
end

txt = fileread(filename);
lines = regexp(txt, '\r\n|\n|\r', 'split');

keep = ~cellfun(@(s) isempty(strtrim(s)), lines);
lines = lines(keep);

if isempty(lines)
    error('readTopology:emptyFile', 'El archivo "%s" está vacío.', filename);
end

hdr = sscanf(lines{1}, '%d %d');
if numel(hdr) < 2
    error('readTopology:badHeader', ...
        'La primera línea de "%s" no tiene el formato "N Ns".', filename);
end

body = lines(2:end);
n = numel(body);

[strand, base, n3, n5, ok] = parseFast(body);
if ~ok
    [strand, base, n3, n5] = parseRobust(body, filename);
end

top.nNucleotides = double(hdr(1));
top.nStrands     = double(hdr(2));
top.strand       = strand;
top.base         = base;
top.neighbor3    = n3;
top.neighbor5    = n5;
top.filename     = filename;

if n ~= top.nNucleotides
    error('readTopology:countMismatch', ...
        ['La cabecera de "%s" declara %d nucleótidos pero el archivo contiene ' ...
         '%d filas de datos.'], filename, top.nNucleotides, n);
end
if max(top.strand) ~= top.nStrands
    error('readTopology:strandMismatch', ...
        ['La cabecera de "%s" declara %d hebras pero el índice de hebra máximo ' ...
         'encontrado es %d.'], filename, top.nStrands, max(top.strand));
end
if any(top.strand < 1)
    error('readTopology:badStrand', ...
        'El archivo "%s" contiene índices de hebra menores que 1.', filename);
end
end
 
function [strand, base, n3, n5, ok] = parseFast(body)
strand = []; base = ''; n3 = []; n5 = []; ok = false;

joined = strjoin(body, newline);
c = textscan(joined, '%f %s %f %f', 'Whitespace', ' \t', 'EndOfLine', newline);

n = numel(body);
if numel(c{1}) ~= n || numel(c{2}) ~= n || numel(c{3}) ~= n || numel(c{4}) ~= n
    return
end

letters = c{2};
if any(cellfun(@numel, letters) ~= 1)
    return   
end

strand = c{1}(:);
base   = char(letters);
base   = base(:);
n3     = c{3}(:);
n5     = c{4}(:);
ok     = true;
end

function [strand, base, n3, n5] = parseRobust(body, filename)
n = numel(body);
strand = zeros(n, 1);
base   = repmat(' ', n, 1);
n3     = zeros(n, 1);
n5     = zeros(n, 1);

for k = 1:n
    f = regexp(strtrim(body{k}), '\s+', 'split');
    if numel(f) < 4
        error('readTopology:badRow', ...
            'La fila %d de "%s" tiene %d campos; se esperaban al menos 4.', ...
            k, filename, numel(f));
    end
    strand(k) = str2double(f{1});
    base(k)   = f{2}(1);
    n3(k)     = str2double(f{3});
    n5(k)     = str2double(f{4});
end

if any(isnan(strand)) || any(isnan(n3)) || any(isnan(n5))
    bad = find(isnan(strand) | isnan(n3) | isnan(n5), 1);
    error('readTopology:badRow', ...
        'La fila %d de "%s" tiene campos numéricos no válidos.', bad, filename);
end
end
