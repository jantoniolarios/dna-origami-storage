function list = listStructures(folder)
%LISTSTRUCTURES  Cataloga los archivos .top disponibles en una carpeta.
%
%   list = LISTSTRUCTURES() busca en la carpeta structures/ del repositorio.
%   list = LISTSTRUCTURES(folder) busca en la carpeta indicada.
%
%   Devuelve un array de estructuras con los campos name, filename, nStaples,
%   capacityLayer1 y capacityLayer2, ordenado alfabéticamente por nombre.

if nargin < 1 || isempty(folder)
    folder = fullfile(projectRoot(), 'structures');
end
if isstring(folder)
    folder = char(folder);
end

if exist(folder, 'dir') ~= 7
    error('listStructures:noFolder', 'No existe la carpeta "%s".', folder);
end

files = dir(fullfile(folder, '*.top'));
files = files(~[files.isdir]);

list = struct('name', {}, 'filename', {}, 'nStaples', {}, ...
    'capacityLayer1', {}, 'capacityLayer2', {});

for k = 1:numel(files)
    full = fullfile(files(k).folder, files(k).name);
    try
        info = topologyInfo(readTopology(full));
    catch err
        warning('listStructures:unreadable', ...
            'Se omite "%s": %s', files(k).name, err.message);
        continue
    end
    [~, stem] = fileparts(files(k).name);
    list(end + 1) = struct( ...
        'name',           stem, ...
        'filename',       full, ...
        'nStaples',       info.nStaples, ...
        'capacityLayer1', info.capacityLayer1, ...
        'capacityLayer2', info.capacityLayer2); %#ok<AGROW>
end

if ~isempty(list)
    [~, order] = sort(lower({list.name}));
    list = list(order);
end
end
