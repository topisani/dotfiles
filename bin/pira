#!/usr/bin/python2

'''
	PIRA : Python InteRActive interface for gdb
	optimized to terminal resolution > 128x48
	Author : daehee
'''

DEBUG = False

import os, sys, thread, time, tty, termios
from subprocess import PIPE, Popen
from threading  import Thread
from Queue import Queue, Empty

# read stdin w/o buffering
class _Getch:
	def __call__(self):
		fd = sys.stdin.fileno()
		old_settings = termios.tcgetattr(fd)
		try:
			tty.setraw(sys.stdin.fileno())
			ch = sys.stdin.read(1)
		finally:
			termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
		return ch


ON_POSIX = 'posix' in sys.builtin_module_names

# terminal colors
'''
Black        0;30     Dark Gray     1;30 Blue         0;34     Light Blue    1;34
Green        0;32     Light Green   1;32 Cyan         0;36     Light Cyan    1;36
Red          0;31     Light Red     1;31 Purple       0;35     Light Purple  1;35
Brown/Orange 0;33     Yellow        1;33 Light Gray   0;37     White         1;37
'''
c_black 	= '\033[0;30m'
c_white 	= '\033[0;37m'
c_red		= '\033[1;31m'
c_darkred	= '\033[0;31m'
c_green		= '\033[0;32m'
c_blue		= '\033[0;34m'
c_gray		= '\033[0;37m'
c_none		= '\033[0m'

# global configuration
SHELL = '\r'+c_red+'pira> '+c_none
MINPOLL = 3000
TWIDTH = 80
RWIDTH = 40
FIXED_HEIGHT = 20
NPREV_INST = 8					# number of previous instructions to be displayed
NEXTSCR = 'magic_next_scr'		# for si
NEXTSCR2 = 'magic_next_scr2'	# for ni
PREVSCR = 'magic_prev_scr'
TOGGLE_MAGIC = 'zz'
ARCH = 'x86'					# x86(eip) / x64(rip) / arm,mips(pc)

# info registers for each cpu
IR_x86 = 'i r $eax $ebx $ecx $edx $esi $edi $esp $ebp $eip $eflags'
IR_x64 = 'i r $rdi $rsi $rdx $rcx $rax $rbx $rbp $rsp $rip $eflags'
IR_arm = 'i r $r0 $r1 $r2 $r3 $r4 $sp $bp $pc'
IR_mips = 'i r $a0 $a1 $a2 $a3 $sp $pc'

TEXT_x86 = 'x/15i $eip'
TEXT_x64 = 'x/15i $rip'
TEXT_arm = 'x/15i $pc'
TEXT_mips = 'x/15i $pc'

#default text section / info registers
TEXT = TEXT_x86
IR = IR_x86

# i-mode global variables
inst_q = Queue()	# initially filled with ' ' as NPREV_INST
prev_regs = []		# initially empty
keybuf = ['']		# key buffer history array
ki = 0 				# current history buffer index (index 0 is current)
prev_cmd = ''
imode = False		# default is static mode
scr_buf = ['end of previous screen']	# screen buffer
si = 0 				# scr index
stall_buffer = False	# exceptional long buffering (ex, run before bp)

# hot key definition
TOGGLE_MODE = 'magic_sequence_toggle_mode'

def enqueue_output(out, queue):
    for line in iter(out.readline, b''):
        queue.put(line)
    out.close()

def clear_screen():	
	print '\033[2J\033[1;1H'
	if imode == False:
		print '-STATIC MODE-'
	else:
		print '-INTERACTIVE MODE-'
	return

'''
class Thread_GUI(Thread):
	def __init__(self, io, cmd, prev_cmd, cursor, q, q2):
		Thread.__init__(self)
		self.io = io
		self.cmd = cmd
		self.prev_cmd = prev_cmd
		self.cursor = cursor
		self.q = q
		self.q2 = q2
	def run(self):
		process_gui(self.io, self.cmd, self.prev_cmd, self.cursor, self.q, self.q2)

class Thread_CUI(Thread):
	def __init__(self, io, cmd, q, q2):
		Thread.__init__(self)
		self.io = io
		self.cmd = cmd
		self.q = q
		self.q2 = q2
	def run(self):
		process_cui(self.io, self.cmd, self.q, self.q2)
'''

def flush_output(q, q2):
	global stall_buffer

	buf=''
	cnt=0
	nolock=0

	if stall_buffer: time.sleep(0.2)		# wait before drain

	# read line without blocking
	while True:			
		#stdout
		try:  
			line = q.get_nowait() # or q.get(timeout=.1)
			buf += line
		except:
			if buf!='':
				cnt += 1
			pass	
		# stderr
		try:  
			line = q2.get_nowait() # or q.get(timeout=.1)		
			buf += line
		except:
			if buf!='':
				cnt += 1
			pass	
		# buffer is drained after reading something!
		if cnt > MINPOLL:
			break
		# if nothing comes to buffer, trigger timeout
		if nolock > 1000000:
			# gdb not giving output. maybe expecting input??
			print 'wtf'
			break
		nolock += 1
	return buf

def process_command(io, cmd, q, q2):
	io.write(cmd + '\n')
	return flush_output(q, q2)

def save(s):
	global scr_buf
	# save screen into buffer
	scr_buf = [s] + scr_buf
	si = 0 		# come back to current scr
	return

def process_cui(io, cmd, q, q2):
	tmp = process_command(io, cmd, q, q2)
	tmp = tmp.lstrip('(gdb )')
	print tmp



'''
handle the case when process_command doesn't give any output!!!
'''
# draw EIP area and Register area
prev_iscr = ''		# global buffer for process_gui
def process_gui(io, cmd, prev_cmd, cursor, q, q2):
	# screen
	global prev_iscr

	scr = ''
	tmp = ''
	tmp2 = ''

	# process user command first.
	if cmd!='':
		tmp = process_command(io, cmd, q, q2) + '\n'
		tmp = tmp.lstrip('(gdb) ')		
		# prev command result
		if cmd != prev_cmd and prev_cmd != '':
			# iterate previous command at new state (e.g. x/10wx $esp)
			tmp2 = process_command(io, prev_cmd, q, q2) + '\n'
			tmp2 = tmp2.lstrip('(gdb) ')			
	
	# draw i-screen
	if cursor == True:
		# register info
		ir = process_command(io, IR, q, q2)
		irs = ir.split('\n')

		# trim lines
		for i in xrange(len(irs)):
			if len(irs[i]) > RWIDTH: irs[i] = irs[i][:RWIDTH]
		
		# initial prev_regs is empty
		if not prev_regs:
			for i in irs:
				prev_regs.append(i)
		else:
			# sanity check
			if len(irs) == len(prev_regs):
				# compare and refresh(to new ones) 
				for i in xrange(len(irs)):
					if prev_regs[i] != irs[i]:
						prev_regs[i] = irs[i]					# update current register value
						irs[i] = c_red + irs[i] + c_none		# mark current register value has been changed
			else:
				del prev_regs[:]		# empty list

		# code section info

		eip = process_command(io, TEXT, q, q2)
		eips = eip.split('\n')

		l = ''
		l2 = ''
		buf = ''
		for i in xrange(FIXED_HEIGHT):
			
			if i < NPREV_INST:
				if not inst_q.empty():
					# peek all element
					l = inst_q.get()
					inst_q.put(l)
				else:
					l = ' '
			else:
				k = i - NPREV_INST
				if k < len(eips) :
					l = eips[k]
				else:
					l = ' '

				# enqueue first instruction
				if k==0 and cursor==True:
					inst_q.get()		# remove oldest instruction
					inst_q.put( eips[k] )	# put new instruction
				
			if i < len(irs) :
				l2 = irs[i]                        
			else:
				l2 = ' '

			# replace tab
			l = l.replace('\x09', '\x20')
			l2 = l2.replace('\x09', '\x20')
			l = l.replace('=>', '')
			l = l.replace('(gdb) ', '')		
			l2 = l2.replace('(gdb) ', '')
		
			# trim code line	
			if len(l) > TWIDTH: l = l[:TWIDTH]
		
			# process by cases
			if i == NPREV_INST:
				fmt = ' '+c_red+'>{:'+str(TWIDTH)+'s}'+c_none+'    {:'+str(RWIDTH)+'s}'
				buf += fmt.format(l, l2) + '\n'
			elif i < NPREV_INST:
				fmt = '  '+c_darkred+'{:'+str(TWIDTH)+'s}'+c_none+'    {:'+str(RWIDTH)+'s}'
				buf += fmt.format(l, l2) + '\n'
			else:
				fmt = '{:'+str(TWIDTH)+'s}      {:'+str(RWIDTH)+'s}'
				buf += fmt.format(l, l2) + '\n'

		# draw screen
		fmt = '  '+c_green+'{:'+str(TWIDTH)+'s}{:'+str(RWIDTH)+'s}'+c_none
		#scr += fmt.format('        [CURRENT EIP CODE SECTION]', '      [REGISTER INFORMATION]') + '\n\n'	
		scr += buf + '\n'
		scr += '   '+c_green+('='*(TWIDTH + RWIDTH))+c_none+'\n'

		# save current i-screen
		prev_iscr = scr

	# if no cursor is used, just show previous i-screen
	else:
		scr = prev_iscr

	# user command result
	scr += tmp2
	scr += tmp

	# save current screen to history buffer
	save(scr)

	# print out screen
	clear_screen()	
	print scr


# handle input buffering and parse command
def readcmd():
	global keybuf			# custom keyboard buffer
	tmpbuf = ''				# tmp buffer

	b_save = True

	# insert an empty buffer at the first of history list
	if len(keybuf) > 0:
		if keybuf[0] != '':
			keybuf = [''] + keybuf
	ki = 0
	
	# flush the buffer only if newline appears or magic sequence appears.
	while True:
		# read 1byte from keyboard raw buffer
		inkey = _Getch()
		while(1):
			k = inkey()
			if k!='': break

		# ctrl-c
		if k == '\x03':
			print 'CTRL-C detected'
			return '\x03'
		# ctrl-z
		if k == '\x1a':
			print 'CTRL-Z detected'

		# backspace (Tricky!!)
		if k == '\x7f':
			tmpbuf = tmpbuf[:-1]
			sys.stdout.write(SHELL+tmpbuf+' ')
			sys.stdout.write(SHELL+tmpbuf)
			continue
			
		# line flush
		if k == '\x0d' or k == '\x0a':
			sys.stdout.write('\n')
			break

		# append byte to custom buffer
		tmpbuf += k
		
		# magic sequence
		if tmpbuf[-3:]=='\x1b[A':	# UP
			if imode==True:
				tmpbuf = PREVSCR
				b_save = False
				break
			sys.stdout.write('\r      '+' '*len(tmpbuf))	# delete line
			tmpbuf = tmpbuf[:-3]							# delete arrow code
			if ki < len(keybuf)-1:
				ki += 1
			tmpbuf = keybuf[ki]				
			sys.stdout.write(SHELL+tmpbuf)					# show line again				
			continue
		elif tmpbuf[-3:]=='\x1b[B':	# DOWN
			if imode==True:
				tmpbuf = NEXTSCR2 	# -> means next screen if si is not 0
				b_save = False
				break
			sys.stdout.write('\r      '+' '*len(tmpbuf))	# delete line
			tmpbuf = tmpbuf[:-3]							# delete arrow code
			if ki > 0:
				ki -= 1
			tmpbuf = keybuf[ki]	
			sys.stdout.write(SHELL+tmpbuf)					# show line again
			continue
		elif tmpbuf[-3:]=='\x1b[C':	# RIGHT
			tmpbuf = tmpbuf[:-3]		# delete arrow code
			if imode==True:
				tmpbuf = NEXTSCR 	# -> means next screen if si is not 0
				b_save = False
				break				
			continue
		elif tmpbuf[-3:]=='\x1b[D':	# LEFT
			tmpbuf = tmpbuf[:-3]		# delete arrow code
			if imode==True:
				tmpbuf = PREVSCR
				b_save = False
				break
			continue
		elif tmpbuf==TOGGLE_MAGIC:
			tmpbuf = TOGGLE_MODE
			break
		else:
			pass

		# show current buffer
		sys.stdout.write(SHELL+tmpbuf)
	
	# save current buffer to history
	if b_save==True: keybuf[0] = tmpbuf
	return tmpbuf

# make this configureable by script
def hotkeys(cmd):
	# for example x/ eax -> x/10wx $eax, x/ *eax -> dump memory around pointer pointed by eax...
	if cmd=='st':
		return 'x/10wx $esp'
	else:
		return cmd

# stty sane
# tput cols
# tput lines
if __name__ == "__main__":
	from argparse import ArgumentParser, RawTextHelpFormatter

	parser = ArgumentParser(description="ex) python pira.py prog\n"
			"ex) python pira.py prog -tw 50 -rw 30\n"
			"ex) python pira.py prog -mp 8000\n"
			"ex) python pira.py prog -f 15 -pi 5 \n"
			"ex) python pira.py -p [pid]"
			, formatter_class=RawTextHelpFormatter)

	parser.add_argument("target", help="select a program to debug")
	parser.add_argument("-tw", "--twidth", help="set text section terminal width. default:80", type=int)
	parser.add_argument("-rw", "--rwidth", help="set register section terminal width. default:40", type=int)
	parser.add_argument("-mp", "--minpoll", help="set input buffer queue polling timdout. default:5000", type=int)
	parser.add_argument("-ih", "--iheight", help="set interactive screen terminal height. default:20", type=int)
	parser.add_argument("-pi", "--previnst", help="set number of previous instructions to be shown. default:8", type=int)
	parser.add_argument("-p", "--pid", help="attach pira to running process", type=int)
	parser.add_argument("-arch", "--architecture", help="specify the CPU architecture for your target binary. default:x86", type=int)
	
	args = parser.parse_args()

	# adjust terminal setting to default
	try:
		Popen(['stty', 'sane'])
	except:
		if DEBUG:
			print 'stty error'
		pass

	# automatic layout adjustment (require : tput)
	try:
		cols = int(Popen(['tput', 'cols'], stdout=PIPE).communicate()[0])
		rows = int(Popen(['tput', 'lines'], stdout=PIPE).communicate()[0])
		# if no exception
		TWIDTH = int(cols * 0.60)
		RWIDTH = int(cols * 0.30)
		FIXED_HEIGHT = int(rows*0.5)
		NPREV_INST = int(rows*0.25)
	except:
		if DEBUG:
			print 'tput error'
		pass

	# manual override
	if args.twidth:
		TWIDTH = args.twidth
	if args.rwidth:
		RWIDTH = args.rwidth
	if args.minpoll:
		MINPOLL = args.minpoll
	if args.iheight:
		FIXED_HEIGHT = args.iheight
	if args.previnst:
		NPREV_INST = args.previnst

	# start gdb
	try:
		if args.pid:	# attach
			p  = Popen(['stdbuf', '-o0', '-e0', 'gdb', '-p', args.pid], stdout=PIPE, stdin=PIPE, stderr=PIPE, bufsize=1, close_fds=ON_POSIX)
		else:	
			p  = Popen(['stdbuf', '-o0', '-e0', 'gdb', '--args', args.target], stdout=PIPE, stdin=PIPE, stderr=PIPE, bufsize=1, close_fds=ON_POSIX)
	except:
		print '[stdbuf] doesn\'t exist! PIRA can still work but if your application performs I/O, there will be buffering problem :('
		try:	
			p  = Popen(['gdb', '--args', args.target], stdout=PIPE, stdin=PIPE, stderr=PIPE, bufsize=1, close_fds=ON_POSIX)
		except:
			print '[gdb] doesn\'t exist! PIRA is just a wrapper interface for gdb :('
			os._exit(0)

	# recognize target architecture
	try:
		s = Popen(['file', args.target], stdout=PIPE).communicate()[0]
		# if no exception
		if s.find('Intel 80386') != -1:		# x86 binary
			ARCH = 'x86'
			IR = IR_x86
			TEXT = TEXT_x86
		elif s.find('x86-64') != -1:	# x86_64 binary
			ARCH = 'x64'
			IR = IR_x64
			TEXT = TEXT_x64
		elif s.find('ARM') != -1:		# arm binary
			ARCH = 'arm'
			IR = IR_arm
			TEXT = TEXT_arm
		elif s.find('MIPS') != -1:		# mips binary
			ARCH = 'mips'
			IR = IR_mips
			TEXT = TEXT_mips
		else:							
			print 'unknown CPU architecture!, assuming as x86'
	except:
		print '[file] command doesn\'t exist. assuming this is x86. you can give -arch option to specify CPU ARCH'

	if DEBUG:
		print 'TWIDTH : ', TWIDTH
		print 'RWIDTH : ', RWIDTH
		print 'FIXED_HEIGHT : ', FIXED_HEIGHT
		print 'NPREV_INST : ', NPREV_INST
		print 'ARCH : ', ARCH

	q  = Queue()	# stdout	
	t = Thread(target=enqueue_output, args=(p.stdout, q))
	t.daemon = True # thread dies with the program
	t.start()

	q2 = Queue()	# stderr
	t2 = Thread(target=enqueue_output, args=(p.stderr, q2))
	t2.daemon = True # thread dies with the program
	t2.start()

	t3 = Thread(target=enqueue_output, args=(p.stderr, q2))


	# wait for initial output
	time.sleep(0.2)
	print flush_output(q, q2)

	def init_queue():
		with inst_q.mutex:
		    inst_q.queue.clear()
		# init prev instruction queue
		for i in xrange(NPREV_INST):
			inst_q.put(' ')
		del prev_regs[:]

	init_queue()
			
	try:
		prev_cmd = ''

		# process command	
		while True:
			sys.stdout.write(SHELL)
	
			# read custom buffer
			cmd = readcmd()

			stall_buffer = False

			# parse hot commands
			cmd = hotkeys(cmd)

			# eat line
			if imode==True:
				if cmd=='si' or cmd=='ni' or cmd=='':
					cmd = ''
					prev_cmd = ''
					sys.stdout.write(SHELL)
					continue

			# eat line
			if imode == False and cmd == '' and prev_cmd!='si' and prev_cmd!='ni':
				sys.stdout.write(SHELL)
				continue
					
			# toggle mode (static/interactive)
			if cmd == TOGGLE_MODE:
				prev_cmd=''
				imode = not imode
				if imode == False:	# static mode
					init_queue()
					print '- STATIC MODE -'
				else:				# i-mode
					clear_screen()
					process_gui(p.stdin, '', '', True, q, q2)	# just draw i-screen. no command
				continue
			
			# screen navigation
			if cmd == NEXTSCR:
				if si > 0:
					si -= 1 				# forward screen
					clear_screen()
					print scr_buf[si]
					continue
				else:
					cmd = 'si'
			if cmd == NEXTSCR2:
				if si > 0:
					si -= 1 				# forward screen
					clear_screen()
					print scr_buf[si]
					continue
				else:
					cmd = 'ni'
			if cmd == PREVSCR:
				if si < len(scr_buf)-1:
					si += 1 			# backward screen
					clear_screen()
					print scr_buf[si]
					continue
				else:
					print 'end of screen buffer'
					continue
			if cmd == 'q' or cmd == 'quit':
				print ' quit pira? (y/n) '
				cmd = raw_input()
				if cmd == 'y' or cmd == 'Y':
					os._exit(0)
				else:
					continue
					
			if cmd == '':
				cmd = prev_cmd
			else:
				if cmd!='si' and cmd!='ni':
					prev_cmd = cmd

			# handle exceptional cases
			if prev_cmd=='r' or prev_cmd=='run' or prev_cmd=='q' or prev_cmd=='quit':
				prev_cmd=''

			# exceptional buffering timeout
			stall_buffer = (cmd=='r' or cmd=='run')
			
			# static mode
			if imode == False:
				if DEBUG:
					print 'sending cmd ({})'.format(cmd.encode('hex'))
				process_cui(p.stdin, cmd, q, q2)
			# interactive mode
			else:
				# moving cursor
				if cmd[:2] == 'si' or cmd[:2] == 'ni':
					cursor = True
				else:
					cursor = False		
				process_gui(p.stdin, cmd, prev_cmd, cursor, q, q2)

	except Exception, e:
		print "PIRA Exception : {0}".format(e)
		os._exit(0)
		
