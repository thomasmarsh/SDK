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

deltas = [ [], [] ]

state = {}
state['touches'] = {}
state['stroke_count'] = 0

class PenEvent:
    def __init__(self, data=None):
        if data is None:
            self.state = PEN_UP
            return

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
            
        return "touch id=%d phase=%s time=%f" % (self.id, phase, self.timestamp)

def log_delta():
    pen = state['last_pen']
    touch = state['last_touch']
    assert((pen.state == PEN_UP and touch.phase == TOUCH_ENDED)
           or (pen.state == PEN_DOWN and touch.phase == TOUCH_BEGAN))
    
    delta = pen.timestamp - touch.timestamp
    deltas[pen.state].append(delta)
        
    if log_deltas:
        print "pen_delta (%s, %s) %f" % (pen.tip_str(), pen.state_str(), delta)

def plot(x):
    import matplotlib.pyplot as plt
    import numpy as np

    hist, bins = np.histogram(x,bins = 50)
    width = 0.7*(bins[1]-bins[0])
    center = (bins[:-1]+bins[1:])/2
    plt.bar(center, hist, align = 'center', width = width)
    plt.show()

def process_touch(touch):
    if touch.phase != TOUCH_MOVED:
        state['last_touch'] = touch
    
    if touch.phase == TOUCH_BEGAN:
        if log_events:
            print 'touch began: %s' % (touch)

        state['stroke_count'] += 1
        state['touches'][touch.id] = touch

        state['last_pen'] 
        if (state['last_pen'].state == PEN_DOWN):
            log_delta()
    elif touch.phase == TOUCH_ENDED or touch.phase == TOUCH_CANCELLED:
        ended = touch
        began = state['touches'][touch.id]

        if log_events:
            print 'touch began: %s, duration=%f' % (touch, ended.timestamp - began.timestamp)

        if (state['last_pen'].state == PEN_UP):
            log_delta()

        del state['touches'][touch.id]
#    print state['touches']

def process_pen(pen):
    if log_events:
        print pen
    
    if (pen.state == state['last_pen'].state):
        print "WARNING: duplicate pen state received"

    state['last_pen'] = pen

    if not state['last_touch']:
        return

    if (pen.state == PEN_UP and state['last_touch'].phase == TOUCH_ENDED):
        log_delta()
    elif (pen.state == PEN_DOWN and state['last_touch'].phase == TOUCH_BEGAN):
        log_delta()

def parse_file(filename):
    f = open(filename)
    for line in f:
        line_data = line.split('=')
        event_type = line_data[0]
        event_data = line_data[1]

        if event_type == 'touch':
            touch = TouchEvent(event_data)
            process_touch(touch)
        elif event_type == 'pen':
            pen = PenEvent(event_data)
            process_pen(pen)

    if len(state['touches']) != 0:
        print "WARNING: not all touches ended"

    if state['last_pen'] != PEN_UP:
        print "WARNING: pen did not end UP"

    print_summary()

def print_summary():
    print "\nSUMMARY"
    print "========================="
    print "stroke count = %d" % (state['stroke_count'])
    
    for i in [ PEN_DOWN, PEN_UP ]:
        print
        if i == PEN_UP:
            print "PEN_UP stats:"
        else:
            print "PEN_DOWN stats:"
            
        print "delta min = %f" % (numpy.min(deltas[i]))
        print "delta max = %f" % (numpy.max(deltas[i]))
        count_over = len([x for x in deltas[i] if x > 0])
        count_under = len(deltas[i]) - count_over
        
        print "delta %% under 0 = %f (%d/%d)" % (float(count_under) / len(deltas[i]) * 100, count_under, len(deltas[i]))
        print "delta %% over 0 = %f (%d/%d)" % (float(count_over) / len(deltas[i]) * 100, count_over, len(deltas[i]))
        print "delta average = %f" % (numpy.average(deltas[i]))
        print "delta stddev = %f" % (numpy.std(deltas[i]))
        print "delta var = %f" % (numpy.var(deltas[i]))

        plot(deltas[i])
        
def main():
    state['last_pen'] = PenEvent()
    state['last_touch'] = None
    
    parser = argparse.ArgumentParser(description='Process pen and touch logs.')
    parser.add_argument('file',
                        help='the file to read data from')

    args = parser.parse_args()

    parse_file(args.file)

if __name__ == "__main__":
    main()
