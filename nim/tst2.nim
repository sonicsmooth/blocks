



var
    s1: seq[int]


proc globalAdder() {.thread.} =
    {.gcsafe.}:
        s1.add(1000)
        s1.add(1001)

proc adder(vseq: var seq[int]) =
    vseq.add(99)
    vseq.add(100)

proc worker1(pseq: ptr seq[int]) {.thread.} =
    pseq[].add(10)
    pseq[].add(11)

proc worker2(pseq: ptr seq[int]) {.thread.} =
    adder(pseq[])

    
# Try adding to seqs in main thread
s1 = @[1,2,3]
globalAdder()
echo s1
adder(s1)
echo s1
worker1(s1.addr)
echo s1
worker2(s1.addr)
echo s1
echo "--"

# Try adding to seqs in separate threads
s1 = @[1,2,3]
var th1, th2: Thread[void]
echo s1
th1.createThread(globalAdder)
th2.createThread(globalAdder)
echo s1
th1.joinThread()
th2.joinThread()
echo s1

#var th2: Thread[ptr seq[int]]
# th.createThread(worker2, s1.addr)
# th.joinThread()
# echo s1

