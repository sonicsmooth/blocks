def topo_sort(dag):
    # dag is dict {(from, to):weight,...}
    # Kahn's algorithm https://en.wikipedia.org/wiki/Topological_sorting
    # Assume node 0 is the only node that exists.
    # Assume node 0 is the only node that has no incoming edges
    L = []
    S = set([0])
    # take edges only, don't care about weights
    edges = list(dag.keys())
    while(S):
        n = S.pop()
        L.append(n)
        n_edges = [e for e in edges if e[0] == n]
        ems = [e[1] for e in n_edges]
        for m in ems:
            edges.remove((n,m))
            edges_with_m_as_target = [e for e in edges if e[1] == m]
            if not edges_with_m_as_target:
                S.add(m)
    return L

def between(x0, x1, y):
    # Returns true if y is between x0 and x1
    return y >= x0 and y <= x1

def within_y(r1, r2):
    # y0 +------+ 
    #    |      |  +----+
    #    |  r1  |  | r2 |  -> over
    #    |      |  +----+
    # y1 +------+ 
    #
    #            +------+  
    # y0 +----+  |      | 
    #    | r1 |  |  r2  |  -> under
    # y1 +----+  |      | 
    #            +------+  
    #
    # y0 +------+ 
    #    |      |  
    #    |  r1  |          -> partial
    #    |      |  +----+
    # y1 +------+  | r2 |
    #              +----+
    # Return 'over' if r2 is fully overlapped by r1
    # Return 'under' if r1 is fully overlapped by r2
    # Return 'partial' if r2 is partially overlapped by r1
    # Return None if there is no overlap between r1 and r2
    r1y0 = r1['pos'].y()
    r1y1 = r1['pos'].y() + r1['size'].height()
    r2y0 = r2['pos'].y()
    r2y1 = r2['pos'].y() + r2['size'].height()
    if r2y0 >= r1y0 and r2y1 <= r1y1:
        return 'over'
    elif r1y0 >= r2y0 and r1y1 <= r2y1:
        return 'under'
    elif between(r1y0, r1y1, r2y0)  or \
         between(r1y0, r1y1, r2y1):
        return 'partial'
    else:
        return None
    
def shadow(r1, r2):
    return bool(within_y(r1, r2))
