function writeChain(filename, nt, metadata)
%WRITECHAIN  Guarda una cadena de nucleótidos con su procedencia.
%
%   WRITECHAIN(filename, nt) escribe la cadena en un archivo de texto.
%   WRITECHAIN(filename, nt, metadata) añade una cabecera de comentarios con
%   los campos de la estructura metadata.

if isstring(filename)
    filename = char(filename);
end
nt = reshape(char(nt), 1, []);

outDir = fileparts(filename);
if ~isempty(outDir) && exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

fid = fopen(filename, 'w');
if fid < 0
    error('writeChain:cannotOpen', 'No se pudo escribir en "%s".', filename);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Cadena de nucleótidos - DNA origami storage\n');
fprintf(fid, '# fecha: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf(fid, '# longitud: %d nt\n', numel(nt));

if nargin >= 3 && isstruct(metadata)
    campos = fieldnames(metadata);
    for k = 1:numel(campos)
        valor = metadata.(campos{k});
        if isnumeric(valor) || islogical(valor)
            valor = num2str(valor);
        elseif isstring(valor)
            valor = char(valor);
        end
        if ischar(valor)
            fprintf(fid, '# %s: %s\n', campos{k}, valor);
        end
    end
end

fprintf(fid, '%s\n', nt);
end
