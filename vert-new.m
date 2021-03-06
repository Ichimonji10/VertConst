%terms = [3 2 1 4 1 0 2 4;
 %        1 2 1 3 2 1 0 1];
%terms = [4 3 2 1; 2 1 3 4];
%terms = [4 1 0 4 2; 3 2 3 4 1];
terms = [7 6 8 5 7 2 4 5 1 3 0; 0 3 4 1 7 6 8 0 0 2 9];

NumOfCols = size(terms,2);
HighestNet = max(terms(1,:));
AdjMatr = zeros(HighestNet,HighestNet);

%creates adjacency matrix
for ColCheck = 1:NumOfCols
    if (terms(1,ColCheck) ~= 0) && (terms(2,ColCheck) ~= 0) && (terms(1,ColCheck) ~= terms(2,ColCheck))
        AdjMatr(terms(1,ColCheck),terms(2,ColCheck)) = 1;
    end
end

AdjMatr

VertGraph = [];

%top constraints that are not bottom constraints placed at top of graph
for PlaceTop = 1:HighestNet
    if (AdjMatr(:,PlaceTop) == zeros(HighestNet,1))
        VertGraph = [PlaceTop; VertGraph];
    end
end

%bottom constraints that are not top constraints placed at bottom of graph
for PlaceBott = 1:HighestNet
    if (AdjMatr(PlaceBott,:) == zeros(1,HighestNet))
        %stops from placing non-vertical constrained net twice
        if (AdjMatr(:,PlaceBott) ~= zeros(HighestNet,1))
            VertGraph = [VertGraph; PlaceBott];
        end
    end
end

CurrTop = [];
CuttBott = [];

%this section fills the remainder of the vertical graph

%row of AdjMatr
for CurrTop = 1:HighestNet
    %column of AdjMatr
    for CurrBott = 1:HighestNet
        %finds vertical constraints
        if (AdjMatr(CurrTop,CurrBott) == 1)
            %position of constraints currently in graph
            %if constraint is not in graph, = []
            PosOfTop = find(VertGraph == CurrTop);
            PosOfBott = find(VertGraph == CurrBott);
            
            %top constraint is already in VertGraph
            if (~isempty(PosOfTop))
            
                %bottom is in graph, above the top
                if (PosOfTop > PosOfBott)
                    %remove bottom constraint from graph
                    VertGraph([PosOfBott,:]) = [];
                    %PosOfTop needs to recalculated
                    PosOfTop = find(VertGraph == CurrTop);
                    %places bottom constraint below top in graph
                    VertGraph = [VertGraph(1:PosOfTop,:); CurrBott; VertGraph(PosOfTop+1:end,:)];
                %bottom is not in graph
                elseif (isempty(PosOfBott));
                    %places bottom constraint below top in graph
                    VertGraph = [VertGraph(1:PosOfTop,:); CurrBott; VertGraph(PosOfTop+1:end,:)];
                end
                
            %top not in graph, bottom is
            elseif(~isempty(PosOfBott))
                %so place top constraint above bottom in graph
                VertGraph = [VertGraph(1:PosOfBott-1,:); CurrTop; VertGraph(PosOfBott:end,:)];
            
            %neither top nor bottom is in VertGraph
            else
                %bottom constraint of last bottom constraint added
                %will check for a repeated value -> cycle
                CycleCheck = [CurrTop; CurrBott];
                finish_now = false;
                %next top
                LastBott = CurrBott;
                %repeats for number of nets
                for i = 1:HighestNet
                    %next bottom
                    for NextInCheck = 1:HighestNet
                        %get next bottom constraint
                        if (AdjMatr(LastBott,NextInCheck) == 1)
                            
                            %found next bottom constraint already in VertGraph
                            if (~isempty(find(VertGraph == NextInCheck)))
                                PosOfNext = find(VertGraph == NextInCheck);
                                %places CycleCheck in the graph above next bottom
                                VertGraph = [VertGraph(1:PosOfNext-1,:); CycleCheck; VertGraph(PosOfNext:end,:)];
                                %cleared so it is not added to bottom of VertGraph
                                CycleCheck = [];
                                finish_now = true;
                            %found next bottom contraint already in the check, ie. a cycle
                            elseif (~isempty(find(CycleCheck == NextInCheck)))
                                %add next bottom
                                CycleCheck = [CycleCheck; NextInCheck];
                                finish_now = true;
                            end
                        
                            %removes used constraints from AdjMatr
                            AdjMatr(LastBott,NextInCheck) = 0;

                            if (finish_now) break; end
                            %next bottom not found in graph or part of cycle, so add to CycleCheck
                            CycleCheck = [CycleCheck; NextInCheck];
                            %next bottom becomes former bottom
                            LastBott = NextInCheck;
                        end
                    end
                    if (finish_now) break; end
                end    
                %adds either set of new constraints or a cycle to bottom of graph
                VertGraph = [VertGraph; CycleCheck];
            end
            
            %clears the constraint from AdjMatr
            AdjMatr(CurrTop,CurrBott) = 0;
        end
    end
end

AdjMatr
VertGraph

%adds 2 columns for the intervals
VertGraph = [VertGraph, zeros(size(VertGraph,1),2)];

%row of VertGraph
for ListRow = 1:size(VertGraph,1)
    %variable for breaking out of the loops
    finish_now = false;
    %finds column where interval starts
    for StartCol = 1:NumOfCols
        %checks top and bottom terminal
        for StartRow = 1:2
            %checks if net is net in ListRow
            if (VertGraph(ListRow,1) == terms(StartRow,StartCol))
                %finds where interval ends
                for EndCol = NumOfCols:-1:StartCol
                    %checks top and bottom terminal
                    for EndRow = 1:2
                        %checks if net is net in ListRow & makes sure there is an interval
                        if (VertGraph(ListRow,1) == terms(EndRow,EndCol) && StartCol ~= EndCol)
                                VertGraph(ListRow,:) = [VertGraph(ListRow,1),StartCol,EndCol];
                                finish_now = true;
                        end
                        if (finish_now) break; end
                    end
                    if (finish_now) break; end
                end
            end
            if (finish_now) break; end
        end
        if (finish_now) break; end
    end
end

%removes nets that have no interval
for RemoveNoInt = 1:size(VertGraph,1)
    if (VertGraph(RemoveNoInt,2) == 0 && VertGraph(RemoveNoInt,3) == 0)
        VertGraph(RemoveNoInt,:) = [];
    end
end

VertGraph

%if there is a cycle, this section corrects intervals

%search to find a cycle
for CycleSearch1 = 1:size(VertGraph,1)
    for CycleSearch2 = CycleSearch1+1:size(VertGraph,1)
        finish_now = false;
        %constraint showing up twice in VertGraph
        if (VertGraph(CycleSearch1,1) == VertGraph(CycleSearch2,1))
            %adds extra column to terms on right
            terms = [terms, zeros(2,1)];
            NumOfCols = NumOfCols + 1;
            %changes the end column to new column
            VertGraph(CycleSearch1,3) = NumOfCols;
            VertGraph(CycleSearch2,3) = NumOfCols;
            
            %changes start column of top repeated net, if necessary
            for TopIntStart = 1:NumOfCols
                if (VertGraph(CycleSearch1,1) == terms(1,TopIntStart))
                    VertGraph(CycleSearch1,2) = TopIntStart;
                    finish_now = true;
                end
                if (finish_now) break; end
            end
            finish_now = false;
            
            %changes start column of bottom repeated net, if necessary
            for BottIntStart = 1:NumOfCols
                if (VertGraph(CycleSearch2,1) == terms(2,BottIntStart))
                    VertGraph(CycleSearch2,2) = BottIntStart;
                    finish_now = true;
                end
                if (finish_now) break; end
            end
            finish_now = false;
        end
    end
end
    
VertGraph

%solution matrix created with zeros in the channel
VertConSoln = [terms(1,:); zeros(size(VertGraph,1),NumOfCols);terms(2,:)];

%row that the solution is placed in
for SolnRow = 2:size(VertGraph,1)+1
    %only goes through interval
    for SolnCol = VertGraph(1,2):VertGraph(1,3)
        %sets value of the net
        VertConSoln(SolnRow,SolnCol) = VertGraph(1,1);
    end
    
    %clears net from VertGraph
    VertGraph(1,:) = [];
end

VertGraph

VertConSoln