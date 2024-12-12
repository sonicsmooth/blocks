

# https://people.eecs.berkeley.edu/~keutzer/classes/244fa2005/lectures/5-1-compaction.pdf
# https://blog.finxter.com/5-best-ways-to-find-the-length-of-the-longest-path-in-a-dag-without-repeated-nodes-in-python/
# https://class.ece.uw.edu/541/hauck/lectures/11_Compaction.pdf




def sort_rects(rects, ids, key, reverse=False):
    # from list of rects, sort from left to right
    chosen_rects = [r for id, r in rects.items() if id in ids]
    sorted_rects = sorted(chosen_rects, key=key, reverse=reverse)
    sorted_ids = [r['id'] for r in sorted_rects]
    return sorted_ids

def compose_graph(active_edges, rects, dir):
    graph = {}
    for ae in active_edges:
        sorted_edges = ae['sorted']
        ge = (0, sorted_edges[0])
        if ge not in graph:
            graph[ge] = 0
        last_e = sorted_edges[0]
        for e in sorted_edges[1:]:
            ge = (last_e, e)
            if ge not in graph:
                if dir == 'x':
                    graph[ge] = rects[last_e]['size'].width()
                elif dir == 'y':
                    graph[ge] = rects[last_e]['size'].height()
            last_e = e
    return graph                    

def update_graph_xleft(rects):
    # Returns DAG = {(from_node, to_node): weight, ...}
    # Scan line top-to-bottom, keep track of vertical edges that intersect
    # Lists of top and bottom edges, then combine and sort
    tops = [{'y':r['pos'].y()                     , 'id':r['id'], 'tb':'top'} for r in rects.values()]
    bots = [{'y':r['pos'].y() + r['size'].height(), 'id':r['id'], 'tb':'bot'} for r in rects.values()]
    sorted_edges = sorted(tops+bots, key=lambda e: e['y'])

    active_edges = [] # [{'y':, 'ids':[...]}, ...]
    edge_count = {e['id']:0 for e in sorted_edges}

    for edge in sorted_edges:
        y   = edge['y']
        id  = edge['id']
        edge_count[edge['id']] += 1
        
        if active_edges:
            # Remove edges that aren't at this edge and that already have 2 entries
            last_ids = active_edges[-1]['ids'][:]
            for lid in last_ids:
                if edge_count[lid] == 2 and lid != id:
                    last_ids.remove(lid)
            if edge['tb'] == 'top':
                last_ids.append(id)
            tmp_edges = {'y': y, 'ids': last_ids}
            tmp_edges['sorted'] = sort_rects(rects, tmp_edges['ids'], 
                                             key=lambda x: x['pos'].x(), 
                                             reverse=False)
            if y == active_edges[-1]['y']:
                active_edges.pop()
            active_edges.append(tmp_edges)
        else:
            tmp_edges = {'y':y, 'ids':[id], 'sorted':[id]}
            active_edges.append(tmp_edges)
    graph = compose_graph(active_edges, rects, 'x')
    return graph

def update_graph_xright(rects):
    # Returns DAG = {(from_node, to_node): weight, ...}
    # Scan line top-to-bottom, keep track of vertical edges that intersect
    # Lists of top and bottom edges, then combine and sort
    tops = [{'y':r['pos'].y()                     , 'id':r['id'], 'tb':'top'} for r in rects.values()]
    bots = [{'y':r['pos'].y() + r['size'].height(), 'id':r['id'], 'tb':'bot'} for r in rects.values()]
    sorted_edges = sorted(tops+bots, key=lambda e: e['y'])

    active_edges = [] # [{'y':, 'ids':[...]}, ...]
    edge_count = {e['id']:0 for e in sorted_edges}

    for edge in sorted_edges:
        y   = edge['y']
        id  = edge['id']
        edge_count[edge['id']] += 1
        
        if active_edges:
            # Remove edges that aren't at this edge and that already have 2 entries
            last_ids = active_edges[-1]['ids'][:]
            for lid in last_ids:
                if edge_count[lid] == 2 and lid != id:
                    last_ids.remove(lid)
            if edge['tb'] == 'top':
                last_ids.append(id)
            tmp_edges = {'y': y, 'ids': last_ids}
            tmp_edges['sorted'] = sort_rects(rects, tmp_edges['ids'], 
                                             key=lambda x: x['pos'].x() + x['size'].width(), 
                                             reverse=True)
            if y == active_edges[-1]['y']:
                active_edges.pop()
            active_edges.append(tmp_edges)
        else:
            tmp_edges = {'y':y, 'ids':[id], 'sorted':[id]}
            active_edges.append(tmp_edges)
    graph = compose_graph(active_edges, rects, 'x')
    return graph

def update_graph_yup(rects):
    # Returns DAG = {(from_node, to_node): weight, ...}
    # Scan line top-to-bottom, keep track of vertical edges that intersect
    # Lists of top and bottom edges, then combine and sort
    lefts  = [{'x':r['pos'].x()                    , 'id':r['id'], 'lr':'left' } for r in rects.values()]
    rights = [{'x':r['pos'].x() + r['size'].width(), 'id':r['id'], 'lr':'right'} for r in rects.values()]
    sorted_edges = sorted(lefts+rights, key=lambda e: e['x'])

    active_edges = [] # [{'x':, 'ids':[...]}, ...]
    edge_count = {e['id']:0 for e in sorted_edges}

    for edge in sorted_edges:
        x   = edge['x']
        id  = edge['id']
        edge_count[edge['id']] += 1
        
        if active_edges:
            # Remove edges that aren't at this edge and that already have 2 entries
            last_ids = active_edges[-1]['ids'][:]
            for lid in last_ids:
                if edge_count[lid] == 2 and lid != id:
                    last_ids.remove(lid)
            if edge['lr'] == 'left':
                last_ids.append(id)
            tmp_edges = {'x': x, 'ids': last_ids}
            tmp_edges['sorted'] = sort_rects(rects, tmp_edges['ids'],
                                              key=lambda x: x['pos'].y(),
                                              reverse=False)
            if x == active_edges[-1]['x']:
                active_edges.pop()
            active_edges.append(tmp_edges)
        else:
            tmp_edges = {'x':x, 'ids':[id], 'sorted':[id]}
            active_edges.append(tmp_edges)
    graph = compose_graph(active_edges, rects, 'y')
    return graph

def update_graph_ydn(rects):
    # Returns DAG = {(from_node, to_node): weight, ...}
    # Scan line top-to-bottom, keep track of vertical edges that intersect
    # Lists of top and bottom edges, then combine and sort
    lefts  = [{'x':r['pos'].x()                    , 'id':r['id'], 'lr':'left' } for r in rects.values()]
    rights = [{'x':r['pos'].x() + r['size'].width(), 'id':r['id'], 'lr':'right'} for r in rects.values()]
    sorted_edges = sorted(lefts+rights, key=lambda e: e['x'])

    active_edges = [] # [{'x':, 'ids':[...]}, ...]
    edge_count = {e['id']:0 for e in sorted_edges}

    for edge in sorted_edges:
        x   = edge['x']
        id  = edge['id']
        edge_count[edge['id']] += 1
        
        if active_edges:
            # Remove edges that aren't at this edge and that already have 2 entries
            last_ids = active_edges[-1]['ids'][:]
            for lid in last_ids:
                if edge_count[lid] == 2 and lid != id:
                    last_ids.remove(lid)
            if edge['lr'] == 'left':
                last_ids.append(id)
            tmp_edges = {'x': x, 'ids': last_ids}
            tmp_edges['sorted'] = sort_rects(rects, 
                                             tmp_edges['ids'], 
                                             key=lambda x: x['pos'].y() + x['size'].width(),
                                             reverse=True)
            if x == active_edges[-1]['x']:
                active_edges.pop()
            active_edges.append(tmp_edges)
        else:
            tmp_edges = {'x':x, 'ids':[id], 'sorted':[id]}
            active_edges.append(tmp_edges)
    graph = compose_graph(active_edges, rects, 'y')
    return graph

def longest_path_bellman_ford(graph):
    MINDIST = 0
    edges = graph.keys()
    nodes = set()
    for edge in edges:
        nodes.add(edge[0])
        nodes.add(edge[1])
    num_nodes = len(nodes)
    dist = [float('-inf')] * num_nodes
    dist[0] = 0  # Assuming 0 is the start node

    # looks like O(num_nodes * num_edges)
    for _ in range(num_nodes - 1):
        for frm, to in edges:
            weight = graph[(frm,to)] + MINDIST
            if dist[frm] != float('-inf') and dist[frm] + weight > dist[to]:
                dist[to] = dist[frm] + weight
    return dist

# This one works, but you still have to subtract
# the width of the rectangle as newpos = pos - rect['size'].width()
# So we'll just use the default one and do the extra math
# def longest_path_bellman_ford_xright(graph, maxx):
#     MINDIST = 0
#     edges = graph.keys()
#     nodes = set()
#     for edge in edges:
#         nodes.add(edge[0])
#         nodes.add(edge[1])
#     num_nodes = len(nodes)
#     dist = [float('+inf')] * num_nodes
#     dist[0] = maxx  # [0] is the start node at far right

#     # looks like O(num_nodes * num_edges)
#     for _ in range(num_nodes - 1):
#         for frm, to in edges:
#             weight = graph[(frm,to)] + MINDIST
#             if dist[frm] != float('+inf') and dist[frm] - weight < dist[to]:
#                 dist[to] = dist[frm] - weight
#     return dist
