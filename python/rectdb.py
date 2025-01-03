
# Items added to Rects instance must have ['id']
class Rects(dict):
    def __init__(self, *kw, **kwargs):
        dict.__init__(self, *kw, **kwargs)
    def __iter__(self):
        return iter(self.values())
    def add(self, item):
        self.__setitem__(item['id'], item)
    def remove(self, id):
        self.__delitem__(id)


if __name__ == '__main__':
    r1 = {'id': 15, 'txt': 'hi'}
    r2 = {'id': 12, 'txt': 'bye'}
    rects = Rects()
    rects.add(r1)
    rects.add(r2)
    print(rects)
    x1 = rects[15]
    x2 = rects[12]
    pass
    