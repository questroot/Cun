from pixelstudio import Sprite
BASE = ['#292438', '#624052', '#a6654a', '#daa45e', '#e7a477', '#ffdab0', '#24525e', '#387d80', '#72b4a1', '#f5e7c5', '#a6a7ae', '#bb5254']

class Artist:

    def __init__(self, palette):
        self.s = Sprite(48, 64, palette=palette)
        self.p = palette

    def poly(self, pts, c):
        self.s.polygon(pts, self.p[c])

    def r(self, a, b, c, d, col):
        self.s.rect(a, b, c, d, self.p[col])

    def l(self, a, b, c, d, col):
        self.s.line(a, b, c, d, self.p[col])

    def dot(self, x, y, c):
        self.s.px(x, y, self.p[c])

    def face(self, older=False, feminine=False):
        self.poly([(16, 12), (28, 12), (31, 16), (30, 23), (27, 26), (20, 26), (16, 22)], 4)
        self.poly([(17, 14), (25, 14), (26, 18), (24, 21), (18, 20), (16, 17)], 5)
        self.r(14, 17, 16, 20, 2)
        self.r(15, 17, 16, 19, 4)
        self.r(30, 17, 31, 20, 2)
        self.r(18, 17, 20, 17, 1)
        self.r(26, 17, 28, 17, 1)
        self.r(19, 18, 20, 19, 0)
        self.r(27, 18, 28, 19, 0)
        self.r(23, 19, 24, 21, 4)
        self.l(23, 24, 25, 24, 2 if older else 1)
        if older:
            self.l(17, 21, 19, 21, 2)
            self.l(28, 21, 29, 21, 2)
        if feminine:
            self.l(21, 23, 24, 23, 11)

    def boots(self):
        self.r(15, 47, 29, 56, 6)
        self.r(16, 48, 20, 55, 7)
        self.l(22, 49, 22, 57, 0)
        self.poly([(15, 55), (20, 55), (19, 60), (10, 60), (11, 58)], 1)
        self.l(12, 57, 18, 57, 2)
        self.l(11, 60, 19, 60, 0)
        self.poly([(25, 55), (29, 55), (30, 58), (33, 59), (33, 60), (25, 60)], 1)
        self.l(26, 56, 29, 56, 2)
        self.l(25, 60, 33, 60, 0)

    def human_base(self, wide=False):
        left, right = (9, 35) if wide else (11, 33)
        self.poly([(17, 8), (27, 8), (31, 12), (32, 22), (28, 26), (right, 29), (right + 2, 38), (right, 44), (31, 50), (30, 57), (34, 59), (34, 61), (24, 61), (22, 54), (20, 54), (20, 61), (9, 61), (9, 58), (13, 55), (13, 50), (left, 46), (left - 2, 39), (left, 30), (17, 26), (13, 21), (13, 14)], 0)
        self.boots()
        self.poly([(16, 27), (28, 27), (right, 31), (right, 45), (29, 50), (14, 50), (left, 44), (left, 33)], 6)
        self.poly([(16, 28), (22, 29), (20, 45), (14, 47), (left + 1, 40), (left + 2, 33)], 7)
        self.poly([(16, 29), (18, 30), (16, 37), (left + 2, 38), (left + 2, 34)], 8)
        self.poly([(24, 29), (29, 29), (right - 1, 33), (right - 2, 40), (27, 47), (23, 44)], 7)
        self.r(20, 24, 26, 29, 2)
        self.r(20, 25, 24, 28, 4)
        self.face()
