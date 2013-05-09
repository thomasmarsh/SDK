import argparse
import numpy

# CONSTANTS

TOUCH_BEGAN = 0
TOUCH_MOVED = 1
TOUCH_ENDED = 2
TOUCH_STATIONARY = 3
TOUCH_CANCELLED = 4

PEN_UP = 0
PEN_DOWN = 1

PEN_TIP1 = 0
PEN_TIP2 = 1

# global state

log_events = 1
log_deltas = 1

class PenEvent:
    def __init__(self, data=None):
        values = data.split(',')
        self.state = int(values[0])
        self.tip = int(values[1])

        self.window_x = float(values[2])
        self.window_y = float(values[3])
        self.x = float(values[4])
        self.y = float(values[5])
        self.timestamp = float(values[6])

    def __repr__(self):
        return "pen state=%s tip=%s time=%f" % (self.state_str(), self.tip_str(), self.timestamp)

    def state_str(self):
        if self.state == PEN_UP:
            return "UP"
        elif self.state == PEN_DOWN:
            return "DOWN"

    def tip_str(self):
        if self.tip == PEN_TIP1:
            return "TIP"
        elif self.tip == PEN_TIP2:
            return "ERASER"

class Analyzer:
    def __init__(self):
        self.deltas = [ [], [] ]

        self.event_count = 0
        self.last_pen = None
        self.missing_count = 0
        
    def log_delta(self, pen):
        if pen.state == self.last_pen.state:
            self.missing_count += 1
        delta = pen.timestamp - self.last_pen.timestamp
        print "delta = %f" % (delta)
        self.deltas[pen.state].append(delta)

    def process_pen(self, pen):
        if log_events:
            print pen

        self.event_count += 1
        if self.last_pen is not None:
            self.log_delta(pen)
        self.last_pen = pen

    def parse_file(self, filename):
        f = open(filename)
        for line in f:
            line_data = line.split('=')
            event_type = line_data[0]
            event_data = line_data[1]

            if event_type == 'pen':
                pen = PenEvent(event_data)
                self.process_pen(pen)

        self.print_summary()
        
    def plot(self, x):
        import matplotlib.pyplot as plt
        import numpy as np

        hist, bins = np.histogram(x,bins = 50)
        width = 0.7*(bins[1]-bins[0])
        center = (bins[:-1]+bins[1:])/2
        plt.bar(center, hist, align = 'center', width = width)
        plt.show()
        
    def print_summary(self):
        print "\nSUMMARY"
        print "========================="
        print "event count = %d" % (self.event_count)
        print "missing count = %d" % (self.missing_count)

        for i in [ PEN_UP, PEN_DOWN ]:
            print
            if i == PEN_UP:
                print "PEN_UP stats:"
            else:
                print "PEN_DOWN stats:"

            if len(self.deltas[i]) != 0:
                print "delta min = %f" % (numpy.min(self.deltas[i]))
                print "delta max = %f" % (numpy.max(self.deltas[i]))
                
                print "delta average = %f" % (numpy.average(self.deltas[i]))
                print "delta stddev = %f" % (numpy.std(self.deltas[i]))
                print "delta var = %f" % (numpy.var(self.deltas[i]))
                
            self.plot(self.deltas[i])
        
def main():
    parser = argparse.ArgumentParser(description='Process pen and touch logs.')
    parser.add_argument('file',
                        help='the file to read data from')

    args = parser.parse_args()

    analyzer = Analyzer()
    analyzer.parse_file(args.file)

if __name__ == "__main__":
    main()
