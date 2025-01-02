#!/usr/bin/python3
import sys
from PyQt6 import QtCore
from PyQt6.QtGui import *
from PyQt6.QtWidgets import *
from PyQt6.QtCore import Qt, QRect, QPoint, QSize
import random
import compact
from rectdb import Rects



DRAG_INFO = {}
RECTS = None
SELECTED = set()
WRANGE = [25, 50]
HRANGE = [25, 50]
QTY = 8

def hittest(pos, rects):
    # Check whether pos is inside any of rects
    hits = []
    px = int(pos.x())
    py = int(pos.y())
    for id,rect in rects.items():
        rpos = rect['pos']
        size = rect['size']
        p1 = QPoint(rpos[0] + size[0], rpos[1] + size[1])
        if px >= rpos[0] and px <= p1.x() and \
           py >= rpos[1] and py <= p1.y():
            hits.append(id)
    return hits

def move_rect_delta(rect, delta):
    # rect is dict
    # delta is tuple
    # Updates rect coordinates in-place
    newpos = (rect['pos'][0] + delta[0],
              rect['pos'][1] + delta[1])
    rect['pos'] = newpos

def move_rect(rect, oldpos, newpos):
    # rect is dict
    # oldpos, newpos are QPoint
    # Updates rect coordinates in-place
    delta = newpos - oldpos
    move_rect_delta(rect, (delta.x(), delta.y()))

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
        hits = DRAG_INFO['hits'] # Returns id
        if not hits: return
        pos = e.position().toPoint()
        movable_rect = RECTS[hits[-1]]
        move_rect(movable_rect, DRAG_INFO['lastpos'], pos)
        DRAG_INFO['lastpos'] = pos
        self.update()

    def mousePressEvent(self, e):
        global RECTS
        global SELECTED
        pos = e.position().toPoint()
        if (hits := hittest(pos, RECTS)):
            global DRAG_INFO
            DRAG_INFO['hits'] = hits
            DRAG_INFO['lastpos'] = pos
            if RECTS[hits[-1]]['selected']:
                RECTS[hits[-1]]['selected'] = False
                SELECTED.remove(hits[-1])
            else:
                RECTS[hits[-1]]['selected'] = True
                SELECTED.add(hits[-1])
        else:
            for id in SELECTED:
                RECTS[id]['selected'] = False
            SELECTED.clear()
        self.update()

    def mouseReleaseEvent(self, e):
        global DRAG_INFO
        DRAG_INFO['hits'].clear()

    def keyPressEvent(self, e):
        global SELECTED
        global RECTS
        if not SELECTED:
            return
        if e.key() == Qt.Key.Key_Left:
            for id in SELECTED:
                move_rect_delta(RECTS[id], (-1, 0))
        elif e.key() == Qt.Key.Key_Right:
            for id in SELECTED:
                move_rect_delta(RECTS[id], ( 1, 0))
        elif e.key() == Qt.Key.Key_Up:
            for id in SELECTED:
                move_rect_delta(RECTS[id], ( 0,-1))
        elif e.key() == Qt.Key.Key_Down:
            for id in SELECTED:
                move_rect_delta(RECTS[id], ( 0, 1))
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
            setter = lambda rect, pos: rect['pos'].setX(pos)
            if reverse: offset = self.canvas.width()
        elif axis == 'y':
            setter = lambda rect, pos: rect['pos'].setY(pos)
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
        self.compact_xy(axis='x', reverse=False)
        self.compact_xy(axis='y', reverse=False)
    def butt_xlyd_click(self):
        self.compact_xy(axis='x', reverse=False)
        self.compact_xy(axis='y', reverse=True)
        self.compact_xy(axis='x', reverse=False)
        self.compact_xy(axis='y', reverse=True)
    def butt_xryu_click(self):
        self.compact_xy(axis='x', reverse=True)
        self.compact_xy(axis='y', reverse=False)
        self.compact_xy(axis='x', reverse=True)
        self.compact_xy(axis='y', reverse=False)
    def butt_xryd_click(self):
        self.compact_xy(axis='x', reverse=True)
        self.compact_xy(axis='y', reverse=True)
        self.compact_xy(axis='x', reverse=True)
        self.compact_xy(axis='y', reverse=True)
    def butt_yuxl_click(self):
        self.compact_xy(axis='y', reverse=False)
        self.compact_xy(axis='x', reverse=False)
        self.compact_xy(axis='y', reverse=False)
        self.compact_xy(axis='x', reverse=False)
    def butt_yuxr_click(self):
        self.compact_xy(axis='y', reverse=False)
        self.compact_xy(axis='x', reverse=True)
        self.compact_xy(axis='y', reverse=False)
        self.compact_xy(axis='x', reverse=True)
    def butt_ydxl_click(self):
        self.compact_xy(axis='y', reverse=True)
        self.compact_xy(axis='x', reverse=False)
        self.compact_xy(axis='y', reverse=True)
        self.compact_xy(axis='x', reverse=False)
    def butt_ydxr_click(self):
        self.compact_xy(axis='y', reverse=True)
        self.compact_xy(axis='x', reverse=True)
        self.compact_xy(axis='y', reverse=True)
        self.compact_xy(axis='x', reverse=True)
    def save(self):
        import json
        with open('rects.json', 'w') as f:
            json.dump(RECTS, f)
    def load(self):
        import json
        global RECTS
        RECTS = json.load(open('rects.json', 'r'))

def randcolor():
    return (random.randint(0,255),
            random.randint(0,255),
            random.randint(0,255))

def randrect(id, maxx, maxy):
    x0    = random.randint(0, maxx - WRANGE[1] - 1)
    y0    = random.randint(0, maxy - HRANGE[1] - 1)
    wrect = random.randint(WRANGE[0], WRANGE[1])
    hrect = random.randint(HRANGE[0], HRANGE[1])
    pos   = (x0, y0)
    size  = (wrect, hrect)
    rect = {'id':id, 'pos':pos, 'size':size, 'selected': False,
            'pencolor':randcolor(), 'brushcolor':randcolor()}
    return rect


def init_rects(maxx, maxy):
    # Returns dict of dicts
    # Top level dict keys is rect id
    rects = Rects()
    #r3(rects)
    for id in range(1, QTY+1):
        rects[id] = randrect(id, maxx, maxy)
    return rects

def r1(rects):
    # Set up rects like in scanline comments
    r255  = lambda: random.randint(0,255)
    rects.add({'id':4, 'pos':(80,10), 'size':(15,10), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':3, 'pos':(80,20), 'size':(15,20), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':2, 'pos':(50,10), 'size':(15,20), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':1, 'pos':( 0, 5), 'size':(10,40), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':5, 'pos':(50,50), 'size':(15,10), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})

def r2(rects):
    # Sets up another edge condition
    r255  = lambda: random.randint(0,255)
    rects.add({'id':1, 'pos':(30,15), 'size':(100,50), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':2, 'pos':(205,65), 'size':(80,50), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':3, 'pos':(200, 115), 'size':(60,50), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':4, 'pos':(0,0), 'size':(25,150), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})

def r3(rects):
    # Sets up another edge condition
    r255  = lambda: random.randint(0,255)
    rects.add({'id':1, 'pos':(0, 0), 'size':(100, 100), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})
    rects.add({'id':2, 'pos':(0, 0), 'size':(100, 100), 'pencolor':randcolor(), 'brushcolor':randcolor(), 'selected': False})


def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.resize(800,600)
    width = window.canvas.width()
    height = window.canvas.height()
    window.canvas.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
    global RECTS
    RECTS = init_rects(width, height)
    DRAG_INFO['hits'] = []

    window.show()
    app.exec()

if __name__ == '__main__':
    main()