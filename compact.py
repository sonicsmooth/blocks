import copy
from pprint import pprint

# https://people.eecs.berkeley.edu/~keutzer/classes/244fa2005/lectures/5-1-compaction.pdf
# https://blog.finxter.com/5-best-ways-to-find-the-length-of-the-longest-path-in-a-dag-without-repeated-nodes-in-python/
# https://class.ece.uw.edu/541/hauck/lectures/11_Compaction.pdf

def lookup_rect(rects, id):
    for r in rects:
        if r['id'] == id:
            return r
    return None

def sort_rects(rects, ids, keyfn, reverse=False):
    # from list of rects, select ids and sort 
    # using keyfn ascending or descending
    # return sorted ids
    chosen_rects = [r for r in rects if r['id'] in ids]
    sorted_rects = sorted(chosen_rects, key=keyfn, reverse=reverse)
    sorted_ids = [r['id'] for r in sorted_rects]
    return sorted_ids

def compose_graph(active_edges, rects, dir):
    graph = {}
    for ae in active_edges:
        edges = ae['sorted']
        ge = (0, edges[0])
        if ge not in graph:
            graph[ge] = 0
        last_e = edges[0]
        for e in edges[1:]:
            ge = (last_e, e)
            if ge not in graph:
                if dir == 'x':
                    graph[ge] = lookup_rect(rects, last_e)['size'].width()
                elif dir == 'y':
                    graph[ge] = lookup_rect(rects, last_e)['size'].height()
            last_e = e
    return graph                    

def compose_graph_new(lines, rects, dir):
    # lines comes from scanlines_[xy][leftright](...)
    graph = {}
    for line in lines:
        ids = line['sorted']
        src = 0
        dst = ids[0]
        ge = (src, dst)
        if ge not in graph:
            graph[ge] = 0
        src = dst
        for dst in ids[1:]:
            aligned = src in line['top'] and dst in line['bot'] or \
                      src in line['bot'] and dst in line['top']
            if not aligned:
                ge = (src, dst)
                if ge not in graph:
                    if dir == 'x':
                        graph[ge] = lookup_rect(rects, src)['size'].width()
                    elif dir == 'y':
                        graph[ge] = lookup_rect(rects, src)['size'].height()
            src = dst
    return graph                    

def active_edges_xleft(rects):
    tops = [{'pos':r['pos'].y()                     , 'id':r['id'], 'tb':'top'} for r in rects]
    bots = [{'pos':r['pos'].y() + r['size'].height(), 'id':r['id'], 'tb':'bot'} for r in rects]
    edges = sorted(tops + bots, key=lambda edge: edge['pos'])

    active_edges = [] # [{'y':, 'ids':[...]}, ...]
    edge_count = {e['id']:0 for e in edges}

    for edge in edges:
        pos = edge['pos']
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
            tmp_edges = {'pos': pos, 'ids': last_ids}
            tmp_edges['sorted'] = sort_rects(rects, tmp_edges['ids'], 
                                                 keyfn=lambda rect: rect['pos'].x(), 
                                                 reverse=False)
            if pos == active_edges[-1]['pos']:
                active_edges.pop()
            active_edges.append(tmp_edges)
        else:
            tmp_edges = {'pos':pos, 'ids':[id], 'sorted':[id]}
            active_edges.append(tmp_edges)
    for ae in active_edges: del ae['ids']
    return active_edges

def scanlines_xleft(rects):
    # rects is list of rectangles
    # Returns list of dicts with edge information
    # Each dict has position and top, mid, bot lists of rect IDs
    # that match that position
    # [{pos:..., 'top':[...], 'mid':[...], 'bot':[...]}, ...]

    #                               top   mid    bot     graph
    #  5  ┌───┐                      1                   0->1
    # 10  │   │   ┌──────┐  ┌─────┐  2,4   1             0->1, 1->2, 2->4
    # 15  │   │   │      │  │  4  │             
    # 20  │   │   │  2   │  ├─────┤  3    1,2     4      0->1, 1->2, 2->3, 2->4
    # 25  │ 1 │   │      │  │     │         
    # 30  │   │   └──────┘  │  3  │       1,3     2      0->1, 1->2, 2->3
    # 35  │   │             │     │  
    # 40  │   │             └─────┘        1      3      0->1, 1->3
    # 45  └───┘                                   1      0->1
    # 50           ┌────┐            5                   0->5
    # 55           │ 5  │     
    # 60           └────┘                        5       0->5

    top_edges = [{'id':r['id'], 'pos':r['pos'].y(), 'tb':'top'} for r in rects]
    bot_edges = [{'id':r['id'], 'pos':r['pos'].y()+r['size'].height(), 'tb':'bot'} for r in rects]
    edges = sorted(top_edges + bot_edges, key=lambda edge: edge['pos'])

    # Prime everything with first edge
    edge = edges[0]
    line = {'pos': edge['pos'], 'top':[], 'mid':[], 'bot':[], 'sorted':[edge['id']]}
    line[edge['tb']] = [edge['id']]
    lastpos = edge['pos']

    # Go through each edge.
    # Push accumulated line when next line detected
    lines = []
    for edge in edges[1:]:
        pos = edge['pos']
        id  = edge['id']
        typ = edge['tb']
        if pos > lastpos: # down one edge
            lines.append(copy.deepcopy(line))
            line['pos'] = pos
            line['bot'].clear()
            line['mid'].extend(line['top']) # alternate: insert-sorted
            line['top'].clear()

        if typ == 'bot' and id in line['mid']:
            line['mid'].remove(id)
        line[typ].append(id)

        line['sorted'] = line['top'] + line['mid'] + line['bot']
        if len(line['sorted']) > 1:
            srtd = sort_rects(rects, line['sorted'], keyfn=lambda r:r['pos'].x())
            line['sorted'][:] = srtd[:]
        lastpos = pos
    lines.append(copy.deepcopy(line))
    return lines


def update_graph_xleft(rects):
    # Returns DAG = {(from_node, to_node): weight, ...}
    # Scan line top-to-bottom, keep track of vertical edges that intersect
    # Lists of top and bottom edges, then combine and sort

    lines = scanlines_xleft(rects)
    ae = active_edges_xleft(rects)
    
    graph1 = compose_graph_new(lines, rects, 'x')
    graph2 = compose_graph(ae, rects, 'x')
    
    return graph1

def update_graph_xright(rects):
    # Returns DAG = {(from_node, to_node): weight, ...}
    # Scan line top-to-bottom, keep track of vertical edges that intersect
    # Lists of top and bottom edges, then combine and sort
    tops = [{'y':r['pos'].y()                     , 'id':r['id'], 'tb':'top'} for r in rects.values()]
    bots = [{'y':r['pos'].y() + r['size'].height(), 'id':r['id'], 'tb':'bot'} for r in rects.values()]
    edges = sorted(tops+bots, key=lambda e: e['y'])

    active_edges = [] # [{'y':, 'ids':[...]}, ...]
    edge_count = {e['id']:0 for e in edges}

    for edge in edges:
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
                                                keyfn=lambda x: x['pos'].x() + x['size'].width(), 
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
    edges = sorted(lefts+rights, key=lambda e: e['x'])

    active_edges = [] # [{'x':, 'ids':[...]}, ...]
    edge_count = {e['id']:0 for e in edges}

    for edge in edges:
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
                                                 keyfn=lambda x: x['pos'].y(),
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
    edges = sorted(lefts+rights, key=lambda e: e['x'])

    active_edges = [] # [{'x':, 'ids':[...]}, ...]
    edge_count = {e['id']:0 for e in edges}

    for edge in edges:
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
