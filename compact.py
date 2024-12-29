import copy
from pprint import pprint

# https://people.eecs.berkeley.edu/~keutzer/classes/244fa2005/lectures/5-1-compaction.pdf
# https://blog.finxter.com/5-best-ways-to-find-the-length-of-the-longest-path-in-a-dag-without-repeated-nodes-in-python/
# https://class.ece.uw.edu/541/hauck/lectures/11_Compaction.pdf

def sort_rects(rects, ids, keyfn, reverse=False):
    # from list of rects, select ids and sort 
    # using keyfn ascending or descending
    # return sorted ids
    chosen_rects = [r for r in rects if r['id'] in ids]
    sorted_rects = sorted(chosen_rects, key=keyfn, reverse=reverse)
    sorted_ids = [r['id'] for r in sorted_rects]
    return sorted_ids

def compose_graph(lines, rects, dim, reverse=False, offset=0):
    # lines comes from scanlines_[xy][leftright](...)
    # The graph represents distances from the reference
    # So it doesn't know about rightmost, etc.
    # The reverse flag just adds the dst width/height
    graph = {}
    if   dim == 'x': wh = lambda rect: rect['size'].width()
    elif dim == 'y': wh = lambda rect: rect['size'].height()
    for line in lines:
        ids = line['sorted']
        src = 0
        dst = ids[0]
        ge = (src, dst)
        if ge not in graph:
            if not reverse:
                graph[ge] = 0
            else:
                graph[ge] = wh(rects[dst])
        src = dst
        for dst in ids[1:]:
            aligned = src in line['top'] and dst in line['bot'] or \
                      src in line['bot'] and dst in line['top']
            #aligned = False
            if not aligned:
                ge = (src, dst)
                if ge not in graph:
                    if not reverse:
                        graph[ge] = wh(rects[src]) # push left/top
                    else:
                        graph[ge] = wh(rects[dst]) # push right/bottom
            src = dst
    return graph                    

def scanlines(rects, axis, reverse=False):
    # rects is list of rectangles
    # Returns list of dicts with edge information
    # Each dict has position and top, mid, bot lists of rect IDs
    # that match that position
    # [{pos:..., 'top':[...], 'mid':[...], 'bot':[...]}, ...]

    #                              top   mid    bot     graph
    #  5  ┌─10┐                     1                   0->1
    # 10  │   │   ┌──15─┐  ┌──15─┐  2,4   1             0->1, 1->2, 2->4
    # 15  │   │   │     │  │  4  │             
    # 20  │   │   │  2  │  ├──15─┤  3    1,2     4      0->1, 1->2, 2->3, 2->4
    # 25  │ 1 │   │     │  │     │         
    # 30  │   │   └─────┘  │  3  │       1,3     2      0->1, 1->2, 2->3
    # 35  │   │            │     │  
    # 40  │   │            └─────┘        1      3      0->1, 1->3
    # 45  └───┘                                  1      0->1
    # 50          ┌─15─┐            5                   0->5
    # 55          │ 5  │     
    # 60          └────┘                         5      0->5

    if axis == 'x':
        prim_pos = lambda rect: rect['pos'].x()
        prim_sz  = lambda rect: rect['size'].width()
        sec_pos  = lambda rect: rect['pos'].y()
        sec_sz   = lambda rect: rect['size'].height()
    elif axis == 'y':
        prim_pos = lambda rect: rect['pos'].y()
        prim_sz  = lambda rect: rect['size'].height()
        sec_pos  = lambda rect: rect['pos'].x()
        sec_sz   = lambda rect: rect['size'].width()

    top_edges = [{'id':r['id'], 'pos':sec_pos(r),             'tb':'top'} for r in rects]
    bot_edges = [{'id':r['id'], 'pos':sec_pos(r) + sec_sz(r), 'tb':'bot'} for r in rects]
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
            line['mid'].extend(line['top'])
            line['top'].clear()

        if typ == 'bot' and id in line['mid']:
            line['mid'].remove(id)
        line[typ].append(id)

        line['sorted'] = line['top'] + line['mid'] + line['bot']
        if len(line['sorted']) > 1:
            #srtd = sort_rects(rects, line['sorted'], keyfn=lambda r:r['pos'].x(), reverse=reverse)
            srtd = sort_rects(rects, line['sorted'], keyfn=prim_pos, reverse=reverse)
            line['sorted'][:] = srtd[:]
        lastpos = pos
    lines.append(copy.deepcopy(line))
    return lines



def make_graph(rects, axis, reverse=False):
    # Returns DAG = {(from_node, to_node): weight, ...}
    # rects is db of rectangles
    # axis is either 'x' or 'y'
    # reverse puts blocks to the right (if 'x') or bottom (if 'y')
    lines = scanlines(rects, axis, reverse)
    graph = compose_graph(lines, rects, axis, reverse)
    return graph



def longest_path_bellman_ford(graph):
    MINDIST = 0
    nodes = set()
    for edge in graph.keys():
        nodes.add(edge[0])
        nodes.add(edge[1])
    num_nodes = len(nodes)
    dist = [float('-inf')] * num_nodes
    dist[0] = 0  # Assuming 0 is the start node

    # looks like O(num_nodes * num_edges)
    for _ in range(num_nodes - 1):
        for (frm, to), weight in graph.items():
            weight += MINDIST
            if dist[frm] != float('-inf') and dist[frm] + weight > dist[to]:
                dist[to] = dist[frm] + weight
    return dist
