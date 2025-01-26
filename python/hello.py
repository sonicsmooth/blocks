#!/usr/bin/python3
import sys
from PyQt6 import QtCore
from PyQt6.QtGui import *
from PyQt6.QtWidgets import *
from PyQt6.QtCore import Qt, QRect, QPoint, QSize
import random
import compact
from rectdb import Rects
from collections import namedtuple



RECTS = None
MOUSE_DATA = {} # 'ids', 'lastpos'
SELECTED = set()
WRANGE = [25, 50]
HRANGE = [25, 50]
QTY = 1000

Point = namedtuple('Point', ['x', 'y'])
Size = namedtuple('Size', ['w', 'h'])

def hittest(pos, rects):
    # Check whether pos tuple is inside any of rects
    hits = []
    for id,rect in rects.items():
        rpos = rect['pos']
        size = rect['size']
        lrcorner = Point(rpos.x + size.w, rpos.y + size.h)
        if pos.x >= rpos.x and pos.x <= lrcorner.x and \
           pos.y >= rpos.y and pos.y <= lrcorner.y:
            hits.append(id)
    return hits

def move_rect_delta(rect, delta):
    # rect is dict
    # delta is tuple
    # Updates rect coordinates in-place
    newpos = Point(rect['pos'].x + delta.x,
                   rect['pos'].y + delta.y)
    rect['pos'] = newpos

def move_rect(rect, oldpos, newpos):
    # rect is dict
    # oldpos, newpos are QPoint
    # Updates rect coordinates in-place
    dx = newpos.x - oldpos.x
    dy = newpos.y - oldpos.y
    delta = Point(dx, dy)
    move_rect_delta(rect, delta)

def PtFromEvent(event):
    pospt = event.position().toPoint() # QPoint
    pos = Point(int(pospt.x()), int(pospt.y()))
    return pos

def toggle_rect_selection(rectid):
    global RECTS
    global SELECTED
    if RECTS[rectid]['selected']:
        RECTS[rectid]['selected'] = False
        SELECTED.remove(rectid)
    else:
        RECTS[rectid]['selected'] = True
        SELECTED.add(rectid)

def clear_rect_selection():
    global RECTS
    global SELECTED
    for id in SELECTED:
        RECTS[id]['selected'] = False
    SELECTED.clear()

def create_rects_from_json(filename):
    import json
    jdict = json.load(open('rects.json', 'r'))
    rects = Rects()
    for id, rdict in jdict.items():
        rects[id] = {'id': rdict['id'],
                     'pos': Point(rdict['pos'][0],rdict['pos'][1]),
                     'size': Size(rdict['size'][0],rdict['size'][1]),
                     'selected': rdict['selected'],
                     'pencolor': tuple(rdict['pencolor']),
                     'brushcolor': tuple(rdict['brushcolor'])}
    return rects

def randcolor():
    return (random.randint(0,255),
            random.randint(0,255),
            random.randint(0,255))

def randrect(id, maxx, maxy):
    x0    = random.randint(0, maxx - WRANGE[1] - 1)
    y0    = random.randint(0, maxy - HRANGE[1] - 1)
    wrect = random.randint(WRANGE[0], WRANGE[1])
    hrect = random.randint(HRANGE[0], HRANGE[1])
    pos   = Point(x0, y0)
    size  = Size(wrect, hrect)
    rect = {'id':id, 'pos':pos, 'size':size, 'selected': False,
            'pencolor':randcolor(), 'brushcolor':randcolor()}
    return rect

def init_rects(maxx, maxy):
    # Returns dict of dicts
    # Top level dict keys is rect id
    rects = Rects()
    #r3(rects)
    for id in range(1, QTY+1):
        strid = str(id)
        rects[strid] = randrect(strid, maxx, maxy)
    return rects

def r1(rects):
    # Set up rects like in scanline comments
    r255  = lambda: random.randint(0,255)
    rects.add({'id':'4', 'pos':Point(80,10), 'size':Size(15,10), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':'3', 'pos':Point(80,20), 'size':Size(15,20), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':'2', 'pos':Point(50,10), 'size':Size(15,20), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':'1', 'pos':Point( 0, 5), 'size':Size(10,40), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':'5', 'pos':Point(50,50), 'size':Size(15,10), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})

def r2(rects):
    # Sets up another edge condition
    r255  = lambda: random.randint(0,255)
    rects.add({'id':'1', 'pos':Point(30,15),    'size':Size(100,50), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':'2', 'pos':Point(205,65),   'size':Size(80,50),  'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':'3', 'pos':Point(200, 115), 'size':Size(60,50),  'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':'4', 'pos':Point(0,0),      'size':Size(25,150), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})

def r3(rects):
    # Sets up another edge condition
    r255  = lambda: random.randint(0,255)
    rects.add({'id':'1', 'pos':Point(0, 0), 'size':Size(100, 100), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':'2', 'pos':Point(0, 0), 'size':Size(100, 100), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})


class BlockCanvas(QWidget):
    def __init__(self):
        super().__init__()
        self.setMouseTracking(True)

    def draw_rects(self, rects):
        painter = QPainter(self)
        painter.setFont(QFont('times', 20))
        painter.setPen(QPen(QColor('black')))
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        for rect in rects:
            painter.setBrush(QBrush(QColor(*rect['brushcolor']), 
                                    Qt.BrushStyle.SolidPattern))
            qr = QRect(QPoint(*rect['pos']), QSize(*rect['size']))
            painter.drawRect(qr)
            s = str(rect['id']) + '*' * int(rect['selected'])
            painter.drawText(qr, Qt.AlignmentFlag.AlignCenter, s)
        painter.end()

    def paintEvent(self, event):
        self.draw_rects(RECTS)

    def resizeEvent(self, e):
        pass

    def mouseMoveEvent(self, e):
        hits = MOUSE_DATA['ids'] # Returns id
        if not hits: return
        pos = PtFromEvent(e)
        movable_rect = RECTS[hits[-1]]
        move_rect(movable_rect, MOUSE_DATA['lastpos'], pos)
        MOUSE_DATA['lastpos'] = pos
        self.update()

    def mousePressEvent(self, e):
        global MOUSE_DATA
        pos = PtFromEvent(e)
        MOUSE_DATA['clickpos'     ] = pos
        if (hits := hittest(pos, RECTS)):
            MOUSE_DATA['ids'          ] = hits
            MOUSE_DATA['lastpos'      ] = pos
            MOUSE_DATA['clear_pending'] = False
        else:
            MOUSE_DATA['clear_pending'] = True

    def mouseReleaseEvent(self, e):
        pos = PtFromEvent(e)
        if pos == MOUSE_DATA['clickpos']:
            if ids := MOUSE_DATA['ids']:
                toggle_rect_selection(ids[-1])
            elif MOUSE_DATA['clear_pending']:
                clear_rect_selection()
                MOUSE_DATA['clear_pending'] = False
        MOUSE_DATA['ids'].clear()
        self.update()

    def keyPressEvent(self, e):
        global SELECTED
        global RECTS
        if not SELECTED:
            return
        if e.key() == Qt.Key.Key_Left:
            for id in SELECTED:
                move_rect_delta(RECTS[id], Point(-1, 0))
        elif e.key() == Qt.Key.Key_Right:
            for id in SELECTED:
                move_rect_delta(RECTS[id], Point( 1, 0))
        elif e.key() == Qt.Key.Key_Up:
            for id in SELECTED:
                move_rect_delta(RECTS[id], Point( 0,-1))
        elif e.key() == Qt.Key.Key_Down:
            for id in SELECTED:
                move_rect_delta(RECTS[id], Point( 0, 1))
        elif e.key() == Qt.Key.Key_Delete:
            for id in SELECTED:
                RECTS.remove(id)
            SELECTED.clear()
        
        self.update()
        return super().keyPressEvent(e)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setMouseTracking(True)
        self.canvas = BlockCanvas()

        leftbar = QWidget()
        leftbar.setMaximumWidth(150)
        leftbar.setMinimumWidth(150)
        vbl = QVBoxLayout()
        butt_random = QPushButton('Randomize')
        butt_xleft  = QPushButton('Compact X←')
        butt_xright = QPushButton('Compact X→')
        butt_yup    = QPushButton('Compact Y↑')
        butt_ydn    = QPushButton('Compact Y↓')
        butt_xlyu   = QPushButton('Compact X← then Y↑')
        butt_xlyd   = QPushButton('Compact X← then Y↓')
        butt_xryu   = QPushButton('Compact X→ then Y↑')
        butt_xryd   = QPushButton('Compact X→ then Y↓')
        butt_yuxl   = QPushButton('Compact Y↑ then X←')
        butt_yuxr   = QPushButton('Compact Y↑ then X→')
        butt_ydxl   = QPushButton('Compact Y↓ then X←')
        butt_ydxr   = QPushButton('Compact Y↓ then X→')
        butt_save   = QPushButton('Save')
        butt_load   = QPushButton('Load')
        
        butt_random.setFixedHeight(40)
        butt_xleft.setFixedHeight(40)
        butt_xright.setFixedHeight(40)
        butt_yup.setFixedHeight(40)
        butt_ydn.setFixedHeight(40)
        butt_xlyu.setFixedHeight(40)
        butt_xlyd.setFixedHeight(40)
        butt_xryu.setFixedHeight(40)
        butt_xryd.setFixedHeight(40)
        butt_yuxl.setFixedHeight(40)
        butt_yuxr.setFixedHeight(40)
        butt_ydxl.setFixedHeight(40)
        butt_ydxr.setFixedHeight(40)
        butt_save.setFixedHeight(40)
        butt_load.setFixedHeight(40)

        vbl.addWidget(butt_random)
        vbl.addWidget(butt_xleft)
        vbl.addWidget(butt_xright)
        vbl.addWidget(butt_yup)
        vbl.addWidget(butt_ydn)
        vbl.addWidget(butt_xlyu)
        vbl.addWidget(butt_xlyd)
        vbl.addWidget(butt_xryu)
        vbl.addWidget(butt_xryd)
        vbl.addWidget(butt_yuxl)
        vbl.addWidget(butt_yuxr)
        vbl.addWidget(butt_ydxl)
        vbl.addWidget(butt_ydxr)
        vbl.addWidget(butt_save)
        vbl.addWidget(butt_load)
        leftbar.setLayout(vbl)

        mainw = QWidget()
        hbl = QHBoxLayout()
        hbl.addWidget(leftbar)
        hbl.addWidget(self.canvas)
        mainw.setLayout(hbl)

        self.setCentralWidget(mainw)
        self.setMinimumSize(200,200)

        butt_random.clicked.connect(self.butt_random_click)
        butt_xleft.clicked.connect(self.butt_xleft_click)
        butt_xright.clicked.connect(self.butt_xright_click)
        butt_yup.clicked.connect(self.butt_yup_click)
        butt_ydn.clicked.connect(self.butt_ydn_click)
        butt_xlyu.clicked.connect(self.butt_xlyu_click)
        butt_xlyd.clicked.connect(self.butt_xlyd_click)
        butt_xryu.clicked.connect(self.butt_xryu_click)
        butt_xryd.clicked.connect(self.butt_xryd_click)
        butt_yuxl.clicked.connect(self.butt_yuxl_click)
        butt_yuxr.clicked.connect(self.butt_yuxr_click)
        butt_ydxl.clicked.connect(self.butt_ydxl_click)
        butt_ydxr.clicked.connect(self.butt_ydxr_click)
        butt_save.clicked.connect(self.save)
        butt_load.clicked.connect(self.load)

    def compact_xy(self, axis, reverse):
        global RECTS
        graph = compact.make_graph(RECTS, axis, reverse)
        lp = compact.longest_path_bellman_ford(graph)
        if axis == 'x':
            def setter(rect, pos): rect['pos'] = Point(pos, rect['pos'].y)
            if reverse: offset = self.canvas.width()
        elif axis == 'y':
            def setter(rect, pos): rect['pos'] = Point(rect['pos'].x, pos)
            if reverse: offset = self.canvas.height()
        if reverse: posfn = lambda i,p: setter(RECTS[i], offset - p)
        else:       posfn = lambda i,p: setter(RECTS[i], pos)
        for i, pos in lp.items():
            posfn(i, pos)
        self.canvas.update()
    def butt_random_click(self):
        global RECTS
        RECTS = init_rects(self.canvas.width(), self.canvas.height())
        self.canvas.update()
    def butt_xleft_click(self):
        self.compact_xy(axis='x', reverse=False)
    def butt_xright_click(self):
        self.compact_xy(axis='x', reverse=True)
    def butt_yup_click(self):
        self.compact_xy(axis='y', reverse=False)
    def butt_ydn_click(self):
        self.compact_xy(axis='y', reverse=True)
    def butt_xlyu_click(self):
        self.compact_xy(axis='x', reverse=False)
        self.compact_xy(axis='y', reverse=False)
    def butt_xlyd_click(self):
        self.compact_xy(axis='x', reverse=False)
        self.compact_xy(axis='y', reverse=True)
    def butt_xryu_click(self):
        self.compact_xy(axis='x', reverse=True)
        self.compact_xy(axis='y', reverse=False)
    def butt_xryd_click(self):
        self.compact_xy(axis='x', reverse=True)
        self.compact_xy(axis='y', reverse=True)
    def butt_yuxl_click(self):
        self.compact_xy(axis='y', reverse=False)
        self.compact_xy(axis='x', reverse=False)
    def butt_yuxr_click(self):
        self.compact_xy(axis='y', reverse=False)
        self.compact_xy(axis='x', reverse=True)
    def butt_ydxl_click(self):
        self.compact_xy(axis='y', reverse=True)
        self.compact_xy(axis='x', reverse=False)
    def butt_ydxr_click(self):
        self.compact_xy(axis='y', reverse=True)
        self.compact_xy(axis='x', reverse=True)
    def save(self):
        import json
        with open('rects.json', 'w') as f:
            json.dump(RECTS, f, indent=2)
    def load(self):
        rects = create_rects_from_json('rects.json')
        global RECTS
        global SELECTED
        SELECTED.clear()
        for rect in rects:
            if rect['selected']:
                SELECTED.add(rect['id'])
        RECTS = rects
        self.update()



def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.resize(800,600)
    width = window.canvas.width()
    height = window.canvas.height()
    window.canvas.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
    global RECTS
    RECTS = init_rects(width, height)
    MOUSE_DATA['ids'     ] = []
    MOUSE_DATA['clickpos'] = None
    MOUSE_DATA['lastpos' ] = None

    window.show()
    app.exec()

if __name__ == '__main__':
    main()