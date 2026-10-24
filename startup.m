% STARTUP  Prepara el path de MATLAB para este proyecto.
%
%       >> cd ruta/al/repositorio
%       >> startup


addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'output')));
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'scripts')));
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'seq2seq')));
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'src')));
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'structures')));
fprintf('Proyecto DNA origami storage listo. Scripts disponibles:\n');
fprintf('  encodeToStructure   - codifica un texto dentro de una estructura\n');
fprintf('  decodeFromStructure - recupera el texto de una estructura\n');
fprintf('  decodeChain         - decodifica una cadena guardada en output/\n');
fprintf('  runTests            - ejecuta la batería de pruebas\n');
