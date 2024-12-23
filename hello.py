import sys
from PyQt6 import QtCore
from PyQt6.QtGui import *
from PyQt6.QtWidgets import *
from PyQt6.QtCore import Qt, QRect, QPoint, QSize
import random
import compact



DRAG_INFO = {}
RECTS = None
WRANGE = [50, 100]
HRANGE = [50, 100]
QTY = 3

def hittest(pos, rects):
    # Check whether pos is inside any of rects
    hits = []
    px = int(pos.x())
    py = int(pos.y())
    for id,rect in rects.items():
        rpos = rect['pos']
        size = rect['size']
        p1 = QPoint(rpos.x() + size.width(), rpos.y() + size.height())
        if px >= rpos.x() and px <= p1.x() and \
           py >= rpos.y() and py <= p1.y():
            hits.append(id)
    return hits

def move_rect(rect, oldpos, newpos):
    # Updates rect coordinates in-place
    delta = newpos - oldpos
    rect['pos'] += delta

class BlockCanvas(QWidget):
    def __init__(self):
        super().__init__()
        self.setMouseTracking(True)

    def draw_rects(self, rects):
        painter = QPainter(self)
        painter.setFont(QFont('times', 20))
        painter.setPen(QPen(QColor('black')))
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        for id, rect in rects.items():
            painter.setBrush(QBrush(rect['brushcolor'], Qt.BrushStyle.SolidPattern))
            qr = QRect(rect['pos'], rect['size'])
            painter.drawRect(qr)
            painter.drawText(qr, Qt.AlignmentFlag.AlignCenter, str(id))
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
        pos = e.position().toPoint()
        if (hits := hittest(pos, RECTS)):
            global DRAG_INFO
            DRAG_INFO['hits'] = hits
            DRAG_INFO['lastpos'] = pos

    def mouseReleaseEvent(self, e):
        global DRAG_INFO
        DRAG_INFO['hits'].clear()

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

        space1 = QSpacerItem(40, 1000, QSizePolicy.Policy.Preferred)
        vbl.addWidget(butt_random)
        #vbl.addItem(space1)
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

    def compact_x(self, dir):
        global RECTS
        if dir == 'left':
            graph = compact.update_graph_xleft(RECTS)
            lp = compact.longest_path_bellman_ford(graph)
            for rect, pos in zip(RECTS.values(), lp[1:]):
                rect['pos'].setX(pos)
        elif dir == 'right':
            graph = compact.update_graph_xright(RECTS)
            lp = compact.longest_path_bellman_ford(graph)
            for rect, pos in zip(RECTS.values(), lp[1:]):
                newpos = self.canvas.width() - pos - rect['size'].width()
                rect['pos'].setX(newpos)
        self.canvas.update()
    def compact_y(self, dir):
        global RECTS
        if dir == 'up':
            graph = compact.update_graph_yup(RECTS)
            lp = compact.longest_path_bellman_ford(graph)
            for rect, pos in zip(RECTS.values(), lp[1:]):
                rect['pos'].setY(pos)
        elif dir == 'dn':
            graph = compact.update_graph_ydn(RECTS)
            lp = compact.longest_path_bellman_ford(graph)
            for rect, pos in zip(RECTS.values(), lp[1:]):
                newpos = self.canvas.height() - pos - rect['size'].height()
                rect['pos'].setY(newpos)
        self.canvas.update()
    def butt_random_click(self):
        global RECTS
        RECTS = init_rects(self.canvas.width(), self.canvas.height())
        self.canvas.update()
    def butt_xleft_click(self):
        self.compact_x('left')
    def butt_xright_click(self):
        self.compact_x('right')
    def butt_yup_click(self):
        self.compact_y('up')
    def butt_ydn_click(self):
        self.compact_y('dn')
    def butt_xlyu_click(self):
        self.compact_x('left')
        self.compact_y('up')
        self.compact_x('left')
        self.compact_y('up')
    def butt_xlyd_click(self):
        self.compact_x('left')
        self.compact_y('dn')
        self.compact_x('left')
        self.compact_y('dn')
    def butt_xryu_click(self):
        self.compact_x('right')
        self.compact_y('up')
        self.compact_x('right')
        self.compact_y('up')
    def butt_xryd_click(self):
        self.compact_x('right')
        self.compact_y('dn')
        self.compact_x('right')
        self.compact_y('dn')
    def butt_yuxl_click(self):
        self.compact_y('up')
        self.compact_x('left')
        self.compact_y('up')
        self.compact_x('left')
    def butt_yuxr_click(self):
        self.compact_y('up')
        self.compact_x('right')
        self.compact_y('up')
        self.compact_x('right')
    def butt_ydxl_click(self):
        self.compact_y('dn')
        self.compact_x('left')
        self.compact_y('dn')
        self.compact_x('left')
    def butt_ydxr_click(self):
        self.compact_y('dn')
        self.compact_x('right')
        self.compact_y('dn')
        self.compact_x('right')



def init_rects(maxx, maxy):
    # Returns dict of dicts
    # Top level dict keys is rect id
    # print(f'init_rects maxx, maxy = {maxx},{maxy}')
    rects = {}
    r255  = lambda: random.randint(0,255)
    randcolor = lambda: QColor(r255(), r255(), r255())
    rects[1] = {'id':1, 'pos':QPoint(0,0), 'size':QSize(50,50), 'pencolor':randcolor(), 'brushcolor':randcolor()}
    rects[2] = {'id':2, 'pos':QPoint(65,60), 'size':QSize(50,50), 'pencolor':randcolor(), 'brushcolor':randcolor()}
    #rects[3] = {'id':3, 'pos':QPoint(55,50), 'size':QSize(50,50), 'pencolor':randcolor(), 'brushcolor':randcolor()}
    # for n in range(1, QTY+1):
    #     x0    = random.randint(0, maxx - WRANGE[1] - 1)
    #     y0    = random.randint(0, maxy - HRANGE[1] - 1)
    #     wrect = random.randint(WRANGE[0], WRANGE[1])
    #     hrect = random.randint(HRANGE[0], HRANGE[1])
    #     pos   = QPoint(x0, y0)
    #     size  = QSize (wrect, hrect)
    #     rects[n] = {'id':n, 'pos':pos, 'size':size, 'pencolor':randcolor(), 'brushcolor':randcolor()}
    #     # rects = {1: {'id': 1, 'pos': QPoint( 10,  10), 'size': QSize(40,40), 'pencolor': randcolor(), 'brushcolor': randcolor()},
    #     #          2: {'id': 2, 'pos': QPoint( 60,  60), 'size': QSize(50,50), 'pencolor': randcolor(), 'brushcolor': randcolor()},
    #     #          3: {'id': 3, 'pos': QPoint(120, 120), 'size': QSize(60,60), 'pencolor': randcolor(), 'brushcolor': randcolor()},
    #     #          }
    return rects

def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.resize(800,600)
    width = window.canvas.width()
    height = window.canvas.height()
    global RECTS
    RECTS = init_rects(width, height)
    DRAG_INFO['hits'] = []

    window.show()
    app.exec()

if __name__ == '__main__':
    main()