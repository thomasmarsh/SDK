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
state['last_touch'] = None
state['last_pen'] = None
state['min_delta'] = 0
state['max_delta'] = 0
state['count_over'] = 0
state['count_under'] = 0

pen_state = [ PEN_UP, PEN_UP ]

class PenEvent:
    def __init__(self, data):
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

def log_delta(pen, touch):
    delta = pen.timestamp - touch.timestamp
    deltas[pen.state].append(delta)

    if delta > 0:
        state['count_over'] += 1
    else:
        state['count_under'] += 1
        
    if log_deltas:
        print "pen_delta (%s, %s) %f" % (pen.tip_str(), pen.state_str(), delta)
        
def process_touch(touch):
    state['last_touch'] = touch
    
    if touch.phase == TOUCH_BEGAN:
        if log_events:
            print 'touch began: %s' % (touch)

        state['stroke_count'] += 1
        state['touches'][touch.id] = touch

        if (pen_state[0] == PEN_DOWN or pen_state[1] == PEN_DOWN):
            # pen happened first
            log_delta(state['last_pen'], touch)
    elif touch.phase == TOUCH_ENDED or touch.phase == TOUCH_CANCELLED:
        ended = touch
        began = state['touches'][touch.id]

        if (pen_state[0] == PEN_UP or pen_state[1] == PEN_UP):
            # pen happened first
            log_delta(state['last_pen'], touch)

        if log_events:
            print "touch ended, duration=%f" % (ended.timestamp - began.timestamp)
        del state['touches'][touch.id]
#    print state['touches']

def process_pen(pen):
    if log_events:
        print pen
    
    if (pen.state == pen_state[pen.tip]):
        print "WARNING: duplicate pen state received"

    state['last_pen'] = pen
    pen_state[pen.tip] = pen.state

    if not state['last_touch']:
        return

    if len(state['touches']):
        # pen happened second
        log_delta(pen, state['last_touch'])

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

    if pen_state[0] != PEN_UP or pen_state[1] != PEN_UP:
        print "WARNING: pen did not end UP"

    print "\nSUMMARY"
    print "========================="
    print "stroke count = %d" % (state['stroke_count'])

    for i in [PEN_UP, PEN_DOWN]:
        if i == PEN_UP:
            print "PEN_UP stats:"
        else:
            print "PEN_DOWN stats:"
            
        print "delta min = %f" % (numpy.min(deltas[i]))
        print "delta max = %f" % (numpy.max(deltas[i]))
        print "delta %% under 0 = %f" % (float(state['count_under']) / len(deltas[i]) * 100)
        print "delta %% over 0 = %f" % (float(state['count_over']) / len(deltas[i]) * 100)
        print "delta average = %f" % (numpy.average(deltas[i]))
        print "delta stddev = %f" % (numpy.std(deltas[i]))
        print "delta var = %f" % (numpy.var(deltas[i]))
        
def main():
    parser = argparse.ArgumentParser(description='Process pen and touch logs.')
    parser.add_argument('file',
                        help='the file to read data from')

    args = parser.parse_args()

    parse_file(args.file)

if __name__ == "__main__":
    main()
