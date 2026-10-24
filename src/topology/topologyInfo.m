function info = topologyInfo(top)
%TOPOLOGYINFO  Resumen y capacidad de almacenamiento de una topología.
%
%   info = TOPOLOGYINFO(top) devuelve una estructura con:
%     info.nNucleotides   - nucleótidos totales
%     info.nStrands       - número de hebras
%     info.nScaffold      - nucleótidos del scaffold (hebra 1)
%     info.nStaples       - nucleótidos de staples (hebras 2+)
%     info.firstStaple    - índice del primer nucleótido de staple
%     info.capacityLayer1 - caracteres almacenables sin la capa 2
%     info.capacityLayer2 - caracteres almacenables con la capa 2

idx = stapleIndices(top);

info.nNucleotides = top.nNucleotides;
info.nStrands     = top.nStrands;
info.nScaffold    = sum(top.strand == 1);
info.nStaples     = numel(idx);
info.firstStaple  = idx(1);

nMarkerCodons = 4;
info.capacityLayer1 = max(0, floor(info.nStaples / 4) - nMarkerCodons);
info.capacityLayer2 = max(0, floor(info.nStaples / 8) - nMarkerCodons);
end
