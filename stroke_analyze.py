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


class TouchEvent:
    def __init__(self, data):
        values = data.split(',')
        self.id = int(values[0])
        self.phase = int(values[1])
        
        self.window_x = float(values[2])
        self.window_y = float(values[3])
        self.x = float(values[4])
        self.y = float(values[5])
        self.timestamp = float(values[6])
        
    def __repr__(self):
        if self.phase == TOUCH_BEGAN:
            phase = "BEGAN"
        elif self.phase == TOUCH_MOVED:
            phase = "MOVED"
        elif self.phase == TOUCH_ENDED:
            phase = "ENDED"
        elif self.phase == TOUCH_STATIONARY:
            phase = "STATIONARY"
        elif self.phase == TOUCH_CANCELLED:
            phase = "CANCELLED"
        else:
            phase = "UNKNOWN"
            
        return "touch phase=%s id=%d time=%f" % (phase, self.id, self.timestamp)

class Analyzer:
    def __init__(self):
        self.deltas = [ [], [] ]

        self.stroke_count = 0
        self.missing_up = 0
        self.missing_down = 0
        self.last_pen = None
        self.last_touch = None
        
    def log_delta(self):
        assert((self.last_pen.state == PEN_UP and self.last_touch.phase == TOUCH_ENDED)
               or (self.last_pen.state == PEN_DOWN and self.last_touch.phase == TOUCH_BEGAN))
        
        delta = self.last_pen.timestamp - self.last_touch.timestamp
        self.deltas[self.last_pen.state].append(delta)
            
        if log_deltas:
            print "pen_delta (%s, %s) %f" % (self.last_pen.tip_str(), self.last_pen.state_str(), delta)

    def touch_began(self, touch):
        if (self.last_touch is None and self.last_pen is None):
            return

        if (self.last_pen is None):
            print 'missing up/down'
            self.missing_down += 1
            self.missing_up += 1
            return
        
        if (self.last_pen.state == PEN_DOWN
            and (self.last_touch is None
                 or self.last_pen.timestamp > self.last_touch.timestamp)):
            # pen down before touch began
            self.last_touch = touch
            self.log_delta()
        else:
            self.last_pen = None

    def touch_ended(self, touch):
        self.stroke_count += 1
            
        if (self.last_pen is not None):
            if (self.last_pen.state == PEN_UP):
                self.last_touch = touch
                self.log_delta()

    def process_touch(self, touch):
        if touch.phase == TOUCH_MOVED:
            return

        if log_events:
            print touch

        if touch.phase == TOUCH_BEGAN:
            self.touch_began(touch)
        elif touch.phase == TOUCH_ENDED or touch.phase == TOUCH_CANCELLED:
            self.touch_ended(touch)
            
        self.last_touch = touch

    def process_pen(self, pen):
        if log_events:
            print pen
    
        if (self.last_pen is not None and pen.state == self.last_pen.state):
            if pen.state == PEN_UP:
                self.missing_down += 1
            elif pen.state == PEN_DOWN:
                self.missing_up += 1

        self.last_pen = pen

        if self.last_touch is None:
            return

        if (pen.state == PEN_UP and self.last_touch.phase == TOUCH_ENDED):
            self.log_delta()
        elif (pen.state == PEN_DOWN and self.last_touch.phase == TOUCH_BEGAN):
            self.log_delta()

    def parse_file(self, filename):
        f = open(filename)
        for line in f:
            line_data = line.split('=')
            event_type = line_data[0]
            event_data = line_data[1]

            if event_type == 'touch':
                touch = TouchEvent(event_data)
                self.process_touch(touch)
            elif event_type == 'pen':
                pen = PenEvent(event_data)
                self.process_pen(pen)

        if self.last_pen.state != PEN_UP:
            print "WARNING: pen did not end UP"

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
        print "stroke count = %d" % (self.stroke_count)
        print "missing down = %d" % (self.missing_down)
        print "missing up = %d" % (self.missing_up)

        print "percent missing = %f" % (float(self.missing_down) / self.stroke_count * 100)
    
        for i in [ PEN_DOWN, PEN_UP ]:
            print
            if i == PEN_UP:
                print "PEN_UP stats:"
            else:
                print "PEN_DOWN stats:"

            if len(self.deltas[i]) != 0:
                print "delta min = %f" % (numpy.min(self.deltas[i]))
                print "delta max = %f" % (numpy.max(self.deltas[i]))
        
                count_over = len([x for x in self.deltas[i] if x > 0])
                count_under = len(self.deltas[i]) - count_over
        
                print "delta %% under 0 = %f (%d/%d)" % (float(count_under) / len(self.deltas[i]) * 100, count_under, len(self.deltas[i]))
                print "delta %% over 0 = %f (%d/%d)" % (float(count_over) / len(self.deltas[i]) * 100, count_over, len(self.deltas[i]))
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
