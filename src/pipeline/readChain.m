function [nt, metadata] = readChain(filename)
%READCHAIN  Lee una cadena de nucleótidos guardada con WRITECHAIN.
%
%   nt = READCHAIN(filename) devuelve la cadena, descartando las líneas de
%   comentario y cualquier carácter que no sea A, C, G o T.
%
%   [nt, metadata] = READCHAIN(filename) devuelve además los campos de la
%   cabecera como una estructura.

if isstring(filename)
    filename = char(filename);
end
if exist(filename, 'file') ~= 2
    error('readChain:notFound', 'No se encontró el archivo "%s".', filename);
end

txt = fileread(filename);
lines = regexp(txt, '\r\n|\n|\r', 'split');

metadata = struct();
pieces = {};

for k = 1:numel(lines)
    line = strtrim(lines{k});
    if isempty(line)
        continue
    end

    if line(1) == '#'
        tokens = regexp(line, '^#\s*([^:]+):\s*(.*)$', 'tokens', 'once');
        if numel(tokens) == 2
            campo = matlab.lang.makeValidName(strtrim(tokens{1}));
            metadata.(campo) = strtrim(tokens{2});
        end
        continue
    end

    pieces{end + 1} = line; %#ok<AGROW>
end

nt = [pieces{:}];
nt = nt(ismember(nt, 'ACGT'));

if isempty(nt)
    error('readChain:empty', ...
        'El archivo "%s" no contiene ninguna base A, C, G o T.', filename);
end
end
