function writeTopology(top, filename)
%WRITETOPOLOGY  Escribe una estructura de topología a un archivo .top.
%
%   WRITETOPOLOGY(top, filename) guarda top en formato oxDNA: una cabecera
%   "N Ns" seguida de una línea por nucleótido con "hebra base 3' 5'".
%
%   Las columnas 1, 3 y 4 se reescriben tal cual se leyeron: solo cambia la
%   columna de bases si quien llama la modificó.

if isstring(filename)
    filename = char(filename);
end

requiredFields = {'nNucleotides', 'nStrands', 'strand', 'base', 'neighbor3', 'neighbor5'};
missing = requiredFields(~isfield(top, requiredFields));
if ~isempty(missing)
    error('writeTopology:badStruct', ...
        'A la estructura de topología le faltan los campos: %s.', strjoin(missing, ', '));
end

n = numel(top.strand);
if numel(top.base) ~= n || numel(top.neighbor3) ~= n || numel(top.neighbor5) ~= n
    error('writeTopology:lengthMismatch', ...
        'Los campos de la topología tienen longitudes distintas.');
end

outDir = fileparts(filename);
if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

fid = fopen(filename, 'w');
if fid < 0
    error('writeTopology:cannotOpen', 'No se pudo escribir en "%s".', filename);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '%d %d\n', top.nNucleotides, top.nStrands);

rows = [ ...
    double(top.strand(:)).'; ...
    double(top.base(:)).'; ...
    double(top.neighbor3(:)).'; ...
    double(top.neighbor5(:)).'];

fprintf(fid, '%d %c %d %d\n', rows);
end
